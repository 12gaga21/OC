; ============================================================================
; TUI.ASM - Текстовый Пользовательский Интерфейс (TUI)
; Стиль: "ЗЛАТО-ИЗУМРУДНЫЙ РИТУАЛЪ" (Warhammer Mechanicus + РПЦ)
; Цвета: Зеленый текст, Золотые рамки, Красные ошибки
; Орфография: Дореформенная (ѣ, і, ъ, ѣ)
; Авторъ: Адептъ Кодификатус
; Дата: Лѣто 2026 отъ Р.Х.
; ============================================================================

[BITS 32]

SECTION .data

; ============================================================================
; КОНСТАНТЫ ЦВѢТОВЪ (ЗЛАТО-ИЗУМРУДНЫЙ СТИЛЬ)
; ============================================================================
COLOR_TEXT_GREEN      equ 0x0A    ; Изумрудный текст (Механикус)
COLOR_BORDER_GOLD     equ 0x1E    ; Золотая рамка на синем (Церковь)
COLOR_ERROR_RED       equ 0x0C    ; Красная ошибка
COLOR_HIGHLIGHT_WHITE equ 0x1F    ; Белый акцент
COLOR_BG_BLUE         equ 0x01    ; Темно-синій фонъ

; Символы для рамокъ въ церковномъ стилѣ
CHAR_BORDER_TL        equ '†'     ; Верхній лѣвый уголъ (Крестъ)
CHAR_BORDER_TR        equ '†'     ; Верхній правый уголъ
CHAR_BORDER_BL        equ '⌊'     ; Нижній лѣвый уголъ
CHAR_BORDER_BR        equ '⌋'     ; Нижній правый уголъ
CHAR_BORDER_H         equ '═'     ; Горизонтальная линія
CHAR_BORDER_V         equ '║'     ; Вертикальная линія
CHAR_BORDER_CROSS     equ '╬'     ; Пересѣченіе

; Буферъ для заголовковъ
window_title_buf: times 64 db 0

; ============================================================================
; СТРУКТУРА ОКНА
; ============================================================================
struc WINDOW
    .x: resd 1          ; Координата X
    .y: resd 1          ; Координата Y
    .width: resd 1      ; Ширина
    .height: resd 1     ; Высота
    .title_ptr: resd 1  ; Указатель на заголовокъ
    .border_color: resb 1 ; Цветъ рамки
    .text_color: resb 1   ; Цветъ текста
endstruc

; Текущее активное окно
current_window: times 16 db 0  ; Максимумъ 16 оконъ
window_count: dd 0

SECTION .bss

; Буферъ для отрисовки рамки
frame_buffer: resb 512

SECTION .text

GLOBAL tui_init
GLOBAL tui_create_window
GLOBAL tui_draw_window
GLOBAL tui_draw_box
GLOBAL tui_print_at
GLOBAL tui_print_centered
GLOBAL tui_clear_screen
GLOBAL tui_set_cursor
GLOBAL tui_show_error
GLOBAL tui_show_message
GLOBAL tui_destroy_window
GLOBAL tui_shutdown

; ============================================================================
; ФУНКЦІЯ: tui_init
; ОПИСАНІЕ: Иніціализація TUI子系统
; ВХОДЪ: Нѣтъ
; ВЫХОДЪ: EAX = 0 (успѣхъ)
; ============================================================================
tui_init:
    pusha
    
    ; Очистить счетчикъ оконъ
    mov dword [window_count], 0
    
    ; Очистить экранъ стандартнымъ цветомъ
    call tui_clear_screen
    
    ; Нарисовать главный заголовокъ
    mov esi, holy_greeting
    mov eax, 0
    mov ebx, 0
    mov ecx, COLOR_BORDER_GOLD
    call tui_print_centered
    
    popa
    xor eax, eax
    ret

; ============================================================================
; ФУНКЦІЯ: tui_create_window
; ОПИСАНІЕ: Созданіе новаго окна
; ВХОДЪ: ESI = указатель на структуру WINDOW
;        EDI = указатель на заголовокъ (ASCIZ)
;        EAX = X, EBX = Y, ECX = ширина, EDX = высота
; ВЫХОДЪ: EAX = ID окна (0..15) или -1 (ошибка)
; ============================================================================
tui_create_window:
    pusha
    
    ; Проверить лимитъ оконъ
    mov eax, [window_count]
    cmp eax, 16
    jge .error_no_windows
    
    ; Сохранить параметры въ структурѣ
    mov [esi + WINDOW.x], eax
    mov [esi + WINDOW.y], ebx
    mov [esi + WINDOW.width], ecx
    mov [esi + WINDOW.height], edx
    mov [esi + WINDOW.title_ptr], edi
    mov byte [esi + WINDOW.border_color], COLOR_BORDER_GOLD
    mov byte [esi + WINDOW.text_color], COLOR_TEXT_GREEN
    
    ; Увеличить счетчикъ
    inc dword [window_count]
    
    ; Вернуть ID
    mov eax, [window_count]
    dec eax
    jmp .success
    
.error_no_windows:
    mov eax, -1
    
.success:
    popa
    ret

; ============================================================================
; ФУНКЦІЯ: tui_draw_window
; ОПИСАНІЕ: Отрисовка окна съ рамкой и заголовкомъ
; ВХОДЪ: ESI = указатель на структуру WINDOW
; ВЫХОДЪ: Нѣтъ
; ============================================================================
tui_draw_window:
    pusha
    
    mov eax, [esi + WINDOW.x]
    mov ebx, [esi + WINDOW.y]
    mov ecx, [esi + WINDOW.width]
    mov edx, [esi + WINDOW.height]
    mov edi, [esi + WINDOW.title_ptr]
    movzx ebp, byte [esi + WINDOW.border_color]
    movzx esi, byte [esi + WINDOW.text_color]
    
    ; Нарисовать рамку
    push eax
    push ebx
    push ecx
    push edx
    push ebp
    call tui_draw_box
    add esp, 20
    
    ; Напечатать заголовокъ по центру верхней границы
    ; (упрощенно - просто въ верхней части)
    mov eax, [esi + WINDOW.x]
    add eax, 2
    mov ebx, [esi + WINDOW.y]
    mov esi, edi
    mov ecx, ebp
    ; Вызовъ tui_print_at будетъ добавленъ въ будущемъ
    
    popa
    ret

; ============================================================================
; ФУНКЦІЯ: tui_draw_box
; ОПИСАНІЕ: Рисованіе прямоугольной рамки въ церковномъ стилѣ
; ВХОДЪ: EAX = X, EBX = Y, ECX = ширина, EDX = высота, EBP = цветъ рамки
; ВЫХОДЪ: Нѣтъ
; ============================================================================
tui_draw_box:
    pusha
    push eax
    push ebx
    push ecx
    push edx
    push ebp
    
    ; Сохранить координаты
    mov edi, eax        ; start_x
    mov esi, ebx        ; start_y
    mov ebp, ecx        ; width
    mov r12d, edx       ; height
    movzx r13d, bp      ; color
    
    ; --- Верхняя граница ---
    mov eax, edi
    mov ebx, esi
    mov ecx, CHAR_BORDER_TL    ; †
    push r13d
    call vga_put_char_attr     ; Левый верхній уголъ
    add esp, 4
    
    ; Горизонтальная линія
    mov ecx, 2
.upper_line_loop:
    cmp ecx, ebp
    jge .upper_done
    mov eax, edi
    add eax, ecx
    mov ebx, esi
    mov ecx, CHAR_BORDER_H     ; ═
    push r13d
    call vga_put_char_attr
    add esp, 4
    inc ecx
    jmp .upper_line_loop
    
.upper_done:
    mov eax, edi
    add eax, ebp
    dec eax
    mov ebx, esi
    mov ecx, CHAR_BORDER_TR    ; †
    push r13d
    call vga_put_char_attr
    add esp, 4
    
    ; --- Боковыя границы ---
    mov ecx, 1
.side_loop:
    cmp ecx, r12d
    jge .side_done
    
    ; Левая вертикаль
    mov eax, edi
    mov ebx, esi
    add ebx, ecx
    mov ecx, CHAR_BORDER_V     ; ║
    push r13d
    call vga_put_char_attr
    add esp, 4
    
    ; Правая вертикаль
    mov eax, edi
    add eax, ebp
    dec eax
    mov ebx, esi
    add ebx, ecx
    mov ecx, CHAR_BORDER_V
    push r13d
    call vga_put_char_attr
    add esp, 4
    
    inc ecx
    jmp .side_loop
    
.side_done:
    ; --- Нижняя граница ---
    mov eax, edi
    mov ebx, esi
    add ebx, r12d
    dec ebx
    mov ecx, CHAR_BORDER_BL    ; ⌊
    push r13d
    call vga_put_char_attr
    add esp, 4
    
    ; Горизонтальная линія внизу
    mov ecx, 2
.lower_line_loop:
    cmp ecx, ebp
    jge .lower_done
    mov eax, edi
    add eax, ecx
    mov ebx, esi
    add ebx, r12d
    dec ebx
    mov ecx, CHAR_BORDER_H
    push r13d
    call vga_put_char_attr
    add esp, 4
    inc ecx
    jmp .lower_line_loop
    
.lower_done:
    mov eax, edi
    add eax, ebp
    dec eax
    mov ebx, esi
    add ebx, r12d
    dec ebx
    mov ecx, CHAR_BORDER_BR    ; ⌋
    push r13d
    call vga_put_char_attr
    add esp, 4
    
    pop ebp
    pop edx
    pop ecx
    pop ebx
    pop eax
    popa
    ret

; ============================================================================
; ФУНКЦІЯ: tui_print_at
; ОПИСАНІЕ: Печать строки въ указанной позиціи
; ВХОДЪ: EAX = X, EBX = Y, ESI = строка, ECX = цветъ
; ВЫХОДЪ: Нѣтъ
; ============================================================================
tui_print_at:
    pusha
    push eax
    push ebx
    push esi
    push ecx
    
.print_loop:
    lodsb
    test al, al
    jz .done
    push ecx
    call vga_put_char_attr
    add esp, 4
    inc dword [eax]  ; Увеличить X (временное рѣшеніе)
    jmp .print_loop
    
.done:
    pop ecx
    pop esi
    pop ebx
    pop eax
    popa
    ret

; ============================================================================
; ФУНКЦІЯ: tui_print_centered
; ОПИСАНІЕ: Печать строки по центру экрана
; ВХОДЪ: ESI = строка, EAX = Y, ECX = цветъ
; ВЫХОДЪ: Нѣтъ
; ============================================================================
tui_print_centered:
    pusha
    push esi
    push eax
    push ecx
    
    ; Вычислить длину строки
    mov edi, esi
    xor edx, edx
.len_loop:
    lodsb
    test al, al
    jz .len_done
    inc edx
    jmp .len_loop
    
.len_done:
    ; Центр = (80 - длина) / 2
    mov eax, 80
    sub eax, edx
    shr eax, 1
    
    ; Восстановить указатель
    mov esi, [esp + 4]  ; original esi
    
    ; Печатать
    mov ebx, [esp + 8]  ; Y
    mov ecx, [esp + 12] ; color
    call tui_print_at
    
    pop ecx
    pop eax
    pop esi
    popa
    ret

; ============================================================================
; ФУНКЦІЯ: tui_clear_screen
; ОПИСАНІЕ: Очистка экрана съ установленнымъ цветомъ фона
; ВХОДЪ: Нѣтъ
; ВЫХОДЪ: Нѣтъ
; ============================================================================
tui_clear_screen:
    pusha
    
    ; Использовать стандартную функцию очистки
    ; съ нашимъ фирменнымъ цветомъ
    mov ax, 0x0600      ; AH=06 (scroll up), AL=00 (clear all)
    mov bh, COLOR_BG_BLUE ; Синій фонъ
    mov cx, 0
    mov dx, 0x184F      ; 80x25
    int 0x10
    
    ; Установить курсоръ въ 0,0
    mov ah, 0x02
    mov bh, 0
    mov dx, 0
    int 0x10
    
    popa
    ret

; ============================================================================
; ФУНКЦІЯ: tui_set_cursor
; ОПИСАНІЕ: Установка позиціи курсора
; ВХОДЪ: EAX = X, EBX = Y
; ВЫХОДЪ: Нѣтъ
; ============================================================================
tui_set_cursor:
    pusha
    mov ah, 0x02
    mov bh, 0
    shl ebx, 8
    or bl, al
    mov dh, bh
    mov dl, al
    int 0x10
    popa
    ret

; ============================================================================
; ФУНКЦІЯ: tui_show_error
; ОПИСАНІЕ: Показъ сообщенія объ ошибкѣ (красный цветъ)
; ВХОДЪ: ESI = текстъ ошибки
; ВЫХОДЪ: Нѣтъ
; ============================================================================
tui_show_error:
    pusha
    push esi
    
    ; Заголовокъ
    mov esi, error_title
    mov eax, 0
    mov ebx, 12
    mov ecx, COLOR_ERROR_RED
    call tui_print_centered
    
    ; Текстъ ошибки
    pop esi
    mov eax, 0
    mov ebx, 14
    mov ecx, COLOR_ERROR_RED
    call tui_print_centered
    
    ; Подсказка
    mov esi, error_hint
    mov eax, 0
    mov ebx, 16
    mov ecx, COLOR_TEXT_GREEN
    call tui_print_centered
    
    popa
    ret

; ============================================================================
; ФУНКЦІЯ: tui_show_message
; ОПИСАНІЕ: Показъ обычнаго сообщенія
; ВХОДЪ: ESI = текстъ, EAX = Y
; ВЫХОДЪ: Нѣтъ
; ============================================================================
tui_show_message:
    pusha
    push esi
    push eax
    
    mov ecx, COLOR_TEXT_GREEN
    call tui_print_centered
    
    pop eax
    pop esi
    popa
    ret

; ============================================================================
; ФУНКЦІЯ: tui_destroy_window
; ОПИСАНІЕ: Удаленіе окна
; ВХОДЪ: EAX = ID окна
; ВЫХОДЪ: EAX = 0 (успѣхъ) или -1
; ============================================================================
tui_destroy_window:
    pusha
    ; Упрощенная реализація - просто уменьшаемъ счетчикъ
    dec dword [window_count]
    xor eax, eax
    popa
    ret

; ============================================================================
; ФУНКЦІЯ: tui_shutdown
; ОПИСАНІЕ: Завершѣніе работы TUI
; ВХОДЪ: Нѣтъ
; ВЫХОДЪ: Нѣтъ
; ============================================================================
tui_shutdown:
    pusha
    call tui_clear_screen
    popa
    ret

; ============================================================================
; СТРОКОВЫЯ КОНСТАНТЫ
; ============================================================================
holy_greeting: db '† ВСЕМОСТИВЫЙ ГОСУДАРЬ †', 0
error_title: db '† ОШИБКА †', 0
error_hint: db 'Требуется покаяніе и повтореніе ритуала', 0

; ============================================================================
; ВСПОМОГАТЕЛЬНЫЯ ФУНКЦІИ VGA (заглушки для интеграціи)
; ============================================================================
vga_put_char_attr:
    ; Реальная функція будетъ вызываться изъ vga.asm
    ; Сейчас заглушка
    ret

%ifidn __OUTPUT_FORMAT__, elf32
section .note.GNU-stack noalloc noexec nowrite progbits
%endif
