; Загрузчик программ (Loader) для ОС «Священный Ритуалъ»
; Загружает исполняемые файлы .BIN из файловой системы и запускает их
; Стиль: Злато-Изумрудный Ритуалъ
bits 32

section .text
    global loader_init
    global loader_load_program
    global loader_execute
    global loader_unload_program
    global loader_get_status
    global loader_validate_binary
    
    extern fs_open_file
    extern fs_read_file
    extern fs_close_file
    extern fs_get_file_size
    extern memory_allocate_pages
    extern memory_free_pages
    extern scheduler_create_task
    extern scheduler_switch_to_task
    extern vga_put_string
    extern vga_put_char

; ============================================================================
; ИНИЦИАЛИЗАЦИЯ ЗАГРУЗЧИКА
; ============================================================================
loader_init:
    pusha
    
    ; Инициализация таблицы загруженных программ
    mov edi, loaded_programs
    mov ecx, MAX_LOADED_PROGRAMS
    xor eax, eax
    rep stosd
    
    ; Установка флага инициализации
    mov dword [loader_initialized], 1
    
    ; Сообщение об успешной инициализации
    mov esi, loader_init_msg
    call vga_put_string
    
    popa
    ret

; ============================================================================
; ПРОВЕРКА ВАЛИДНОСТИ BIN ФАЙЛА
; Проверяет сигнатуру и базовую структуру файла
; ============================================================================
loader_validate_binary:
    ; Вход: ESI = указатель на буфер с данными
    ;       EDX = размер данных
    ; Выход: EAX = 1 если валиден, 0 если нет
    pusha
    
    ; Проверка минимального размера (хотя бы заголовок)
    cmp edx, MIN_BINARY_SIZE
    jl .invalid
    
    ; Проверка магической сигнатуры "RI†U" (0x52498655)
    ; Первые 4 байта должны содержать сигнатуру
    mov eax, [esi]
    cmp eax, BINARY_SIGNATURE
    je .valid
    
    ; Альтернатива: простой BIN без сигнатуры (для совместимости)
    ; Проверяем что первые байты - это код (не нули)
    mov eax, [esi]
    test eax, eax
    jnz .simple_bin_valid
    
.invalid:
    popa
    mov eax, 0
    ret
    
.simple_bin_valid:
    ; Простой BIN файл без заголовка
    popa
    mov eax, 2  ; Возвращаем 2 для простого BIN
    ret
    
.valid:
    popa
    mov eax, 1
    ret

; ============================================================================
; ЗАГРУЗКА ПРОГРАММЫ ИЗ ФАЙЛОВОЙ СИСТЕМЫ
; ============================================================================
loader_load_program:
    ; Вход: ESI = имя файла (полный путь)
    ; Выход: EAX = дескриптор программы (>=0) или ошибка (<0)
    pusha
    push ebx
    push ecx
    push edx
    push edi
    
    ; Проверка инициализации
    cmp dword [loader_initialized], 1
    jne .not_initialized
    
    ; Поиск свободного слота в таблице программ
    mov edi, loaded_programs
    mov ecx, MAX_LOADED_PROGRAMS
    xor ebx, ebx  ; Индекс слота
    
.find_slot:
    test ecx, ecx
    jz .no_slots
    
    ; Проверка флага is_loaded (смещение 0 в структуре)
    cmp dword [edi], 0
    je .slot_found
    
    add edi, PROGRAM_STRUCT_SIZE
    inc ebx
    dec ecx
    jmp .find_slot
    
.no_slots:
    popa
    mov eax, -ERR_NO_SLOTS
    ret
    
.slot_found:
    ; Сохраняем указатель на структуру программы
    mov [current_program_struct], edi
    
    ; Открытие файла
    push esi
    call fs_open_file
    add esp, 4
    test eax, eax
    js .open_error
    
    mov [file_handle], eax
    
    ; Получение размера файла
    push eax
    call fs_get_file_size
    add esp, 4
    test eax, eax
    js .size_error
    
    ; Проверка размера
    cmp eax, MAX_PROGRAM_SIZE
    jg .too_large
    
    mov [program_size], eax
    
    ; Выделение памяти для программы
    push eax
    call memory_allocate_pages
    add esp, 4
    test eax, eax
    jz .memory_error
    
    mov [program_memory], eax
    mov [edi + PROG_MEM_PTR], eax  ; Сохраняем указатель на память
    
    ; Чтение файла в память
    push dword [file_handle]
    push eax          ; Буфер
    push dword [program_size]  ; Размер
    call fs_read_file
    add esp, 12
    test eax, eax
    js .read_error
    
    ; Валидация загруженных данных
    push dword [program_size]
    push dword [program_memory]
    call loader_validate_binary
    add esp, 8
    test eax, eax
    jz .validation_error
    
    ; Заполнение структуры программы
    mov edi, [current_program_struct]
    
    ; Флаг загрузки
    mov dword [edi], 1
    
    ; Имя файла (копируем первые 64 символа)
    mov esi, [esp + 20]  ; Исходное имя файла
    mov ecx, 64
    mov edi, [current_program_struct]
    add edi, PROG_NAME
    rep movsb
    
    ; Размер программы
    mov eax, [program_size]
    mov edi, [current_program_struct]
    mov [edi + PROG_SIZE], eax
    
    ; Точка входа (начало памяти для простого BIN)
    mov eax, [program_memory]
    mov [edi + PROG_ENTRY_POINT], eax
    
    ; Состояние (READY)
    mov [edi + PROG_STATE], PROG_STATE_READY
    
    ; Закрытие файла
    push dword [file_handle]
    call fs_close_file
    add esp, 4
    
    ; Возврат индекса программы
    mov eax, ebx
    
    ; Сообщение об успехе
    push ebx
    mov esi, load_success_msg
    call vga_put_string
    pop ebx
    
    popa
    ret
    
.not_initialized:
    popa
    mov eax, -ERR_NOT_INITIALIZED
    ret
    
.open_error:
    popa
    mov esi, open_error_msg
    call vga_put_string
    popa
    mov eax, -ERR_FILE_OPEN
    ret
    
.size_error:
    popa
    mov esi, size_error_msg
    call vga_put_string
    popa
    mov eax, -ERR_FILE_SIZE
    ret
    
.too_large:
    popa
    mov esi, too_large_msg
    call vga_put_string
    popa
    mov eax, -ERR_TOO_LARGE
    ret
    
.memory_error:
    popa
    mov esi, memory_error_msg
    call vga_put_string
    popa
    mov eax, -ERR_MEMORY
    ret
    
.read_error:
    popa
    mov esi, read_error_msg
    call vga_put_string
    popa
    mov eax, -ERR_FILE_READ
    ret
    
.validation_error:
    popa
    mov esi, validation_error_msg
    call vga_put_string
    popa
    mov eax, -ERR_INVALID_FORMAT
    ret

; ============================================================================
; ВЫПОЛНЕНИЕ ЗАГРУЖЕННОЙ ПРОГРАММЫ
; Создаёт новую задачу и передаёт управление
; ============================================================================
loader_execute:
    ; Вход: EAX = индекс программы
    ; Выход: EAX = 0 если успешно, иначе код ошибки
    pusha
    push ebx
    push ecx
    push edx
    
    ; Проверка индекса
    cmp eax, MAX_LOADED_PROGRAMS
    jge .invalid_index
    test eax, eax
    jl .invalid_index
    
    ; Получение структуры программы
    imul ebx, eax, PROGRAM_STRUCT_SIZE
    mov edi, loaded_programs
    add edi, ebx
    
    ; Проверка что программа загружена
    cmp dword [edi], 0
    je .not_loaded
    
    ; Проверка состояния
    cmp dword [edi + PROG_STATE], PROG_STATE_READY
    jne .not_ready
    
    ; Получение точки входа
    mov ecx, [edi + PROG_ENTRY_POINT]
    
    ; Создание новой задачи планировщиком
    push ecx              ; Точка входа
    push PROG_PRIORITY    ; Приоритет
    push edi              ; Указатель на структуру программы
    add edi, PROG_NAME
    push edi              ; Имя задачи
    call scheduler_create_task
    add esp, 16
    test eax, eax
    js .task_error
    
    ; Обновление состояния программы
    mov edi, loaded_programs
    add edi, ebx
    mov [edi + PROG_STATE], PROG_STATE_RUNNING
    mov [edi + PROG_TASK_ID], eax
    
    ; Передача управления задаче (опционально)
    ; call scheduler_yield
    
    ; Сообщение об успехе
    mov esi, execute_success_msg
    call vga_put_string
    
    popa
    mov eax, 0
    ret
    
.invalid_index:
    popa
    mov esi, invalid_index_msg
    call vga_put_string
    popa
    mov eax, -ERR_INVALID_INDEX
    ret
    
.not_loaded:
    popa
    mov esi, not_loaded_msg
    call vga_put_string
    popa
    mov eax, -ERR_NOT_LOADED
    ret
    
.not_ready:
    popa
    mov esi, not_ready_msg
    call vga_put_string
    popa
    mov eax, -ERR_NOT_READY
    ret
    
.task_error:
    popa
    mov esi, task_error_msg
    call vga_put_string
    popa
    mov eax, -ERR_TASK_CREATE
    ret

; ============================================================================
; ВЫГРУЗКА ПРОГРАММЫ
; Освобождает память и удаляет из таблицы
; ============================================================================
loader_unload_program:
    ; Вход: EAX = индекс программы
    ; Выход: EAX = 0 если успешно
    pusha
    
    ; Проверка индекса
    cmp eax, MAX_LOADED_PROGRAMS
    jge .invalid_index
    test eax, eax
    jl .invalid_index
    
    ; Получение структуры программы
    imul ebx, eax, PROGRAM_STRUCT_SIZE
    mov edi, loaded_programs
    add edi, ebx
    
    ; Проверка что программа загружена
    cmp dword [edi], 0
    je .not_loaded
    
    ; Освобождение памяти
    mov eax, [edi + PROG_MEM_PTR]
    test eax, eax
    jz .skip_free
    
    push eax
    call memory_free_pages
    add esp, 4
    
.skip_free:
    ; Очистка структуры программы
    mov ecx, PROGRAM_STRUCT_SIZE / 4
    xor eax, eax
    rep stosd
    
    popa
    mov eax, 0
    ret
    
.invalid_index:
    popa
    mov eax, -ERR_INVALID_INDEX
    ret
    
.not_loaded:
    popa
    mov eax, -ERR_NOT_LOADED
    ret

; ============================================================================
; ПОЛУЧЕНИЕ СТАТУСА ЗАГРУЗЧИКА
; ============================================================================
loader_get_status:
    ; Вход: ESI = указатель на буфер для статуса
    ; Выход: EAX = количество загруженных программ
    pusha
    push ebx
    push edi
    
    mov edi, esi
    xor ebx, ebx  ; Счётчик программ
    xor ecx, ecx  ; Индекс
    
.status_loop:
    cmp ecx, MAX_LOADED_PROGRAMS
    jge .status_done
    
    ; Получение структуры программы
    push ecx
    imul eax, ecx, PROGRAM_STRUCT_SIZE
    mov edx, loaded_programs
    add edx, eax
    
    ; Проверка флага загрузки
    cmp dword [edx], 0
    je .next_program
    
    ; Программа загружена - добавляем в список
    inc ebx
    
    ; Копирование имени программы
    mov esi, edx
    add esi, PROG_NAME
    mov eax, 64
    rep movsb
    
    ; Разделитель строк
    mov al, 0x0D
    stosb
    mov al, 0x0A
    stosb
    
.next_program:
    pop ecx
    inc ecx
    jmp .status_loop
    
.status_done:
    popa
    mov eax, ebx
    ret

; ============================================================================
; ЗАГРУЗКА И ЗАПУСК ПРОГРАММЫ (ОДНОЙ ФУНКЦИЕЙ)
; ============================================================================
loader_run:
    ; Вход: ESI = имя файла
    ; Выход: EAX = 0 если успешно
    pusha
    
    ; Загрузка программы
    push esi
    call loader_load_program
    add esp, 4
    test eax, eax
    js .load_failed
    
    ; Выполнение программы
    push eax
    call loader_execute
    add esp, 4
    test eax, eax
    js .exec_failed
    
    popa
    ret
    
.load_failed:
    popa
    mov eax, -ERR_LOAD_FAILED
    ret
    
.exec_failed:
    popa
    mov eax, -ERR_EXEC_FAILED
    ret

; ============================================================================
; КОНСТАНТЫ
; ============================================================================
%define MAX_LOADED_PROGRAMS     16
%define PROGRAM_STRUCT_SIZE     256
%define MAX_PROGRAM_SIZE        0x100000  ; 1 MB макс
%define MIN_BINARY_SIZE         16
%define BINARY_SIGNATURE        0x52498655  ; "RI†U"
%define PROG_PRIORITY           5

; Смещения в структуре программы
%define PROG_FLAGS              0
%define PROG_NAME               4
%define PROG_SIZE               68
%define PROG_MEM_PTR            72
%define PROG_ENTRY_POINT        76
%define PROG_STATE              80
%define PROG_TASK_ID            84
%define PROG_MEM_PTR_HIGH       88

; Состояния программы
%define PROG_STATE_READY        0
%define PROG_STATE_RUNNING      1
%define PROG_STATE_SUSPENDED    2
%define PROG_STATE_TERMINATED   3

; Коды ошибок
%define ERR_NOT_INITIALIZED     1
%define ERR_NO_SLOTS            2
%define ERR_FILE_OPEN           3
%define ERR_FILE_SIZE           4
%define ERR_TOO_LARGE           5
%define ERR_MEMORY              6
%define ERR_FILE_READ           7
%define ERR_INVALID_FORMAT      8
%define ERR_INVALID_INDEX       9
%define ERR_NOT_LOADED          10
%define ERR_NOT_READY           11
%define ERR_TASK_CREATE         12
%define ERR_LOAD_FAILED         13
%define ERR_EXEC_FAILED         14

; ============================================================================
; ДАННЫЕ
; ============================================================================
section .data
    loader_initialized dd 0
    file_handle dd 0
    program_size dd 0
    program_memory dd 0
    current_program_struct dd 0
    
    ; Сообщения
    loader_init_msg db '† Загрузчик Программъ иниціализированъ', 0x0D, 0x0A, 0
    load_success_msg db '✓ Программа успѣшно загружена', 0x0D, 0x0A, 0
    execute_success_msg db '▶ Запускъ программы...', 0x0D, 0x0A, 0
    open_error_msg db '✗ Ошибка открытія файла', 0x0D, 0x0A, 0
    size_error_msg db '✗ Ошибка полученія размера', 0x0D, 0x0A, 0
    too_large_msg db '✗ Программа слишком велика', 0x0D, 0x0A, 0
    memory_error_msg db '✗ Недостаточно памяти', 0x0D, 0x0A, 0
    read_error_msg db '✗ Ошибка чтенія файла', 0x0D, 0x0A, 0
    validation_error_msg db '✗ Невѣрный форматъ программы', 0x0D, 0x0A, 0
    invalid_index_msg db '✗ Невѣрный индексъ программы', 0x0D, 0x0A, 0
    not_loaded_msg db '✗ Программа не загружена', 0x0D, 0x0A, 0
    not_ready_msg db '✗ Программа не готова к запуску', 0x0D, 0x0A, 0
    task_error_msg db '✗ Ошибка созданія задачи', 0x0D, 0x0A, 0

; ============================================================================
; ТАБЛИЦА ЗАГРУЖЕННЫХ ПРОГРАММ
; ============================================================================
section .bss
    loaded_programs resb MAX_LOADED_PROGRAMS * PROGRAM_STRUCT_SIZE
