; Простая оболочка (shell) для ОС "UNIVERSAL ASM CORE"
; Стиль: "Священный Ритуал" - Механикус (Зеленый люминофор) + Имперская эстетика
bits 32

section .text
    global shell_init
    global shell_run
    global shell_print_prompt
    global shell_read_command
    global shell_execute_command
    extern vga_put_string
    extern vga_put_char
    extern keyboard_read_char
    extern dir_read
    extern dir_find_entry
    extern dir_change
    extern fs_read_file
    extern print_system_info

; Инициализация оболочки
shell_init:
    pusha
    
    ; Инициализация переменных
    mov dword [shell_initialized], 1
    mov dword [current_dir_cluster], 0  ; Начинаем с корневой директории
    
    popa
    ret

; Запуск оболочки
shell_run:
    pusha
    
.main_loop:
    ; Вывод приглашения командной строки
    call shell_print_prompt
    
    ; Чтение команды от пользователя
    call shell_read_command
    
    ; Выполнение команды
    call shell_execute_command
    
    ; Переход к следующей итерации
    jmp .main_loop
    
    popa
    ret

; Вывод приглашения командной строки
shell_print_prompt:
    pusha
    
    ; Вывод строки приглашения в стиле священного ритуала
    mov esi, prompt_string
    call vga_put_string
    
    popa
    ret

; Чтение команды от пользователя
shell_read_command:
    pusha
    
    ; Очистка буфера команды
    mov edi, command_buffer
    mov ecx, 256
    xor eax, eax
    rep stosb
    
    ; Установка указателя на начало буфера
    mov dword [command_ptr], command_buffer
    
.read_loop:
    ; Чтение символа с клавиатуры
    call keyboard_read_char
    mov bl, al  ; Сохраняем символ
    
    ; Проверка на Enter (0x0D)
    cmp al, 0x0D
    je .done
    
    ; Проверка на Backspace (0x08)
    cmp al, 0x08
    je .backspace
    
    ; Проверка на допустимые символы
    cmp al, 0x20  ; Пробел
    jl .read_loop  ; Игнорируем управляющие символы
    
    cmp al, 0x7E  ; Тильда (~)
    jg .read_loop  ; Игнорируем символы вне диапазона
    
    ; Добавление символа в буфер команды
    mov edi, [command_ptr]
    mov [edi], bl
    inc dword [command_ptr]
    
    ; Вывод символа на экран
    mov al, bl
    call vga_put_char
    
    jmp .read_loop
    
.backspace:
    ; Проверка, есть ли символы для удаления
    mov eax, [command_ptr]
    cmp eax, command_buffer
    jle .read_loop  ; Нечего удалять
    
    ; Перемещение указателя назад
    dec dword [command_ptr]
    
    ; Вывод символа backspace на экран
    mov al, 0x08
    call vga_put_char
    
    ; Вывод пробела для стирания символа
    mov al, ' '
    call vga_put_char
    
    ; Вывод символа backspace для перемещения курсора
    mov al, 0x08
    call vga_put_char
    
    jmp .read_loop
    
.done:
    ; Добавление завершающего нуля
    mov edi, [command_ptr]
    mov byte [edi], 0
    
    ; Вывод новой строки
    mov al, 0x0A
    call vga_put_char
    
    popa
    ret

; Выполнение команды
shell_execute_command:
    pusha
    
    ; Получение указателя на команду
    mov esi, command_buffer
    
    ; Пропуск пробелов в начале
.skip_spaces:
    lodsb
    cmp al, ' '
    je .skip_spaces
    cmp al, 0
    je .empty_command
    dec esi  ; Вернуться к первому символу команды
    
    ; Сравнение с известными командами
    ; Проверка на "ls"
    mov edi, ls_command
    mov ecx, 2
    repe cmpsb
    je .cmd_ls
    
    ; Вернуть указатель к началу команды
    mov esi, command_buffer
    dec esi
    dec esi
    
    ; Проверка на "cd"
    mov edi, cd_command
    mov ecx, 2
    repe cmpsb
    je .cmd_cd
    
    ; Вернуть указатель к началу команды
    mov esi, command_buffer
    dec esi
    dec esi
    
    ; Проверка на "cat"
    mov edi, cat_command
    mov ecx, 3
    repe cmpsb
    je .cmd_cat
    
    ; Вернуть указатель к началу команды
    mov esi, command_buffer
    dec esi
    dec esi
    dec esi
    
    ; Проверка на "sysinfo"
    mov edi, sysinfo_command
    mov ecx, 7
    repe cmpsb
    je .cmd_sysinfo
    
    ; Неизвестная команда
    mov esi, unknown_command_msg
    call vga_put_string
    jmp .done
    
.empty_command:
    ; Пустая команда - ничего не делаем
    jmp .done
    
.cmd_ls:
    call shell_cmd_ls
    jmp .done
    
.cmd_cd:
    call shell_cmd_cd
    jmp .done
    
.cmd_cat:
    call shell_cmd_cat
    jmp .done
    
.cmd_sysinfo:
    call shell_cmd_sysinfo
    jmp .done
    
.done:
    popa
    ret

; Команда "ls" - вывод содержимого текущей директории
shell_cmd_ls:
    pusha
    
    ; Вывод заголовка
    mov esi, ls_header
    call vga_put_string
    
    popa
    ret

; Команда "cd" - смена текущей директории
shell_cmd_cd:
    pusha
    
    ; Пока просто выводим сообщение
    mov esi, cd_message
    call vga_put_string
    
    popa
    ret

; Команда "cat" - вывод содержимого файла
shell_cmd_cat:
    pusha
    
    ; Пока просто выводим сообщение
    mov esi, cat_message
    call vga_put_string
    
    popa
    ret

; Команда "sysinfo" - вывод информации о системе
shell_cmd_sysinfo:
    pusha
    
    ; Вызов функции вывода информации о системе
    call print_system_info
    
    popa
    ret

section .data
    shell_initialized dd 0
    current_dir_cluster dd 0
    command_ptr dd command_buffer
    ; Строка приглашения в стиле священного ритуала
    prompt_string db '[РИТУАЛЬНЫЙ ТЕРМИНАЛЪ]> ', 0
    ls_command db 'ls', 0
    cd_command db 'cd', 0
    cat_command db 'cat', 0
    sysinfo_command db 'sysinfo', 0
    unknown_command_msg db 'Невѣдомая команда', 0x0A, 0
    ls_header db 'Содержимое каталога:', 0x0A, 0
    cd_message db 'Перемѣщеніе каталога...', 0x0A, 0
    cat_message db 'Отображеніе содержимого файла...', 0x0A, 0

section .bss
    command_buffer resb 256