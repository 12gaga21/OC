; Текстовый редактор для ОС (простой TUI редактор)
bits 32

section .text
    global editor_init
    global editor_run
    global editor_load_file
    global editor_save_file
    global editor_close
    
    extern vga_put_string
    extern vga_put_char
    extern vga_clear_screen
    extern vga_set_cursor
    extern keyboard_read_char
    extern fs_read_file
    extern fs_write_file
    extern shell_cmd_clear

; ============================================================================
; ИНИЦИАЛИЗАЦИЯ РЕДАКТОРА
; ============================================================================
editor_init:
    pusha
    
    ; Очистка экрана
    call vga_clear_screen
    
    ; Инициализация переменных
    mov dword [editor_initialized], 1
    mov dword [editor_cursor_x], 0
    mov dword [editor_cursor_y], 0
    mov dword [editor_scroll_offset], 0
    mov dword [editor_line_count], 1
    mov dword [editor_modified], 0
    
    ; Вывод заголовка
    mov esi, editor_title
    call vga_put_string
    
    popa
    ret

; ============================================================================
; ЗАПУСК РЕДАКТОРА
; ============================================================================
editor_run:
    pusha
    
.main_loop:
    ; Установка курсора
    call editor_update_cursor
    
    ; Чтение символа
    call keyboard_read_char
    
    ; Проверка на Escape (выход)
    cmp al, 0x1B
    je .exit_editor
    
    ; Проверка на Ctrl+S (сохранение)
    cmp al, 0x13
    je .save_file
    
    ; Проверка на Ctrl+O (открыть файл)
    cmp al, 0x0F
    je .open_file
    
    ; Проверка на Backspace
    cmp al, 0x08
    je .handle_backspace
    
    ; Проверка на Enter
    cmp al, 0x0D
    je .handle_enter
    
    ; Проверка на стрелки (последовательности ESC)
    cmp al, 0x1B
    je .handle_arrow
    
    ; Обычный символ - добавление в буфер
    call editor_insert_char
    
    jmp .main_loop
    
.handle_backspace:
    call editor_delete_char
    jmp .main_loop
    
.handle_enter:
    call editor_insert_newline
    jmp .main_loop
    
.handle_arrow:
    ; Чтение последовательности стрелки
    call keyboard_read_char
    cmp al, '['
    jne .main_loop
    
    call keyboard_read_char
    cmp al, 'A'
    je .arrow_up
    cmp al, 'B'
    je .arrow_down
    cmp al, 'C'
    je .arrow_right
    cmp al, 'D'
    je .arrow_left
    jmp .main_loop
    
.arrow_up:
    call editor_move_up
    jmp .main_loop
    
.arrow_down:
    call editor_move_down
    jmp .main_loop
    
.arrow_right:
    call editor_move_right
    jmp .main_loop
    
.arrow_left:
    call editor_move_left
    jmp .main_loop
    
.save_file:
    call editor_save_current
    jmp .main_loop
    
.open_file:
    call editor_open_prompt
    jmp .main_loop
    
.exit_editor:
    ; Проверка на несохранённые изменения
    cmp dword [editor_modified], 1
    jne .exit_now
    
    ; Вывод запроса на сохранение
    mov esi, save_prompt_msg
    call vga_put_string
    
.exit_now:
    popa
    ret

; ============================================================================
; ВСТАВКА СИМВОЛА
; ============================================================================
editor_insert_char:
    pusha
    
    ; Получение текущей позиции
    mov eax, [editor_cursor_y]
    mov ebx, [editor_cursor_x]
    
    ; Вычисление смещения в буфере
    ; Упрощённо: line_width * y + x
    mov ecx, EDITOR_LINE_WIDTH
    mul ecx
    add eax, ebx
    
    ; Проверка границ буфера
    cmp eax, EDITOR_BUFFER_SIZE
    jge .out_of_bounds
    
    ; Вставка символа
    mov edi, editor_buffer
    add edi, eax
    mov [edi], al
    
    ; Установка флага модификации
    mov dword [editor_modified], 1
    
    ; Движение курсора вправо
    inc dword [editor_cursor_x]
    
.out_of_bounds:
    popa
    ret

; ============================================================================
; УДАЛЕНИЕ СИМВОЛА (Backspace)
; ============================================================================
editor_delete_char:
    pusha
    
    ; Если курсор в начале строки
    cmp dword [editor_cursor_x], 0
    je .at_line_start
    
    ; Удаление предыдущего символа
    dec dword [editor_cursor_x]
    
    mov eax, [editor_cursor_y]
    mov ebx, [editor_cursor_x]
    mov ecx, EDITOR_LINE_WIDTH
    mul ecx
    add eax, ebx
    
    mov edi, editor_buffer
    add edi, eax
    mov byte [edi], 0
    
    ; Установка флага модификации
    mov dword [editor_modified], 1
    
.at_line_start:
    popa
    ret

; ============================================================================
; ВСТАВКА НОВОЙ СТРОКИ (Enter)
; ============================================================================
editor_insert_newline:
    pusha
    
    ; Переход на следующую строку
    mov dword [editor_cursor_x], 0
    inc dword [editor_cursor_y]
    
    ; Увеличение счётчика строк
    inc dword [editor_line_count]
    
    ; Установка флага модификации
    mov dword [editor_modified], 1
    
    ; Проверка на выход за пределы экрана
    cmp dword [editor_cursor_y], EDITOR_VISIBLE_LINES
    jl .done
    
    ; Прокрутка вверх
    inc dword [editor_scroll_offset]
    dec dword [editor_cursor_y]
    
.done:
    popa
    ret

; ============================================================================
; ДВИЖЕНИЕ КУРСОРА
; ============================================================================
editor_move_up:
    pusha
    cmp dword [editor_cursor_y], 0
    je .done
    dec dword [editor_cursor_y]
.done:
    popa
    ret

editor_move_down:
    pusha
    inc dword [editor_cursor_y]
    popa
    ret

editor_move_left:
    pusha
    cmp dword [editor_cursor_x], 0
    je .done
    dec dword [editor_cursor_x]
.done:
    popa
    ret

editor_move_right:
    pusha
    inc dword [editor_cursor_x]
    popa
    ret

; ============================================================================
; ОБНОВЛЕНИЕ ПОЗИЦИИ КУРСОРА
; ============================================================================
editor_update_cursor:
    pusha
    
    ; Вычисление позиции на экране
    ; Строка 2 + (y - scroll_offset)
    mov eax, [editor_cursor_y]
    sub eax, [editor_scroll_offset]
    add eax, 2  ; Пропуск заголовка
    
    ; Столбец 0 + x
    mov ebx, [editor_cursor_x]
    
    ; Установка курсора VGA
    push eax
    push ebx
    call vga_set_cursor
    add esp, 8
    
    popa
    ret

; ============================================================================
; ЗАГРУЗКА ФАЙЛА
; ============================================================================
editor_load_file:
    pusha
    
    ; Выделение буфера для чтения
    sub esp, EDITOR_BUFFER_SIZE
    mov edi, esp
    
    ; Чтение файла
    push edi
    push esi  ; Имя файла
    call fs_read_file
    add esp, 8
    
    ; Копирование в буфер редактора
    mov esi, edi
    mov edi, editor_buffer
    mov ecx, EDITOR_BUFFER_SIZE
    rep movsb
    
    ; Подсчёт строк
    call editor_count_lines
    
    ; Сброс позиции
    mov dword [editor_cursor_x], 0
    mov dword [editor_cursor_y], 0
    mov dword [editor_scroll_offset], 0
    mov dword [editor_modified], 0
    
    ; Очистка стека
    add esp, EDITOR_BUFFER_SIZE
    
    popa
    ret

; ============================================================================
; СОХРАНЕНИЕ ФАЙЛА
; ============================================================================
editor_save_file:
    pusha
    
    ; Запись файла
    push editor_buffer
    push editor_filename
    call fs_write_file
    add esp, 8
    
    ; Сброс флага модификации
    mov dword [editor_modified], 0
    
    ; Вывод сообщения об успехе
    mov esi, save_success_msg
    call vga_put_string
    
    popa
    ret

; ============================================================================
; ПОДСЧЁТ СТРОК
; ============================================================================
editor_count_lines:
    pusha
    
    mov dword [editor_line_count], 1
    mov esi, editor_buffer
    mov ecx, EDITOR_BUFFER_SIZE
    
.count_loop:
    test ecx, ecx
    jz .done
    
    lodsb
    test al, al
    jz .done
    
    cmp al, 0x0A
    jne .next_char
    
    inc dword [editor_line_count]
    
.next_char:
    dec ecx
    jmp .count_loop
    
.done:
    popa
    ret

; ============================================================================
; ОТКРЫТИЕ ФАЙЛА (запрос имени)
; ============================================================================
editor_open_prompt:
    pusha
    
    ; Вывод приглашения
    mov esi, open_prompt_msg
    call vga_put_string
    
    ; Чтение имени файла (упрощённо)
    ; Здесь должна быть логика ввода с клавиатуры
    
    popa
    ret

; ============================================================================
; СОХРАНЕНИЕ ТЕКУЩЕГО ФАЙЛА
; ============================================================================
editor_save_current:
    pusha
    
    cmp dword [editor_modified], 0
    je .not_modified
    
    call editor_save_file
    
.not_modified:
    popa
    ret

; ============================================================================
; ЗАКРЫТИЕ РЕДАКТОРА
; ============================================================================
editor_close:
    pusha
    
    ; Очистка буфера
    mov edi, editor_buffer
    mov ecx, EDITOR_BUFFER_SIZE
    xor eax, eax
    rep stosb
    
    ; Сброс переменных
    mov dword [editor_initialized], 0
    mov dword [editor_cursor_x], 0
    mov dword [editor_cursor_y], 0
    mov dword [editor_scroll_offset], 0
    mov dword [editor_line_count], 1
    mov dword [editor_modified], 0
    
    popa
    ret

; ============================================================================
; КОНСТАНТЫ
; ============================================================================
%define EDITOR_BUFFER_SIZE 4096      ; 4KB буфер
%define EDITOR_LINE_WIDTH 80         ; Ширина строки
%define EDITOR_VISIBLE_LINES 23      ; Видимых строк (25 - 2 заголовок)

; ============================================================================
; СТРОКОВЫЕ КОНСТАНТЫ
; ============================================================================
section .rodata
    editor_title db '=== TEXT EDITOR ===  Ctrl+S:Save  Ctrl+O:Open  Esc:Exit', 0x0D, 0x0A, 0
    save_prompt_msg db 'Save changes before exit? (Y/N)', 0x0D, 0x0A, 0
    save_success_msg db 'File saved successfully.', 0x0D, 0x0A, 0
    open_prompt_msg db 'Enter filename: ', 0

; ============================================================================
; ДАННЫЕ
; ============================================================================
section .data
    editor_initialized dd 0
    editor_cursor_x dd 0
    editor_cursor_y dd 0
    editor_scroll_offset dd 0
    editor_line_count dd 1
    editor_modified dd 0
    editor_filename times 256 db 0
    editor_buffer times EDITOR_BUFFER_SIZE db 0
