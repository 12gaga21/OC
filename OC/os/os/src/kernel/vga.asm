; Расширенный драйвер VGA для ОС "UNIVERSAL ASM CORE"
; Стиль: Индустриальный монохром (Зеленый терминал)
; Совместимость: Универсальный интерфейс без нарушения авторских прав
bits 32

section .text
    global vga_init
    global vga_put_char
    global vga_put_string
    global vga_clear_screen
    global vga_set_color
    global vga_set_cursor

; Цветовая палитра "Индустриальный Стандарт"
; 0x0A = Зеленый текст на черном фоне (Классический терминал)
; 0x0F = Белый на черном (Предупреждения)
; 0x02 = Темно-зеленый (Фон)
DEFAULT_COLOR_VALUE equ 0x0A
WARNING_COLOR_VALUE equ 0x0F

; Инициализация VGA
vga_init:
    ; Установка режима 80x25 текстовый цветной (0x03)
    mov ax, 0x03
    int 0x10
    
    ; Очистка экрана
    call vga_clear_screen
    
    ; Установка цвета по умолчанию (Зеленый терминал)
    mov byte [default_color], DEFAULT_COLOR_VALUE
    
    ; Установка позиции курсора в начало
    mov word [cursor_x], 0
    mov word [cursor_y], 0
    
    ; Вывод приветственного сообщения системы
    push si
    mov si, init_message
    call vga_put_string
    pop si
    
    ret

init_message:
    db 0x0D, 0x0A
    db "[СИСТЕМА] Инициализация визуального протокола...", 0x0D, 0x0A
    db "[ЯДРО] Синхронизация матрицы дисплея...", 0x0D, 0x0A
    db "[ГОТОВО] Терминал активен.", 0x0D, 0x0A
    db 0

; Вывод символа в текущую позицию курсора
; Вход: al - символ для вывода
vga_put_char:
    pusha
    push es
    
    ; Проверка специальных символов
    cmp al, 0x08  ; Backspace
    je .backspace
    cmp al, 0x09  ; Tab
    je .tab
    cmp al, 0x0A  ; Newline
    je .newline
    cmp al, 0x0D  ; Carriage return
    je .carriage_return
    
    ; Обычный символ
    call .put_char_at_cursor
    call .move_cursor_right
    jmp .done
    
.backspace:
    call .move_cursor_left
    mov al, ' '
    call .put_char_at_cursor
    call .move_cursor_left
    jmp .done
    
.tab:
    ; Перемещение курсора к следующей позиции, кратной 8
    mov ax, [cursor_x]
    add ax, 8
    and ax, 0xFFF8  ; Округление до ближайшего меньшего кратного 8
    mov [cursor_x], ax
    call .update_cursor
    jmp .done
    
.newline:
    mov word [cursor_x], 0
    call .move_cursor_down
    jmp .done
    
.carriage_return:
    mov word [cursor_x], 0
    call .update_cursor
    jmp .done
    
.put_char_at_cursor:
    ; Вычисление адреса в видеопамяти
    mov eax, [cursor_y]
    mov ebx, 80
    mul ebx
    add eax, [cursor_x]
    mov ebx, 2
    mul ebx
    mov edi, 0xB8000
    add edi, eax
    
    ; Запись символа и атрибута цвета
    mov ah, [default_color]
    mov [es:edi], ax
    
    ret
    
.move_cursor_right:
    inc word [cursor_x]
    mov ax, [cursor_x]
    cmp ax, 80
    jl .no_wrap
    mov word [cursor_x], 0
    call .move_cursor_down
.no_wrap:
    call .update_cursor
    ret
    
.move_cursor_left:
    cmp word [cursor_x], 0
    jg .not_at_start
    ; Если в начале строки, перемещаемся в конец предыдущей строки
    cmp word [cursor_y], 0
    jle .already_at_start
    mov word [cursor_x], 79
    dec word [cursor_y]
    jmp .update_cursor
.not_at_start:
    dec word [cursor_x]
.already_at_start:
    call .update_cursor
    ret
    
.move_cursor_down:
    inc word [cursor_y]
    mov ax, [cursor_y]
    cmp ax, 25
    jl .no_scroll
    ; Прокрутка экрана
    call .scroll_screen
    dec word [cursor_y]
.no_scroll:
    call .update_cursor
    ret
    
.update_cursor:
    ; Обновление позиции курсора на экране
    mov ax, [cursor_y]
    mov bx, 80
    mul bx
    add ax, [cursor_x]
    
    mov dx, 0x3D4
    mov al, 0x0F
    out dx, al
    mov dx, 0x3D5
    out dx, al
    
    mov dx, 0x3D4
    mov al, 0x0E
    out dx, al
    mov dx, 0x3D5
    mov al, ah
    out dx, al
    
    ret
    
.scroll_screen:
    pusha
    
    ; Копирование строк с 1 по 24 в строки с 0 по 23
    mov esi, 0xB8000 + 160  ; Вторая строка
    mov edi, 0xB8000         ; Первая строка
    mov ecx, 160 * 24 / 4    ; 24 строки по 160 байт (80 символов * 2 байта)
    rep movsd
    
    ; Очистка последней строки
    mov edi, 0xB8000 + 160 * 24  ; Последняя строка
    mov al, ' '
    mov ah, [default_color]
    mov ecx, 80
.clear_loop:
    mov [es:edi], ax
    add edi, 2
    loop .clear_loop
    
    popa
    ret

; Вывод строки в текущую позицию курсора
; Вход: esi - адрес строки (завершается нулем)
vga_put_string:
    pusha
    
.loop:
    mov al, [esi]
    test al, al
    jz .done
    
    call vga_put_char
    inc esi
    jmp .loop
    
.done:
    popa
    ret

; Очистка экрана
vga_clear_screen:
    pusha
    push es
    
    ; Установка сегмента ES на видеопамять
    mov ax, 0xB800
    mov es, ax
    
    ; Очистка экрана пробелами
    mov edi, 0
    mov al, ' '
    mov ah, [default_color]
    mov ecx, 80 * 25
.clear_loop:
    mov [es:edi], ax
    add edi, 2
    loop .clear_loop
    
    ; Установка курсора в начало
    mov word [cursor_x], 0
    mov word [cursor_y], 0
    call .update_cursor
    
    pop es
    popa
    ret

; Установка цвета текста и фона
; Вход: al - атрибут цвета
vga_set_color:
    mov [default_color], al
    ret

; Установка позиции курсора
; Вход: ah - строка (0-24), al - столбец (0-79)
vga_set_cursor:
    mov [cursor_y], ah
    mov [cursor_x], al
    call .update_cursor
    ret

section .data
    default_color db 0x07  ; Светло-серый на черном по умолчанию

section .bss
    cursor_x resw 1        ; Позиция курсора по X (столбец)
    cursor_y resw 1        ; Позиция курсора по Y (строка)