; Модуль русской раскладки клавиатуры (ЙЦУКЕН)
; Поддержка кодировки CP866 для VGA текста
bits 32

section .text
    global rus_layout_init
    global rus_scan_to_cp866
    global rus_toggle_caps
    global rus_get_layout_state
    global rus_set_shift_state

; Инициализация русской раскладки
rus_layout_init:
    pusha
    
    ; Сброс состояния CapsLock
    mov byte [rus_caps_lock], 0
    ; Сброс состояния Shift
    mov byte [rus_shift_pressed], 0
    ; Активная раскладка: 0=латиница, 1=кириллица
    mov byte [rus_layout_active], 0
    
    popa
    ret

; Преобразование сканкода в символ CP866 с учётом русской раскладки
; Вход: bl - сканкод, dh - состояние Shift (0=нет, 1=да)
; Выход: al - символ в CP866, 0 если не поддерживается
rus_scan_to_cp866:
    push ebx
    push ecx
    push edx
    push esi
    
    ; Проверка границ сканкода (0x01-0x3A)
    cmp bl, 0x01
    jb .invalid
    cmp bl, 0x3A
    ja .invalid
    
    ; Получаем активную раскладку
    movzx esi, byte [rus_layout_active]
    
    ; Проверяем CapsLock для регистра
    mov cl, 0
    test byte [rus_caps_lock], 1
    jz .no_caps
    mov cl, 1
.no_caps:
    
    ; XOR CapsLock и Shift для определения финального регистра
    xor cl, dh
    ; cl = 0 -> нижний регистр, cl = 1 -> верхний регистр
    
    ; Выбор таблицы на основе раскладки
    test esi, 1
    jz .latin_table
    
    ; Русская раскладка (кириллица)
    movzx eax, bl
    cmp eax, 90          ; Максимальный индекс для русской таблицы
    ja .invalid
    
    ; Выбор таблицы по регистру
    test cl, 1
    jnz .russian_upper
    
    ; Нижний регистр (строчные буквы)
    mov esi, russian_lower_table
    jmp .get_char
    
.russian_upper:
    ; Верхний регистр (заглавные буквы + цифры/символы)
    mov esi, russian_upper_table
    jmp .get_char
    
.latin_table:
    ; Латинская раскладка (оригинальная таблица)
    movzx eax, bl
    cmp eax, 58
    ja .invalid
    
    test cl, 1
    jnz .latin_upper
    
    ; Нижний регистр
    mov esi, latin_lower_table
    jmp .get_char
    
.latin_upper:
    ; Верхний регистр
    mov esi, latin_upper_table
    jmp .get_char
    
.get_char:
    movzx eax, bl
    mov al, [esi + eax]
    jmp .done
    
.invalid:
    xor al, al
    
.done:
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

; Переключение CapsLock
; Обновляет внутреннее состояние
rus_toggle_caps:
    pusha
    xor byte [rus_caps_lock], 1
    popa
    ret

; Переключение раскладки (латиница <-> кириллица)
rus_toggle_layout:
    pusha
    xor byte [rus_layout_active], 1
    popa
    ret

; Получить текущее состояние раскладки
; Выход: al = 0 (латиница) или 1 (кириллица)
rus_get_layout_state:
    movzx eax, byte [rus_layout_active]
    ret

; Установить состояние Shift
; Вход: al = 0 (отпущен) или 1 (нажат)
rus_set_shift_state:
    mov [rus_shift_pressed], al
    ret

; Получить состояние Shift
; Выход: al = 0 или 1
rus_get_shift_state:
    movzx eax, byte [rus_shift_pressed]
    ret

section .data
    ; Флаги состояния
    rus_caps_lock db 0           ; CapsLock状态
    rus_shift_pressed db 0       ; Shift нажат
    rus_layout_active db 0       ; 0=EN, 1=RU
    
    ; Латинская таблица (нижний регистр)
    latin_lower_table:
        db 0, 0, '1', '2', '3', '4', '5', '6', '7', '8'   ; 0x00-0x09
        db '9', '0', '-', '=', 0, 0, 'q', 'w', 'e', 'r'   ; 0x0A-0x13
        db 't', 'y', 'u', 'i', 'o', 'p', '[', ']', 0, 0   ; 0x14-0x1D
        db 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';' ; 0x1E-0x27
        db "'", '`', 0, '\\', 'z', 'x', 'c', 'v', 'b', 'n' ; 0x28-0x31
        db 'm', ',', '.', '/', 0, '*', 0, ' ', 0, 0       ; 0x32-0x3A
    
    ; Латинская таблица (верхний регистр)
    latin_upper_table:
        db 0, 0, '!', '@', '#', '$', '%', '^', '&', '*'   ; 0x00-0x09
        db '(', ')', '_', '+', 0, 0, 'Q', 'W', 'E', 'R'   ; 0x0A-0x13
        db 'T', 'Y', 'U', 'I', 'O', 'P', '{', '}', 0, 0   ; 0x14-0x1D
        db 'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', ':' ; 0x1E-0x27
        db '"', '~', 0, '|', 'Z', 'X', 'C', 'V', 'B', 'N' ; 0x28-0x31
        db 'M', '<', '>', '?', 0, '*', 0, ' ', 0, 0       ; 0x32-0x3A
    
    ; Русская таблица (нижний регистр) - кодировка CP866
    align 16
    russian_lower_table:
        times 0x10 db 0                    ; 0x00-0x0F
        db 134, 135, 136, 137, 138, 139    ; 0x10-0x15: й ц у к е н
        db 140, 141, 142, 143, 144, 145    ; 0x16-0x1B: г ш щ з х ъ
        db 0, 0                            ; 0x1C-0x1D
        db 146, 147, 148, 149, 150, 151    ; 0x1E-0x23: ф ы в а п р
        db 152, 153, 154, 155, 156         ; 0x24-0x28: о л д ж э
        db 0, 0, 0                         ; 0x29-0x2B
        db 157, 158, 159, 160, 161, 162    ; 0x2C-0x31: я ч с м и т
        db 163, 164, 165, 166              ; 0x32-0x35: ь б ю .
        db 0                               ; 0x36
        db 0, 0, 0                         ; 0x37-0x39
        db 0                               ; 0x3A
    
    ; Русская таблица (верхний регистр) - кодировка CP866
    align 16
    russian_upper_table:
        times 0x10 db 0                    ; 0x00-0x0F
        db 138, 151, 148, 139, 133, 142    ; 0x10-0x15: Й Ц У К Е Н
        db 131, 153, 154, 136, 150, 155    ; 0x16-0x1B: Г Ш Щ З Х Ъ
        db 0, 0                            ; 0x1C-0x1D
        db 149, 156, 130, 128, 144, 145    ; 0x1E-0x23: Ф Ы В А П Р
        db 143, 140, 132, 135, 158         ; 0x24-0x28: О Л Д Ж Э
        db 0, 0, 0                         ; 0x29-0x2B
        db 160, 152, 146, 141, 137, 147    ; 0x2C-0x31: Я Ч С М И Т
        db 157, 129, 159, 166              ; 0x32-0x35: Ь Б Ю .
        db 0                               ; 0x36
        db 0, 0, 0                         ; 0x37-0x39
        db 0                               ; 0x3A

section .bss
    ; Буфер для временного хранения
    rus_temp_buffer: resb 1
