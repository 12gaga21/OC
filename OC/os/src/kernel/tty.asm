; ============================================================================
; OS Project - Virtual Terminal (TTY) Module
; File: os/src/kernel/tty.asm
; Description: Абстракция виртуального терминала с буферизацией, прокруткой
;              и поддержкой кодировок. Управляет выводом текста на экран.
; Author: AI Assistant
; License: MIT
; ============================================================================

BITS 32

SECTION .text

; -----------------------------------------------------------------------------
; Глобальные переменные и константы
; -----------------------------------------------------------------------------

; Константы экрана
VIDEO_MEMORY      equ 0xB8000
SCREEN_WIDTH      equ 80
SCREEN_HEIGHT     equ 25
SCREEN_SIZE       equ SCREEN_WIDTH * SCREEN_HEIGHT * 2  ; 2 байта на символ (символ + атрибут)
BUFFER_SIZE       equ SCREEN_SIZE                       ; Размер буфера экрана

; Цвета атрибутов (фон << 4 | передний план)
COLOR_BLACK       equ 0x00
COLOR_BLUE        equ 0x01
COLOR_GREEN       equ 0x02
COLOR_CYAN        equ 0x03
COLOR_RED         equ 0x04
COLOR_MAGENTA     equ 0x05
COLOR_BROWN       equ 0x06
COLOR_LIGHT_GRAY  equ 0x07
COLOR_DARK_GRAY   equ 0x08
COLOR_LIGHT_BLUE  equ 0x09
COLOR_LIGHT_GREEN equ 0x0A
COLOR_LIGHT_CYAN  equ 0x0B
COLOR_LIGHT_RED   equ 0x0C
COLOR_LIGHT_MAGENTA equ 0x0D
COLOR_YELLOW      equ 0x0E
COLOR_WHITE       equ 0x0F

; Стандартный атрибут (серый текст на черном фоне)
DEFAULT_ATTR      equ (COLOR_LIGHT_GRAY << 4) | COLOR_WHITE

; -----------------------------------------------------------------------------
; Структура состояния TTY
; Хранится в секции .bss
; -----------------------------------------------------------------------------

SECTION .bss

; Буфер экрана (копия видеопамяти для безопасной работы)
align 16
tty_screen_buffer:  resb BUFFER_SIZE

; Позиция курсора (в символах, 0..1999)
tty_cursor_pos:     resd 1

; Текущий цвет атрибута
tty_current_attr:   resb 1

; Флаг видимости курсора
tty_cursor_visible: resb 1

; Счетчик строк для прокрутки (отладка)
tty_scroll_count:   resd 1

; -----------------------------------------------------------------------------
; Экспорт функций
; -----------------------------------------------------------------------------

GLOBAL tty_init
GLOBAL tty_clear
GLOBAL tty_putchar
GLOBAL tty_putstr
GLOBAL tty_putstr_color
GLOBAL tty_set_cursor
GLOBAL tty_get_cursor
GLOBAL tty_move_cursor
GLOBAL tty_scroll_up
GLOBAL tty_set_color
GLOBAL tty_get_color
GLOBAL tty_enable_cursor
GLOBAL tty_disable_cursor
GLOBAL tty_update_cursor_hw
GLOBAL tty_refresh
GLOBAL tty_print_hex
GLOBAL tty_print_dec
GLOBAL tty_newline

; -----------------------------------------------------------------------------
; Функция: tty_init
; Описание: Инициализация терминала. Очистка буфера, установка курсора.
; Вход: Нет
; Выход: Нет
; -----------------------------------------------------------------------------
tty_init:
    pushad

    ; Инициализация переменных
    mov dword [tty_cursor_pos], 0
    mov byte [tty_current_attr], DEFAULT_ATTR
    mov byte [tty_cursor_visible], 1
    mov dword [tty_scroll_count], 0

    ; Очистка буфера экрана
    call tty_clear

    ; Показать курсор
    call tty_enable_cursor

    ; Первоначальная отрисовка
    call tty_refresh

    popad
    ret

; -----------------------------------------------------------------------------
; Функция: tty_clear
; Описание: Полная очистка экрана и сброс курсора в (0,0)
; Вход: Нет
; Выход: Нет
; -----------------------------------------------------------------------------
tty_clear:
    pushad

    ; Заполнение буфера пробелами с текущим атрибутом
    mov edi, tty_screen_buffer
    mov ecx, SCREEN_SIZE / 2          ; Количество слов (2 байта)
    mov ax, 0x0720                    ; Атрибут 0x07 (серый), символ пробел
    rep stosw

    ; Сброс курсора
    mov dword [tty_cursor_pos], 0

    ; Обновление железа
    call tty_refresh
    call tty_update_cursor_hw

    popad
    ret

; -----------------------------------------------------------------------------
; Функция: tty_putchar
; Описание: Вывод одного символа в текущую позицию курсора с авто-прокруткой
; Вход: AL = символ
; Выход: Нет
; -----------------------------------------------------------------------------
tty_putchar:
    pushad
    movzx ebx, al                     ; Сохраняем символ в EBX

    ; Проверка на управляющие символы
    cmp bl, 0x0D                      ; Carriage Return (\r)
    je .handle_cr
    cmp bl, 0x0A                      ; Line Feed (\n)
    je .handle_lf
    cmp bl, 0x08                      ; Backspace (\b)
    je .handle_bs
    cmp bl, 0x09                      ; Tab (\t)
    je .handle_tab

    ; Обычный символ
    mov edi, [tty_cursor_pos]
    cmp edi, SCREEN_WIDTH * SCREEN_HEIGHT
    jge .scroll_and_print             ; Если курсор за пределами экрана

    ; Вычисление адреса в буфере: pos * 2
    shl edi, 1
    add edi, tty_screen_buffer

    ; Запись символа и атрибута
    mov [edi], bl                     ; Символ
    mov [edi+1], byte [tty_current_attr] ; Атрибут

    ; Перемещение курсора вперед
    inc dword [tty_cursor_pos]
    jmp .check_wrap

.handle_cr:
    ; Возврат каретки: курсор в начало строки
    mov eax, [tty_cursor_pos]
    mov ebx, SCREEN_WIDTH
    div ebx
    mul ebx                           ; Округление вниз до начала строки
    mov [tty_cursor_pos], eax
    jmp .done

.handle_lf:
    ; Перевод строки
    call tty_newline
    jmp .done

.handle_bs:
    ; Backspace
    mov eax, [tty_cursor_pos]
    test eax, eax
    jz .done                          ; Если уже в начале
    dec dword [tty_cursor_pos]
    
    ; Очистка предыдущего символа
    mov edi, [tty_cursor_pos]
    shl edi, 1
    add edi, tty_screen_buffer
    mov word [edi], 0x0720            ; Пробел
    jmp .done

.handle_tab:
    ; Tab (до следующей табуляции, шаг 4)
    mov eax, [tty_cursor_pos]
    mov ebx, 4
    div ebx
    inc eax
    mul ebx
    cmp eax, SCREEN_WIDTH * SCREEN_HEIGHT
    jge .done
    mov [tty_cursor_pos], eax
    jmp .done

.scroll_and_print:
    ; Если буфер полон, скроллим и печатаем в последней строке
    call tty_scroll_up
    ; После скролла курсор должен быть в начале последней строки
    mov eax, SCREEN_WIDTH * (SCREEN_HEIGHT - 1)
    mov [tty_cursor_pos], eax
    ; Рекурсивный вызов для печати самого символа (теперь место есть)
    ; Но чтобы избежать рекурсии, просто запишем вручную
    mov edi, [tty_cursor_pos]
    shl edi, 1
    add edi, tty_screen_buffer
    mov [edi], bl
    mov [edi+1], byte [tty_current_attr]
    inc dword [tty_cursor_pos]
    jmp .check_wrap

.check_wrap:
    ; Проверка перехода на новую строку
    mov eax, [tty_cursor_pos]
    mov ebx, SCREEN_WIDTH
    xor edx, edx
    div ebx
    test edx, edx
    jnz .done                         ; Если не конец строки
    
    ; Если конец строки, но не конец экрана - ничего страшного
    ; Курсор просто укажет на первый символ следующей строки
    ; Если это самый конец экрана - следующее введение вызовет скролл
    
.done:
    ; Обновление курсора на экране
    call tty_update_cursor_hw
    popad
    ret

; -----------------------------------------------------------------------------
; Функция: tty_newline
; Описание: Перевод курсора на начало следующей строки с прокруткой при необходимости
; Вход: Нет
; Выход: Нет
; -----------------------------------------------------------------------------
tty_newline:
    pushad
    mov eax, [tty_cursor_pos]
    add eax, SCREEN_WIDTH             ; Следующая строка
    
    cmp eax, SCREEN_WIDTH * SCREEN_HEIGHT
    jl .no_scroll

    ; Если вышли за пределы - скролл
    call tty_scroll_up
    mov eax, SCREEN_WIDTH * (SCREEN_HEIGHT - 1) ; Последняя строка
    mov [tty_cursor_pos], eax
    jmp .done

.no_scroll:
    mov [tty_cursor_pos], eax

.done:
    call tty_update_cursor_hw
    popad
    ret

; -----------------------------------------------------------------------------
; Функция: tty_scroll_up
; Описание: Прокрутка экрана на одну строку вверх
; Вход: Нет
; Выход: Нет
; -----------------------------------------------------------------------------
tty_scroll_up:
    pushad

    inc dword [tty_scroll_count]

    ; Копирование строк: строка N -> строка N-1
    ; Источник: строка 1 (адрес SCREEN_WIDTH * 2)
    ; Приемник: строка 0 (адрес 0)
    ; Размер: (HEIGHT-1) строк
    
    mov esi, tty_screen_buffer
    add esi, SCREEN_WIDTH * 2         ; Пропускаем первую строку
    mov edi, tty_screen_buffer
    mov ecx, (SCREEN_HEIGHT - 1) * SCREEN_WIDTH * 2
    rep movsb

    ; Очистка последней строки
    mov edi, tty_screen_buffer
    add edi, (SCREEN_HEIGHT - 1) * SCREEN_WIDTH * 2
    mov ecx, SCREEN_WIDTH
    mov ax, 0x0720                    ; Пробел с атрибутом
    rep stosw

    ; Обновление всего экрана
    call tty_refresh

    popad
    ret

; -----------------------------------------------------------------------------
; Функция: tty_putstr
; Описание: Вывод строки нуль-терминированной строки
; Вход: ESI = указатель на строку
; Выход: Нет
; -----------------------------------------------------------------------------
tty_putstr:
    pushad
.loop:
    lodsb
    test al, al
    jz .done
    push esi
    call tty_putchar
    pop esi
    jmp .loop
.done:
    popad
    ret

; -----------------------------------------------------------------------------
; Функция: tty_putstr_color
; Описание: Вывод строки с временным изменением цвета
; Вход: ESI = строка, BL = новый атрибут
; Выход: Нет
; -----------------------------------------------------------------------------
tty_putstr_color:
    pushad
    push ebx
    call tty_get_color
    push eax                        ; Сохраняем старый цвет
    mov [tty_current_attr], bl      ; Устанавливаем новый
    call tty_putstr
    pop eax                         ; Восстанавливаем старый
    mov [tty_current_attr], al
    pop ebx
    popad
    ret

; -----------------------------------------------------------------------------
; Функции управления курсором
; -----------------------------------------------------------------------------

tty_set_cursor:
    ; Вход: EAX = новая позиция (0..1999)
    pushad
    cmp eax, SCREEN_WIDTH * SCREEN_HEIGHT
    jge .limit
    mov [tty_cursor_pos], eax
.limit:
    call tty_update_cursor_hw
    popad
    ret

tty_get_cursor:
    ; Выход: EAX = текущая позиция
    mov eax, [tty_cursor_pos]
    ret

tty_move_cursor:
    ; Вход: DH = строка, DL = колонка (0-based)
    pushad
    movzx eax, dh
    mov ebx, SCREEN_WIDTH
    mul ebx
    add eax, edx
    call tty_set_cursor
    popad
    ret

tty_enable_cursor:
    mov byte [tty_cursor_visible], 1
    call tty_update_cursor_hw
    ret

tty_disable_cursor:
    mov byte [tty_cursor_visible], 0
    call tty_update_cursor_hw
    ret

; -----------------------------------------------------------------------------
; Функция: tty_update_cursor_hw
; Описание: Обновление положения курсора на реальном VGA контроллере
; Вход: Нет (берет из tty_cursor_pos)
; Выход: Нет
; -----------------------------------------------------------------------------
tty_update_cursor_hw:
    pushad

    ; Если курсор скрыт, отправляем его за пределы экрана
    cmp byte [tty_cursor_visible], 0
    je .hide_cursor

    mov eax, [tty_cursor_pos]
    jmp .send_pos

.hide_cursor:
    mov eax, SCREEN_WIDTH * SCREEN_HEIGHT ; Позиция за экраном

.send_pos:
    ; Порт VGA контроллера: 0x3D4 (регистр), 0x3D5 (данные)
    ; Регистр 0x0E - старший байт, 0x0F - младший
    
    ; Старший байт
    mov dx, 0x3D4
    mov al, 0x0E
    out dx, al
    inc dx
    mov cl, 8
    mov eax, [tty_cursor_pos]
    shr eax, cl
    and eax, 0xFF
    out dx, al
    
    ; Младший байт
    dec dx
    mov al, 0x0F
    out dx, al
    inc dx
    mov eax, [tty_cursor_pos]
    and eax, 0xFF
    out dx, al
    jmp .done

.hide_cursor_send:
    mov eax, SCREEN_WIDTH * SCREEN_HEIGHT
    mov dx, 0x3D4
    mov al, 0x0E
    out dx, al
    inc dx
    mov cl, 8
    shr eax, cl
    and eax, 0xFF
    out dx, al
    mov eax, SCREEN_WIDTH * SCREEN_HEIGHT
    dec dx
    mov al, 0x0F
    out dx, al
    inc dx
    and eax, 0xFF
    out dx, al

.done:
    popad
    ret

; -----------------------------------------------------------------------------
; Функция: tty_refresh
; Описание: Копирование буфера экрана в видеопамять
; Вход: Нет
; Выход: Нет
; -----------------------------------------------------------------------------
tty_refresh:
    pushad
    mov esi, tty_screen_buffer
    mov edi, VIDEO_MEMORY
    mov ecx, SCREEN_SIZE / 4
    rep movsd
    popad
    ret

; -----------------------------------------------------------------------------
; Функции установки цвета
; -----------------------------------------------------------------------------

tty_set_color:
    ; Вход: AL = новый атрибут
    mov [tty_current_attr], al
    ret

tty_get_color:
    ; Выход: AL = текущий атрибут
    movzx eax, byte [tty_current_attr]
    ret

; -----------------------------------------------------------------------------
; Утилиты вывода чисел
; -----------------------------------------------------------------------------

; Вывод числа в шестнадцатеричном формате (32 бита)
tty_print_hex:
    pushad
    mov ecx, 8          ; 8 нибблов
    mov ebx, eax        ; Сохраняем число
    mov esi, hex_buf    ; Буфер для строки
    add esi, 8          ; В конец буфера
    mov byte [esi], 0   ; Нуль-терминатор

.loop:
    dec esi
    mov eax, ebx
    and eax, 0xF
    cmp al, 9
    jbe .digit
    add al, 'A' - 9 - 1
    jmp .store
.digit:
    add al, '0'
.store:
    mov [esi], al
    shr ebx, 4
    loop .loop

    ; Добавляем префикс "0x"
    dec esi
    mov byte [esi], 'x'
    dec esi
    mov byte [esi], '0'

    push esi
    call tty_putstr
    popad
    ret

; Вывод числа в десятичном формате (беззнаковое)
tty_print_dec:
    pushad
    mov ebx, 10
    mov esi, dec_buf
    mov byte [esi], 0
    add esi, 10         ; Запас места

    test eax, eax
    jnz .convert
    mov byte [esi-1], '0'
    dec esi
    jmp .print

.convert:
    xor edx, edx
    div ebx
    add dl, '0'
    dec esi
    mov [esi], dl
    test eax, eax
    jnz .convert

.print:
    push esi
    call tty_putstr
    popad
    ret

; -----------------------------------------------------------------------------
; Секция данных для утилит
; -----------------------------------------------------------------------------
SECTION .data
hex_buf: resb 12
dec_buf: resb 12
