; Драйвер клавиатуры для ОС с поддержкой русской раскладки
bits 32

section .text
    global keyboard_get_layout
    global keyboard_set_layout
    extern encoding_init
    extern encoding_translate_char
    extern encoding_handle_layout_toggle
    extern encoding_get_active_layout
    global keyboard_init
    global keyboard_handler
    global read_scan_code
    global keyboard_read_char
    extern interrupt_handler

; Инициализация клавиатуры
keyboard_init:
    ; Разрешение прерываний от клавиатуры (IRQ1)
    ; Отправка команды контроллеру прерываний
    mov al, 0x20
    out 0x20, al
    
    ; Настройка обработчика прерываний для IRQ1 (клавиатура)
    ; Обработчик будет вызываться по адресу 0x21 (33 в десятичной системе)
    
    ; Инициализация буфера
    mov dword [key_buffer_head], 0
    mov dword [key_buffer_tail], 0
    mov dword [key_buffer_count], 0
    
    ret

; Обработчик прерываний клавиатуры
keyboard_handler:
    ; Сохранение регистров
    pusha
    push ds
    push es
    push fs
    push gs
    
    ; Чтение сканкода из порта 0x60
    in al, 0x60
    mov bl, al
    
    ; Проверка на отпускание клавиши (старший бит установлен)
    test al, 0x80
    jnz .key_released
    
    ; Преобразование сканкода в ASCII
    call scancode_to_ascii
    cmp al, 0
    je .skip_store
    
    ; Сохранение ASCII символа в буфер
    mov edi, [key_buffer_head]
    mov [key_buffer + edi], al
    inc edi
    cmp edi, KEY_BUFFER_SIZE
    jl .no_wrap_head
    xor edi, edi
.no_wrap_head:
    mov [key_buffer_head], edi
    
    ; Увеличение счётчика
    inc dword [key_buffer_count]
    
    ; Сохраняем также сканкод для отладки
    mov [last_scan_code], bl
    
    jmp .skip_store
    
.key_released:
    ; Обработка отпускания клавиши (можно отслеживать модификаторы)
    ; Пока просто пропускаем
    and bl, 0x7F  ; Убираем бит отпускания
    mov [last_released_scan_code], bl
    
.skip_store:
    ; Отправка сигнала EOI (End of Interrupt) контроллеру прерываний
    mov al, 0x20
    out 0x20, al
    
    ; Восстановление регистров
    pop gs
    pop fs
    pop es
    pop ds
    popa
    iret

; Функция чтения последнего сканкода
read_scan_code:
    mov al, [last_scan_code]
    ret

; Функция чтения символа из буфера (возвращает 0 если буфер пуст)
; Выход: AL = ASCII символ (0 если нет символа)
keyboard_read_char:
    push ebx
    
    ; Проверяем, есть ли данные в буфере
    mov eax, [key_buffer_count]
    test eax, eax
    jz .empty
    
    ; Читаем символ из хвоста буфера
    mov ebx, [key_buffer_tail]
    mov al, [key_buffer + ebx]
    
    ; Увеличиваем хвост
    inc ebx
    cmp ebx, KEY_BUFFER_SIZE
    jl .no_wrap_tail
    xor ebx, ebx
.no_wrap_tail:
    mov [key_buffer_tail], ebx
    
    ; Уменьшаем счётчик
    dec dword [key_buffer_count]
    
    ; Возвращаем символ в AL
    pop ebx
    ret
    
.empty:
    xor al, al
    pop ebx
    ret

; Преобразование сканкода в ASCII (упрощённая таблица для US QWERTY)
; Вход: BL = сканкод
; Выход: AL = ASCII символ (0 если непечатаемый)
scancode_to_ascii:
    push ebx
    push ecx
    
    ; Проверяем границы
    cmp bl, 0x01
    jb .invalid
    cmp bl, 0x3A
    ja .invalid
    
    ; Используем таблицу
    movzx ecx, bl
    mov al, [scancode_table + ecx]
    jmp .done
    
.invalid:
    xor al, al
    
.done:
    pop ecx
    pop ebx
    ret

section .data
    ; Таблица преобразования сканкодов в ASCII (для US QWERTY, без Shift)
    scancode_table:
        db 0, 0, '1', '2', '3', '4', '5', '6', '7', '8'   ; 0x00-0x09
        db '9', '0', '-', '=', 0, 0, 'q', 'w', 'e', 'r'   ; 0x0A-0x13
        db 't', 'y', 'u', 'i', 'o', 'p', '[', ']', 0, 0   ; 0x14-0x1D
        db 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';' ; 0x1E-0x27
        db "'", '`', 0, '\', 'z', 'x', 'c', 'v', 'b', 'n' ; 0x28-0x31
        db 'm', ',', '.', '/', 0, '*', 0, ' ', 0, 0       ; 0x32-0x3A
    
    last_scan_code db 0
    last_released_scan_code db 0

section .bss
    ; Буфер для символов (кольцевой буфер)
    KEY_BUFFER_SIZE equ 256
    key_buffer: resb KEY_BUFFER_SIZE
    key_buffer_head: resd 1
    key_buffer_tail: resd 1
    key_buffer_count: resd 1
; Получить текущую раскладку
; Выход: EAX = 0 (English) или 1 (Russian)
keyboard_get_layout:
    push ebx
    call encoding_get_active_layout
    pop ebx
    ret

; Установить раскладку
; Вход: EAX = 0 (English) или 1 (Russian)
keyboard_set_layout:
    push ebx
    call encoding_set_active_layout
    pop ebx
    ret

; Переопределение scancode_to_ascii для поддержки русской раскладки
; Теперь использует модуль encoding
scancode_to_ascii_new:
    push ebx
    push ecx
    push edx
    
    ; Получаем состояние модификаторов
    movzx ecx, bl          ; ECX = сканкод
    xor ebx, ebx
    
    ; Проверяем Shift
    cmp byte [shift_pressed], 0
    je .no_shift
    or ebx, 0x01           ; Бит 0 = Shift
.no_shift:
    
    ; Проверяем Ctrl
    cmp byte [ctrl_pressed], 0
    je .no_ctrl
    or ebx, 0x02           ; Бит 1 = Ctrl
.no_ctrl:
    
    ; Проверяем Alt
    cmp byte [alt_pressed], 0
    je .no_alt
    or ebx, 0x04           ; Бит 2 = Alt
.no_alt:
    
    ; Вызываем функцию перевода с учётом раскладки
    ; BL = сканкод, BH = модификаторы
    mov bl, cl
    call encoding_translate_char
    
    ; Если CF=1 (нет символа), возвращаем 0
    jc .no_char
    
    pop edx
    pop ecx
    pop ebx
    ret
    
.no_char:
    xor al, al
    pop edx
    pop ecx
    pop ebx
    ret

section .bss
    shift_pressed: resb 1
    ctrl_pressed: resb 1
    alt_pressed: resb 1
    caps_lock: resb 1
