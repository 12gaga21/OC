; Полный VGA драйвер для ОС на ассемблере
bits 32

section .text
    global vga_init
    global kprint
    global kprint_color
    global clear_screen
    global terminal_setcolor
    global terminal_putentryat
    global terminal_scroll
    global terminal_newline
    global terminal_putchar

; Инициализация VGA драйвера
vga_init:
    pusha
    
    ; Инициализация переменных
    mov byte [terminal_row], 0
    mov byte [terminal_column], 0
    mov byte [terminal_color], 0x07  ; Светло-серый на черном
    mov dword [terminal_buffer], 0xb8000
    
    ; Очистка экрана
    call clear_screen
    
    popa
    ret

; Установка цвета терминала
; Вход: al - цвет
terminal_setcolor:
    mov [terminal_color], al
    ret

; Вывод символа в позицию
; Вход: al - символ, ah - цвет, bl - x, cl - y
terminal_putentryat:
    pusha
    
    ; Вычисление индекса в буфере терминала
    ; index = y * VGA_WIDTH + x
    movzx edx, cl        ; y
    mov ebx, 80          ; VGA_WIDTH
    mul ebx, edx
    movzx edx, bl        ; x
    add eax, edx
    
    ; index *= 2 (каждый символ занимает 2 байта)
    shl eax, 1
    
    ; Добавление базового адреса видеопамяти
    add eax, 0xb8000
    mov edi, eax
    
    ; Запись символа и цвета в видеопамять
    mov ah, [terminal_color]
    mov [edi], ax
    
    popa
    ret

; Прокрутка экрана вверх
terminal_scroll:
    pusha
    
    ; Сдвигаем все строки вверх
    mov esi, 0xb8000 + 160    ; Вторая строка
    mov edi, 0xb8000          ; Первая строка
    mov ecx, 160 * 24 / 4     ; 24 строки по 160 байт (80 символов * 2 байта)
    rep movsd
    
    ; Очищаем последнюю строку
    mov edi, 0xb8000 + 160 * 24  ; Последняя строка
    mov al, ' '
    mov ah, [terminal_color]
    mov ecx, 80
.clear_loop:
    mov [edi], ax
    add edi, 2
    loop .clear_loop
    
    popa
    ret

; Перемещение курсора в новую строку
terminal_newline:
    pusha
    
    mov byte [terminal_column], 0
    inc byte [terminal_row]
    
    ; Если достигли конца экрана, прокручиваем
    cmp byte [terminal_row], 25
    jl .no_scroll
    
    call terminal_scroll
    mov byte [terminal_row], 24
    
.no_scroll:
    popa
    ret

; Вывод символа
terminal_putchar:
    pusha
    
    ; Проверка специальных символов
    cmp al, 0x0A  ; \n
    je .newline
    cmp al, 0x0D  ; \\r
    je .carriage_return
    
    ; Проверка на конец строки
    cmp byte [terminal_column], 80
    jl .no_wrap
    
    call terminal_newline
    
.no_wrap:
    ; Выводим символ
    movzx ebx, byte [terminal_column]
    movzx ecx, byte [terminal_row]
    call terminal_putentryat
    
    inc byte [terminal_column]
    jmp .done
    
.newline:
    call terminal_newline
    jmp .done
    
.carriage_return:
    mov byte [terminal_column], 0
    
.done:
    popa
    ret

; Вывод строки
; Вход: esi - адрес строки (завершается нулем)
kprint:
    pusha
    
.loop:
    mov al, [esi]
    test al, al
    jz .done
    
    call terminal_putchar
    inc esi
    jmp .loop
    
.done:
    popa
    ret

; Вывод строки с указанным цветом
; Вход: esi - адрес строки, al - цвет
kprint_color:
    pusha
    
    ; Сохраняем текущий цвет
    mov bl, [terminal_color]
    
    ; Устанавливаем новый цвет
    call terminal_setcolor
    
    ; Выводим строку
    call kprint
    
    ; Восстанавливаем старый цвет
    mov [terminal_color], bl
    
    popa
    ret

; Очистка экрана
clear_screen:
    pusha
    
    mov edi, 0xb8000
    mov al, ' '
    mov ah, [terminal_color]
    mov ecx, 80 * 25
.loop:
    mov [edi], ax
    add edi, 2
    loop .loop
    
    mov byte [terminal_row], 0
    mov byte [terminal_column], 0
    
    popa
    ret

section .data
    terminal_row db 0
    terminal_column db 0
    terminal_color db 0x07
    terminal_buffer dd 0xb8000

section .bss
