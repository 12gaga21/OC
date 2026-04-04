; ============================================================================
; МОДУЛЬ УПРАВЛЕНИЯ ПАМЯТЬЮ (MEMORY MANAGER)
; Операционная система "Священный Ритуалъ"
; Стиль: Злато-Изумрудный Ритуалъ
; © Россійская Имперія, Лѣто 2026 отъ Р.Х.
; ============================================================================
; Назначеніе:
;   - Распредѣленіе памяти для процессовъ
;   - Защиты отъ несанкціонированнаго доступа (Инквизиція)
;   - Виртуальная память (базовая поддержка)
;   - Сборка мусора (очистка освободившихся страницъ)
; ============================================================================

[BITS 32]

SECTION .data

; Магическія числа и константы
MEMORY_MAGIC equ 0xDEADBEEF
PAGE_SIZE equ 4096
MAX_PAGES equ 1024
MAX_PROCESSES equ 64

; Цвѣта для сообщеній (VGA)
COLOR_GREEN equ 0x0A    ; Изумрудный
COLOR_GOLD equ 0x1E     ; Златой на синемъ
COLOR_RED equ 0x0C      ; Кровавый (ошибки)

; Статусы
MEM_OK equ 0
MEM_ERROR equ 1
MEM_ACCESS_DENIED equ 2

; Таблица страницъ (Page Directory)
align 4096
page_directory:
    times MAX_PAGES db 0

; Карта свободной памяти
memory_map:
    times MAX_PAGES db 0    ; 0 = свободно, 1 = занято

; Счетчики
free_pages_count: dd MAX_PAGES
allocated_pages: dd 0
total_allocations: dd 0
total_frees: dd 0

; Сообщенія
msg_mem_init db '[ПАМЯТЬ] Инициализація...', 0
msg_mem_ok db 'Благословенно', 0
msg_mem_error db '† ОШИБКА †: Нарушеніе цѣлостности памяти', 0
msg_access_denied db '† ИНКВИЗИЦІЯ †: Доступъ запрещенъ!', 0

SECTION .bss

; Буферъ для временныхъ операцій
temp_buffer resb PAGE_SIZE

; Текущій контекстъ процесса
current_process_id resd 1

SECTION .text

; ============================================================================
; ФУНКЦІЯ: memory_init
; Назначеніе: Инициализація менеджера памяти
; Входъ: Нѣтъ
; Выходъ: EAX = статусъ (MEM_OK/MEM_ERROR)
; ============================================================================
global memory_init
memory_init:
    pusha
    
    ; Очищаемъ карту памяти
    mov edi, memory_map
    mov ecx, MAX_PAGES
    xor eax, eax
    rep stosb
    
    ; Сбрасываемъ счетчики
    mov dword [free_pages_count], MAX_PAGES
    mov dword [allocated_pages], 0
    mov dword [total_allocations], 0
    mov dword [total_frees], 0
    
    ; Инициализируемъ каталогъ страницъ
    mov edi, page_directory
    mov ecx, MAX_PAGES
    xor eax, eax
    rep stosb
    
    ; Устанавливаемъ идентификаторъ текущаго процесса
    mov dword [current_process_id], 0
    
    ; Выводимъ сообщеніе объ успѣшной инициализаціи
    ; (Вызовъ tty_print будетъ интегрированъ въ kernel.asm)
    
    popa
    mov eax, MEM_OK
    ret

; ============================================================================
; ФУНКЦІЯ: memory_allocate_page
; Назначеніе: Выдѣленіе одной страницы памяти
; Входъ: Нѣтъ
; Выходъ: EAX = адресъ страницы или 0 при ошибкѣ
; ============================================================================
global memory_allocate_page
memory_allocate_page:
    pusha
    
    ; Провѣряемъ наличие свободныхъ страницъ
    mov eax, [free_pages_count]
    cmp eax, 0
    je .no_free_pages
    
    ; Ищемъ первую свободную страницу
    mov ecx, MAX_PAGES
    mov esi, memory_map
    xor ebx, ebx    ; Индексъ страницы
    
.find_free:
    cmp ecx, 0
    je .no_free_pages
    
    mov al, [esi + ebx]
    cmp al, 0
    je .found_free
    
    inc ebx
    dec ecx
    jmp .find_free
    
.found_free:
    ; Отмечаемъ страницу какъ занятую
    mov byte [esi + ebx], 1
    
    ; Обновляемъ счетчики
    dec dword [free_pages_count]
    inc dword [allocated_pages]
    inc dword [total_allocations]
    
    ; Вычисляемъ физическій адресъ
    mov eax, ebx
    imul eax, PAGE_SIZE
    add eax, 0x100000    ; Начинаемъ съ 1MB
    
    ; Заполняемъ страницу нулями (очищаемъ)
    mov edi, eax
    mov ecx, PAGE_SIZE / 4
    xor eax, eax
    rep stosd
    
    ; Возвращаемъ адресъ
    mov eax, edi
    sub eax, ecx * 4    ; Корректируемъ адресъ
    
    popa
    ret
    
.no_free_pages:
    popa
    xor eax, eax    ; Возвращаемъ 0 (ошибка)
    ret

; ============================================================================
; ФУНКЦІЯ: memory_free_page
; Назначеніе: Освобожденіе страницы памяти
; Входъ: EAX = адресъ страницы
; Выходъ: EAX = статусъ (MEM_OK/MEM_ERROR)
; ============================================================================
global memory_free_page
memory_free_page:
    pusha
    push eax    ; Сохраняемъ адресъ
    
    ; Проверяемъ корректность адреса
    cmp eax, 0x100000
    jb .invalid_address
    
    ; Вычисляемъ индексъ страницы
    sub eax, 0x100000
    xor edx, edx
    mov ecx, PAGE_SIZE
    div ecx
    
    cmp eax, MAX_PAGES
    jge .invalid_address
    
    ; Проверяемъ, была ли страница занята
    mov ebx, eax
    mov esi, memory_map
    mov al, [esi + ebx]
    cmp al, 0
    je .already_free
    
    ; Освобождаемъ страницу
    mov byte [esi + ebx], 0
    
    ; Обновляемъ счетчики
    inc dword [free_pages_count]
    dec dword [allocated_pages]
    inc dword [total_frees]
    
    ; Очищаемъ содержимое страницы
    mov eax, ebx
    imul eax, PAGE_SIZE
    add eax, 0x100000
    mov edi, eax
    mov ecx, PAGE_SIZE / 4
    xor eax, eax
    rep stosd
    
    pop eax
    mov eax, MEM_OK
    popa
    ret
    
.invalid_address:
    pop eax
    mov eax, MEM_ERROR
    popa
    ret
    
.already_free:
    pop eax
    mov eax, MEM_ERROR
    popa
    ret

; ============================================================================
; ФУНКЦІЯ: memory_check_access
; Назначеніе: Проверка доступа къ памяти (Инквизиція)
; Входъ: EAX = адресъ, EBX = ID процесса
; Выходъ: EAX = статусъ (MEM_OK/MEM_ACCESS_DENIED)
; ============================================================================
global memory_check_access
memory_check_access:
    pusha
    
    ; Проверяемъ, что адресъ въ допустимыхъ предѣлахъ
    cmp eax, 0x100000
    jb .access_denied
    
    ; Вычисляемъ индексъ страницы
    push eax
    sub eax, 0x100000
    xor edx, edx
    mov ecx, PAGE_SIZE
    div ecx
    pop eax
    
    cmp eax, MAX_PAGES
    jge .access_denied
    
    ; Проверяемъ, занята ли страница
    mov ebx, eax
    mov esi, memory_map
    mov al, [esi + ebx]
    cmp al, 0
    je .access_denied
    
    ; Здесь должна быть проверка правъ процесса
    ; (Интеграция съ модулемъ inquisition.asm)
    
    ; Доступъ разрѣшенъ
    popa
    mov eax, MEM_OK
    ret
    
.access_denied:
    popa
    mov eax, MEM_ACCESS_DENIED
    ret

; ============================================================================
; ФУНКЦІЯ: memory_get_stats
; Назначеніе: Полученіе статистики использованія памяти
; Входъ: EAX = указатель на буферъ (16 байтъ)
; Выходъ: Нѣтъ (заполняетъ буферъ)
; Структура буфера:
;   [0-3]: Всего страницъ
;   [4-7]: Свободно страницъ
;   [8-11]: Выдѣлено страницъ
;   [12-15]: Всего выдѣленій
; ============================================================================
global memory_get_stats
memory_get_stats:
    pusha
    push eax    ; Сохраняемъ указатель на буферъ
    
    mov edi, [esp + 20]    ; Адресъ буфера (послѣ pusha)
    
    ; Всего страницъ
    mov eax, MAX_PAGES
    stosd
    
    ; Свободно страницъ
    mov eax, [free_pages_count]
    stosd
    
    ; Выдѣлено страницъ
    mov eax, [allocated_pages]
    stosd
    
    ; Всего выдѣленій
    mov eax, [total_allocations]
    stosd
    
    pop eax
    popa
    ret

; ============================================================================
; ФУНКЦІЯ: memory_dump_region
; Назначеніе: Дампъ области памяти (для отладки)
; Входъ: EAX = адресъ начала, EBX = количество байтъ
; Выходъ: Нѣтъ (выводитъ на экранъ черезъ tty)
; ============================================================================
global memory_dump_region
memory_dump_region:
    pusha
    
    ; Сохраняемъ параметры
    push eax
    push ebx
    
    ; Здесь будетъ реализація дампа памяти
    ; (Интеграция съ tty.asm для вывода)
    
    ; Временная заглушка
    pop ebx
    pop eax
    
    popa
    ret

; ============================================================================
; ФУНКЦІЯ: memory_protect_region
; Назначеніе: Защита области памяти (установка правъ доступа)
; Входъ: EAX = адресъ, EBX = размѣръ, ECX = права доступа
; Выходъ: EAX = статусъ
; Права доступа:
;   Bit 0: Чтеніе
;   Bit 1: Запись
;   Bit 2: Выполненіе
; ============================================================================
global memory_protect_region
memory_protect_region:
    pusha
    
    ; Проверяемъ параметры
    cmp eax, 0x100000
    jb .error
    
    cmp ebx, 0
    je .error
    
    ; Вычисляемъ количество страницъ
    mov edx, ebx
    add edx, PAGE_SIZE - 1
    shr edx, 12    ; Дѣлимъ на PAGE_SIZE
    
    ; Устанавливаемъ права для каждой страницы
    mov esi, eax
.protect_loop:
    cmp edx, 0
    je .done
    
    ; Вычисляемъ индексъ страницы
    push eax
    mov eax, esi
    sub eax, 0x100000
    xor edx, edx
    mov ecx, PAGE_SIZE
    div ecx
    
    cmp eax, MAX_PAGES
    jge .error
    
    ; Здесь будетъ установленіе правъ доступа
    ; (Требуется интеграция съ таблицей страницъ)
    
    add esi, PAGE_SIZE
    dec edx
    pop eax
    jmp .protect_loop
    
.done:
    popa
    xor eax, eax    ; MEM_OK
    ret
    
.error:
    popa
    mov eax, 1    ; MEM_ERROR
    ret

; ============================================================================
; ФУНКЦІЯ: memory_copy
; Назначеніе: Копированіе блока памяти
; Входъ: EAX = источникъ, EBX = назначеніе, ECX = количество байтъ
; Выходъ: Нѣтъ
; ============================================================================
global memory_copy
memory_copy:
    pusha
    
    ; Проверяемъ доступъ къ областямъ памяти
    push eax
    push ebx
    push ecx
    
    ; Копированіе
    mov esi, [esp + 16]    ; Источникъ
    mov edi, [esp + 20]    ; Назначеніе
    mov ecx, [esp + 24]    ; Количество
    
    ; Используемъ REP MOVSB для быстрого копированія
    rep movsb
    
    pop ecx
    pop ebx
    pop eax
    
    popa
    ret

; ============================================================================
; ФУНКЦІЯ: memory_zero
; Назначеніе: Обнуленіе блока памяти
; Входъ: EAX = адресъ, EBX = количество байтъ
; Выходъ: Нѣтъ
; ============================================================================
global memory_zero
memory_zero:
    pusha
    
    mov edi, eax
    mov ecx, ebx
    xor eax, eax
    
    ; Быстрое обнуленіе
    rep stosb
    
    popa
    ret

; ============================================================================
; КОНЕЦЪ МОДУЛЯ УПРАВЛЕНІЯ ПАМЯТЬЮ
; Слава Отечеству! Слава Вѣрѣ! Слава Омниссіи!
; ============================================================================
