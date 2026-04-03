; Реализация страничной памяти для ядра операционной системы на ассемблере
bits 32

section .text
    global paging_init
    global paging_enable
    global paging_disable
    global paging_map_page
    global paging_unmap_page
    global paging_get_physical_address
    global paging_handle_page_fault
    global paging_create_address_space
    global paging_map_page_in_space

; Константы страничной памяти
PAGE_SIZE equ 4096
PAGE_DIRECTORY_SIZE equ 1024
PAGE_TABLE_SIZE equ 1024

; Флаги для записей в таблицах страниц
PAGE_PRESENT equ 0x01
PAGE_WRITABLE equ 0x02
PAGE_USER equ 0x04
PAGE_WRITE_THROUGH equ 0x08
PAGE_CACHE_DISABLE equ 0x10
PAGE_ACCESSED equ 0x20
PAGE_DIRTY equ 0x40
PAGE_GLOBAL equ 0x80

; Адреса таблиц страниц
PAGE_DIRECTORY_ADDR equ 0x100000  ; 1MB - начало каталога страниц
PAGE_TABLES_ADDR equ 0x101000     ; 1MB + 4KB - начало таблиц страниц

; Глобальные переменные
page_directory dd PAGE_DIRECTORY_ADDR
page_tables_base dd PAGE_TABLES_ADDR
paging_enabled db 0

; Инициализация страничной памяти
paging_init:
    pusha
    
    ; Очистка каталога страниц
    mov edi, PAGE_DIRECTORY_ADDR
    mov ecx, PAGE_DIRECTORY_SIZE
    xor eax, eax
    rep stosd
    
    ; Создание таблиц страниц для первых 4MB (ядро)
    mov edi, PAGE_TABLES_ADDR
    mov ecx, PAGE_TABLE_SIZE * 4  ; 4 таблицы по 1024 записи = 4MB
    mov eax, PAGE_PRESENT | PAGE_WRITABLE  ; Флаги для ядра
    
.fill_kernel_tables:
    stosd
    add eax, PAGE_SIZE
    loop .fill_kernel_tables
    
    ; Настройка каталога страниц
    mov edi, PAGE_DIRECTORY_ADDR
    mov eax, PAGE_TABLES_ADDR
    or eax, PAGE_PRESENT | PAGE_WRITABLE
    
    ; Первые 4 записи каталога указывают на 4 таблицы страниц
    mov ecx, 4
.set_kernel_entries:
    stosd
    add eax, PAGE_SIZE * PAGE_TABLE_SIZE  ; Следующая таблица страниц
    loop .set_kernel_entries
    
    ; Остальные записи каталога - не присутствуют
    mov ecx, PAGE_DIRECTORY_SIZE - 4
    xor eax, eax
    rep stosd
    
    ; Загрузка каталога страниц в CR3
    mov eax, PAGE_DIRECTORY_ADDR
    mov cr3, eax
    
    ; Вывод сообщения об инициализации
    mov esi, msg_paging_init
    call kprint
    
    popa
    ret

; Включение страничной памяти
paging_enable:
    pusha
    
    ; Проверка, не включена ли уже страничная память
    cmp byte [paging_enabled], 1
    je .already_enabled
    
    ; Установка бита PG (31) в CR0
    mov eax, cr0
    or eax, 0x80000000
    mov cr0, eax
    
    mov byte [paging_enabled], 1
    
    ; Вывод сообщения
    mov esi, msg_paging_enabled
    call kprint
    
.already_enabled:
    popa
    ret

; Отключение страничной памяти
paging_disable:
    pusha
    
    ; Проверка, включена ли страничная память
    cmp byte [paging_enabled], 0
    je .already_disabled
    
    ; Сброс бита PG в CR0
    mov eax, cr0
    and eax, 0x7FFFFFFF
    mov cr0, eax
    
    mov byte [paging_enabled], 0
    
    ; Вывод сообщения
    mov esi, msg_paging_disabled
    call kprint
    
.already_disabled:
    popa
    ret

; Отображение виртуальной страницы на физическую
; Вход: eax - виртуальный адрес (выровненный по границе страницы)
;       ebx - физический адрес (выровненный по границе страницы)
;       ecx - флаги (PAGE_PRESENT, PAGE_WRITABLE, etc.)
paging_map_page:
    pusha
    
    ; Проверка выравнивания
    test eax, 0xFFF
    jnz .alignment_error
    test ebx, 0xFFF
    jnz .alignment_error
    
    ; Вычисляем индексы в каталоге страниц и таблице страниц
    mov edx, eax
    shr edx, 22          ; Индекс в каталоге страниц (биты 22-31)
    and edx, 0x3FF
    
    mov esi, eax
    shr esi, 12          ; Индекс в таблице страниц (биты 12-21)
    and esi, 0x3FF
    
    ; Получаем адрес записи в каталоге страниц
    mov edi, PAGE_DIRECTORY_ADDR
    lea edi, [edi + edx * 4]
    
    ; Проверяем, присутствует ли таблица страниц
    mov eax, [edi]
    test eax, PAGE_PRESENT
    jnz .table_exists
    
    ; Таблица отсутствует - создаём новую
    call .allocate_page_table
    mov eax, [edi]  ; Обновляем eax с адресом новой таблицы
    
.table_exists:
    ; Очищаем флаги, оставляем только адрес таблицы
    and eax, 0xFFFFF000
    
    ; Получаем адрес записи в таблице страниц
    lea edi, [eax + esi * 4]
    
    ; Устанавливаем запись в таблице страниц
    mov eax, ebx
    or eax, ecx      ; Добавляем флаги
    mov [edi], eax
    
    ; Инвалидируем TLB для этой страницы
    invlpg [eax]
    
    popa
    ret

.alignment_error:
    mov esi, msg_alignment_error
    call kprint
    popa
    ret

.allocate_page_table:
    pusha
    
    ; Ищем свободную физическую страницу (упрощённо)
    ; В реальной ОС нужно использовать менеджер физической памяти
    mov eax, PAGE_TABLES_ADDR + 0x4000  ; Начинаем с адреса после первых 4 таблиц
    
    ; Устанавливаем запись в каталоге страниц
    mov ebx, eax
    or ebx, PAGE_PRESENT | PAGE_WRITABLE
    mov [edi], ebx
    
    ; Очищаем новую таблицу страниц
    mov edi, eax
    mov ecx, PAGE_TABLE_SIZE
    xor eax, eax
    rep stosd
    
    popa
    ret

; Удаление отображения виртуальной страницы
; Вход: eax - виртуальный адрес
paging_unmap_page:
    pusha
    
    ; Вычисляем индексы
    mov edx, eax
    shr edx, 22
    and edx, 0x3FF
    
    mov esi, eax
    shr esi, 12
    and esi, 0x3FF
    
    ; Получаем адрес записи в каталоге страниц
    mov edi, PAGE_DIRECTORY_ADDR
    lea edi, [edi + edx * 4]
    
    ; Проверяем, присутствует ли таблица страниц
    mov eax, [edi]
    test eax, PAGE_PRESENT
    jz .not_present
    
    ; Очищаем флаги, оставляем только адрес таблицы
    and eax, 0xFFFFF000
    
    ; Получаем адрес записи в таблице страниц
    lea edi, [eax + esi * 4]
    
    ; Очищаем запись
    mov dword [edi], 0
    
    ; Инвалидируем TLB для этой страницы
    invlpg [eax]
    
.not_present:
    popa
    ret

; Получение физического адреса по виртуальному
; Вход: eax - виртуальный адрес
; Выход: eax - физический адрес (0 если не отображено)
paging_get_physical_address:
    push ebx
    push ecx
    push edx
    
    ; Вычисляем индексы
    mov edx, eax
    shr edx, 22
    and edx, 0x3FF
    
    mov ecx, eax
    shr ecx, 12
    and ecx, 0x3FF
    
    ; Получаем адрес записи в каталоге страниц
    mov ebx, PAGE_DIRECTORY_ADDR
    lea ebx, [ebx + edx * 4]
    
    ; Проверяем, присутствует ли таблица страниц
    mov eax, [ebx]
    test eax, PAGE_PRESENT
    jz .not_mapped
    
    ; Очищаем флаги, оставляем только адрес таблицы
    and eax, 0xFFFFF000
    
    ; Получаем адрес записи в таблице страниц
    lea ebx, [eax + ecx * 4]
    
    ; Проверяем, присутствует ли страница
    mov eax, [ebx]
    test eax, PAGE_PRESENT
    jz .not_mapped
    
    ; Очищаем флаги, оставляем только адрес страницы
    and eax, 0xFFFFF000
    
    ; Добавляем смещение внутри страницы
    mov edx, [esp + 12]  ; Оригинальный eax (виртуальный адрес)
    and edx, 0xFFF
    add eax, edx
    
    jmp .done
    
.not_mapped:
    xor eax, eax
    
.done:
    pop edx
    pop ecx
    pop ebx
    ret

; Обработчик page fault (исключение 14)
paging_handle_page_fault:
    pusha
    
    ; Получаем виртуальный адрес из CR2
    mov eax, cr2
    
    ; Проверяем причину page fault
    ; В реальной ОС здесь должна быть сложная логика
    ; Для простоты просто выводим сообщение об ошибке
    
    mov esi, msg_page_fault
    call kprint
    
    ; Выводим виртуальный адрес
    mov esi, msg_fault_address
    call kprint
    mov eax, cr2
    call print_hex
    
    ; Для демонстрации пытаемся выделить страницу
    ; В реальной ОС здесь должна быть логика подкачки страниц
    
    ; Бесконечный цикл (временное решение)
    mov esi, msg_halt
    call kprint
    cli
    hlt
    
    popa
    iret

; Создание нового адресного пространства для задачи
; Выход: eax - физический адрес каталога страниц (0 если ошибка)
paging_create_address_space:
    pusha
    
    ; Выделяем память для нового каталога страниц
    mov eax, PAGE_SIZE
    call allocate_physical_page
    test eax, eax
    jz .error
    
    mov edi, eax
    push edi
    
    ; Копируем записи ядра (первые 4 записи) из основного каталога
    mov esi, PAGE_DIRECTORY_ADDR
    mov ecx, 4
.copy_kernel_entries:
    mov eax, [esi]
    mov [edi], eax
    add esi, 4
    add edi, 4
    loop .copy_kernel_entries
    
    ; Остальные записи - не присутствуют
    mov ecx, PAGE_DIRECTORY_SIZE - 4
    xor eax, eax
    rep stosd
    
    pop eax  ; Возвращаем адрес каталога страниц
    
    popa
    ret
    
.error:
    xor eax, eax
    popa
    ret

; Отображение страницы в адресном пространстве задачи
; Вход: eax - адрес каталога страниц
;       ebx - виртуальный адрес
;       ecx - физический адрес
;       edx - флаги
paging_map_page_in_space:
    pusha
    
    ; Сохраняем адрес каталога страниц
    mov esi, eax
    
    ; Вычисляем индексы
    mov eax, ebx
    shr eax, 22
    and eax, 0x3FF
    
    mov edi, ebx
    shr edi, 12
    and edi, 0x3FF
    
    ; Получаем адрес записи в каталоге страниц
    lea ebx, [esi + eax * 4]
    
    ; Проверяем, присутствует ли таблица страниц
    mov eax, [ebx]
    test eax, PAGE_PRESENT
    jnz .table_exists
    
    ; Таблица отсутствует - создаём новую
    push esi
    push edi
    push edx
    
    ; Выделяем страницу для таблицы
    mov eax, PAGE_SIZE
    call allocate_physical_page
    test eax, eax
    jz .table_alloc_error
    
    mov edi, eax
    push edi
    
    ; Очищаем таблицу
    mov ecx, PAGE_TABLE_SIZE
    xor eax, eax
    rep stosd
    
    pop eax
    or eax, PAGE_PRESENT | PAGE_WRITABLE | PAGE_USER
    mov [ebx], eax  ; Устанавливаем запись в каталоге
    
    pop edx
    pop edi
    pop esi
    
    ; Обновляем eax с адресом таблицы
    mov eax, [ebx]
    and eax, 0xFFFFF000
    
.table_exists:
    ; Очищаем флаги, оставляем только адрес таблицы
    and eax, 0xFFFFF000
    
    ; Получаем адрес записи в таблице страниц
    lea ebx, [eax + edi * 4]
    
    ; Устанавливаем запись
    mov eax, ecx
    or eax, edx
    mov [ebx], eax
    
    popa
    ret
    
.table_alloc_error:
    pop edx
    pop edi
    pop esi
    popa
    ret

; Вспомогательные функции (должны быть определены в других модулях)
extern kprint
extern print_hex
extern allocate_physical_page

section .data
    msg_paging_init db "Страничная память инициализирована", 0x0A, 0
    msg_paging_enabled db "Страничная память включена", 0x0A, 0
    msg_paging_disabled db "Страничная память отключена", 0x0A, 0
    msg_alignment_error db "Ошибка выравнивания при отображении страницы", 0x0A, 0
    msg_page_fault db "Page fault! Виртуальный адрес: ", 0
    msg_fault_address db "Адрес: 0x", 0
    msg_halt db "Система остановлена", 0x0A, 0