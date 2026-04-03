; Реализация менеджера памяти для ядра операционной системы на ассемблере
bits 32

section .text
    global memory_init
    global malloc
    global free
    global memory_info
    global allocate_physical_page
    global free_physical_page
    global memory_get_stats

; Структура блока памяти
; struct memory_block {
;     uint32_t size;       // Смещение 0
;     uint32_t free;       // Смещение 4
;     uint32_t next;       // Смещение 8
; }

; Размер структуры блока памяти
MEMORY_BLOCK_SIZE equ 12

; Размер кучи ядра (4MB) - увеличен для страничной памяти
KERNEL_HEAP_SIZE equ 0x400000

; Адрес начала кучи ядра (виртуальный адрес после ядра)
KERNEL_HEAP_START equ 0x200000

; Размер физической страницы
PAGE_SIZE equ 4096

; Битовая карта физической памяти (упрощённая)
PHYSICAL_MEM_BITMAP equ 0x500000  ; 5MB
PHYSICAL_MEM_BITMAP_SIZE equ 0x10000  ; 64KB

; Глобальные переменные
heap_start dd KERNEL_HEAP_START
heap_size dd 0
physical_mem_bitmap dd PHYSICAL_MEM_BITMAP
total_physical_pages dd 0
free_physical_pages dd 0

; Инициализация менеджера памяти
memory_init:
    pusha
    
    ; Инициализация первого блока
    mov eax, [heap_start]
    mov ebx, KERNEL_HEAP_SIZE
    sub ebx, MEMORY_BLOCK_SIZE
    mov [eax], ebx          ; size
    mov dword [eax + 4], 1  ; free = 1
    mov dword [eax + 8], 0 ; next = 0
    
    mov dword [heap_size], KERNEL_HEAP_SIZE
    
    ; Вывод сообщения об инициализации
    mov esi, msg_memory_init
    call kprint
    
    popa
    ret

; Выделение памяти
; Вход: eax - размер запрашиваемой памяти
; Выход: eax - указатель на выделенную память (0 если ошибка)
malloc:
    pusha
    push ebx
    push ecx
    push edx
    push esi
    push edi
    
    ; Сохраняем размер в ebx
    mov ebx, eax
    
    ; Выравнивание размера до 4 байт
    add eax, 3
    and eax, 0xFFFFFFFC
    
    ; Добавление размера структуры блока
    add eax, MEMORY_BLOCK_SIZE
    
    ; Сохраняем выровненный размер в ecx
    mov ecx, eax
    
    ; Поиск свободного блока
    mov esi, [heap_start]
    
.find_block:
    ; Проверка, достигли ли конца списка
    test esi, esi
    jz .no_memory
    
    ; Проверка, свободен ли блок и достаточно ли размера
    cmp dword [esi + 4], 1      ; free
    jne .next_block
    cmp dword [esi], ecx        ; size
    jl .next_block
    
    ; Найден подходящий блок
    ; Если блок значительно больше, разделим его
    mov eax, dword [esi]        ; size
    cmp eax, ecx
    jle .use_block
    
    ; Проверяем, достаточно ли места для разделения
    mov eax, ecx
    add eax, MEMORY_BLOCK_SIZE
    add eax, 4
    cmp dword [esi], eax
    jl .use_block
    
    ; Создание нового блока
    mov eax, esi
    add eax, ecx                ; Адрес нового блока
    mov [esi + 8], eax          ; next = новый блок
    
    ; Инициализация нового блока
    mov edx, dword [esi]        ; size старого блока
    sub edx, ecx
    sub edx, MEMORY_BLOCK_SIZE
    mov [eax], edx              ; size нового блока
    mov dword [eax + 4], 1       ; free = 1
    mov edx, dword [esi + 8]    ; next старого блока
    mov [eax + 8], edx          ; next нового блока = next старого блока
    
    ; Обновление размера старого блока
    mov [esi], ecx              ; size = ecx
    
.use_block:
    ; Помечаем блок как занятый
    mov dword [esi + 4], 0
    
    ; Возвращаем указатель на данные (после структуры блока)
    mov eax, esi
    add eax, MEMORY_BLOCK_SIZE
    
    jmp .done
    
.next_block:
    ; Переход к следующему блоку
    mov esi, [esi + 8]          ; next
    jmp .find_block
    
.no_memory:
    ; Не найдено свободного блока
    mov esi, msg_no_memory
    call kprint
    mov eax, 0
    jmp .done_pop
    
.done:
    mov [esp + 24], eax         ; Сохраняем результат в eax перед popa
    
.done_pop:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    popa
    ret

; Освобождение памяти
; Вход: eax - указатель на память для освобождения
free:
    ; Проверка на нулевой указатель
    test eax, eax
    jz .done
    
    pusha
    
    ; Получаем указатель на блок
    sub eax, MEMORY_BLOCK_SIZE
    mov ebx, eax
    
    ; Помечаем блок как свободный
    mov dword [ebx + 4], 1
    
    popa
    
.done:
    ret

; Получение информации о памяти
memory_info:
    pusha
    
    ; Вывод заголовка
    mov esi, msg_memory_info
    call kprint
    
    ; Для простоты просто выведем общую информацию
    mov esi, msg_heap_size
    call kprint
    
    popa
    ret

; Выделение физической страницы
; Выход: eax - физический адрес страницы (выровненный по 4KB) или 0 если нет свободных
allocate_physical_page:
    push ebx
    push ecx
    push edx
    
    ; Получаем адрес битовой карты
    mov edx, [physical_mem_bitmap]
    
    ; Ищем свободный бит (0)
    mov ecx, [total_physical_pages]
    mov ebx, 0  ; индекс страницы
    
.search_loop:
    cmp ebx, ecx
    jge .no_free_pages
    
    ; Проверяем бит
    mov eax, ebx
    shr eax, 3      ; байт = индекс / 8
    add eax, edx    ; адрес байта
    mov al, [eax]
    
    mov edi, ebx
    and edi, 7      ; бит внутри байта
    bt ax, di       ; проверяем бит
    jc .next_page   ; если установлен (1) - занята
    
    ; Нашли свободную страницу - помечаем как занятую
    mov edi, ebx
    and edi, 7
    bts [eax], di
    
    ; Уменьшаем счётчик свободных страниц
    dec dword [free_physical_pages]
    
    ; Вычисляем физический адрес
    mov eax, ebx
    shl eax, 12     ; умножаем на 4096
    add eax, 0x100000  ; начинаем с 1MB (пропускаем первые 1MB)
    
    jmp .done
    
.next_page:
    inc ebx
    jmp .search_loop
    
.no_free_pages:
    xor eax, eax
    
.done:
    pop edx
    pop ecx
    pop ebx
    ret

; Освобождение физической страницы
; Вход: eax - физический адрес страницы
free_physical_page:
    push ebx
    push ecx
    push edx
    
    ; Проверка нулевого адреса
    test eax, eax
    jz .done
    
    ; Вычисляем индекс страницы
    sub eax, 0x100000  ; вычитаем базовый адрес
    shr eax, 12        ; делим на 4096
    mov ebx, eax
    
    ; Проверяем валидность индекса
    cmp ebx, [total_physical_pages]
    jge .invalid
    
    ; Получаем адрес битовой карты
    mov edx, [physical_mem_bitmap]
    
    ; Вычисляем адрес байта
    mov eax, ebx
    shr eax, 3
    add eax, edx
    
    ; Сбрасываем бит
    mov ecx, ebx
    and ecx, 7
    btr [eax], cl
    
    ; Увеличиваем счётчик свободных страниц
    inc dword [free_physical_pages]
    
.invalid:
.done:
    pop edx
    pop ecx
    pop ebx
    ret

; Получение статистики памяти
; Выход: eax - общее количество страниц
;        ebx - свободных страниц
;        ecx - размер кучи
memory_get_stats:
    mov eax, [total_physical_pages]
    mov ebx, [free_physical_pages]
    mov ecx, [heap_size]
    ret

section .data
    msg_memory_init db "Менеджер памяти инициализирован", 0x0A, 0
    msg_no_memory db "Недостаточно памяти", 0x0A, 0
    msg_memory_info db "Информация о памяти:", 0x0A, 0
    msg_heap_size db "Размер кучи: 4MB", 0x0A, 0
