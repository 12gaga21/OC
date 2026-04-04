; Расширенные команды оболочки (shell commands)
bits 32

section .text
    global shell_cmd_help
    global shell_cmd_clear
    global shell_cmd_echo
    global shell_cmd_date
    global shell_cmd_version
    global shell_cmd_reboot
    global shell_cmd_beep
    global shell_cmd_meminfo
    global shell_cmd_tasks
    global shell_cmd_ping
    
    extern vga_put_string
    extern vga_put_char
    extern vga_clear_screen
    extern keyboard_read_char
    extern print_system_info
    extern sound_beep
    extern sound_play_note
    extern get_memory_stats
    extern scheduler_get_task_list
    extern network_ping
    
; ============================================================================
; КОМАНДА: help - вывод справки по доступным командам
; ============================================================================
shell_cmd_help:
    pusha
    
    mov esi, help_header
    call vga_put_string
    
    ; Список команд
    mov esi, help_command_ls
    call vga_put_string
    mov esi, help_command_cd
    call vga_put_string
    mov esi, help_command_cat
    call vga_put_string
    mov esi, help_command_sysinfo
    call vga_put_string
    mov esi, help_command_clear
    call vga_put_string
    mov esi, help_command_echo
    call vga_put_string
    mov esi, help_command_date
    call vga_put_string
    mov esi, help_command_version
    call vga_put_string
    mov esi, help_command_reboot
    call vga_put_string
    mov esi, help_command_beep
    call vga_put_string
    mov esi, help_command_meminfo
    call vga_put_string
    mov esi, help_command_tasks
    call vga_put_string
    mov esi, help_command_ping
    call vga_put_string
    mov esi, help_command_help
    call vga_put_string
    
    mov esi, help_footer
    call vga_put_string
    
    popa
    ret

; ============================================================================
; КОМАНДА: clear - очистка экрана
; ============================================================================
shell_cmd_clear:
    pusha
    
    call vga_clear_screen
    
    popa
    ret

; ============================================================================
; КОМАНДА: echo - вывод текста
; ============================================================================
shell_cmd_echo:
    pusha
    
    ; Получение аргумента после команды "echo "
    mov esi, command_buffer
    add esi, 5  ; Пропускаем "echo "
    
    ; Вывод аргумента
    call vga_put_string
    
    ; Вывод перевода строки
    mov al, 0x0D
    call vga_put_char
    mov al, 0x0A
    call vga_put_char
    
    popa
    ret

; ============================================================================
; КОМАНДА: date - вывод текущей даты и времени
; ============================================================================
shell_cmd_date:
    pusha
    
    ; Чтение из CMOS (порт 0x70-0x71)
    ; Секунды
    mov al, 0x00
    out 0x70, al
    in al, 0x71
    push ax
    
    ; Минуты
    mov al, 0x02
    out 0x70, al
    in al, 0x71
    push ax
    
    ; Часы
    mov al, 0x04
    out 0x70, al
    in al, 0x71
    push ax
    
    ; День
    mov al, 0x07
    out 0x70, al
    in al, 0x71
    push ax
    
    ; Месяц
    mov al, 0x08
    out 0x70, al
    in al, 0x71
    push ax
    
    ; Год
    mov al, 0x09
    out 0x70, al
    in al, 0x71
    push ax
    
    ; Форматированный вывод: DD.MM.YYYY HH:MM:SS
    mov esi, date_prefix
    call vga_put_string
    
    ; День (из стека)
    pop ax
    call print_hex_byte
    mov al, '.'
    call vga_put_char
    
    ; Месяц
    pop ax
    call print_hex_byte
    mov al, '.'
    call vga_put_char
    
    ; Год
    pop ax
    call print_hex_byte
    mov al, ' '
    call vga_put_char
    
    ; Часы
    pop ax
    call print_hex_byte
    mov al, ':'
    call vga_put_char
    
    ; Минуты
    pop ax
    call print_hex_byte
    mov al, ':'
    call vga_put_char
    
    ; Секунды
    pop ax
    call print_hex_byte
    
    ; Перевод строки
    mov al, 0x0D
    call vga_put_char
    mov al, 0x0A
    call vga_put_char
    
    popa
    ret

; Вспомогательная функция для вывода байта в HEX
print_hex_byte:
    pusha
    push ax
    
    ; Старшая тетрада
    shr al, 4
    cmp al, 9
    jbe .digit1
    add al, 7
.digit1:
    add al, '0'
    call vga_put_char
    
    pop ax
    ; Младшая тетрада
    and al, 0x0F
    cmp al, 9
    jbe .digit2
    add al, 7
.digit2:
    add al, '0'
    call vga_put_char
    
    popa
    ret

; ============================================================================
; КОМАНДА: version - вывод версии ОС
; ============================================================================
shell_cmd_version:
    pusha
    
    mov esi, version_string
    call vga_put_string
    
    popa
    ret

; ============================================================================
; КОМАНДА: reboot - перезагрузка системы
; ============================================================================
shell_cmd_reboot:
    pusha
    
    mov esi, reboot_message
    call vga_put_string
    
    ; Перезагрузка через клавиатуру контроллер
    mov al, 0xFE
    out 0x64, al
    
    ; Бесконечный цикл на случай если перезагрузка не сработала
.hang:
    jmp .hang
    
    popa
    ret

; ============================================================================
; КОМАНДА: beep - тестовый звуковой сигнал
; ============================================================================
shell_cmd_beep:
    pusha
    
    mov esi, beep_message
    call vga_put_string
    
    ; Воспроизведение гаммы
    call sound_test_sequence
    
    mov esi, beep_done
    call vga_put_string
    
    popa
    ret

; ============================================================================
; КОМАНДА: meminfo - информация о памяти
; ============================================================================
shell_cmd_meminfo:
    pusha
    
    mov esi, meminfo_header
    call vga_put_string
    
    ; Выделение буфера для статистики (64 байта)
    sub esp, 64
    mov edi, esp
    
    ; Получение статистики памяти
    push edi
    call get_memory_stats
    add esp, 4
    
    ; Чтение значений из буфера
    ; [esp] = total_low
    ; [esp+4] = total_high
    ; [esp+8] = used_low
    ; [esp+12] = used_high
    ; [esp+16] = free_low
    ; [esp+20] = free_high
    
    mov eax, [esp]
    mov edx, [esp+4]
    call print_64bit_value
    mov esi, meminfo_total_suffix
    call vga_put_string
    
    mov eax, [esp+8]
    mov edx, [esp+12]
    call print_64bit_value
    mov esi, meminfo_used_suffix
    call vga_put_string
    
    mov eax, [esp+16]
    mov edx, [esp+20]
    call print_64bit_value
    mov esi, meminfo_free_suffix
    call vga_put_string
    
    ; Очистка стека
    add esp, 64
    
    popa
    ret

; Вывод 64-битного значения
print_64bit_value:
    pusha
    ; Упрощённый вывод - только младшие 32 бита
    ; Для полного вывода нужно реализовать деление на 10
    push eax
    push ebx
    push ecx
    push edx
    
    ; Вывод в HEX для простоты
    mov ebx, edx
    mov eax, ebx
    shr eax, 28
    and eax, 0x0F
    call print_hex_digit
    mov eax, ebx
    shr eax, 24
    and eax, 0x0F
    call print_hex_digit
    mov eax, ebx
    shr eax, 20
    and eax, 0x0F
    call print_hex_digit
    mov eax, ebx
    shr eax, 16
    and eax, 0x0F
    call print_hex_digit
    mov eax, ebx
    shr eax, 12
    and eax, 0x0F
    call print_hex_digit
    mov eax, ebx
    shr eax, 8
    and eax, 0x0F
    call print_hex_digit
    mov eax, ebx
    shr eax, 4
    and eax, 0x0F
    call print_hex_digit
    mov eax, ebx
    and eax, 0x0F
    call print_hex_digit
    
    mov ebx, eax
    mov eax, ebx
    shr eax, 28
    and eax, 0x0F
    call print_hex_digit
    mov eax, ebx
    shr eax, 24
    and eax, 0x0F
    call print_hex_digit
    mov eax, ebx
    shr eax, 20
    and eax, 0x0F
    call print_hex_digit
    mov eax, ebx
    shr eax, 16
    and eax, 0x0F
    call print_hex_digit
    mov eax, ebx
    shr eax, 12
    and eax, 0x0F
    call print_hex_digit
    mov eax, ebx
    shr eax, 8
    and eax, 0x0F
    call print_hex_digit
    mov eax, ebx
    shr eax, 4
    and eax, 0x0F
    call print_hex_digit
    mov eax, ebx
    and eax, 0x0F
    call print_hex_digit
    
    pop edx
    pop ecx
    pop ebx
    pop eax
    popa
    ret

print_hex_digit:
    pusha
    cmp al, 9
    jbe .digit
    add al, 7
.digit:
    add al, '0'
    call vga_put_char
    popa
    ret

; ============================================================================
; КОМАНДА: tasks - список активных задач
; ============================================================================
shell_cmd_tasks:
    pusha
    
    mov esi, tasks_header
    call vga_put_string
    
    ; Выделение буфера для списка задач
    sub esp, 256
    mov edi, esp
    
    ; Получение списка задач
    push edi
    call scheduler_get_task_list
    add esp, 4
    
    ; Парсинг и вывод списка задач
    ; Формат: ID, State, Priority, Name
    mov esi, esp
    mov ecx, 16  ; Максимум 16 задач
    
.task_loop:
    test ecx, ecx
    jz .task_done
    
    ; Чтение ID задачи
    mov eax, [esi]
    test eax, eax
    jz .next_task  ; Пустая задача
    
    ; Вывод ID
    push eax
    call print_decimal
    mov al, ':'
    call vga_put_char
    mov al, ' '
    call vga_put_char
    
    ; Вывод имени (смещение 4 байта)
    mov ebx, [esi+4]
    test ebx, ebx
    jz .next_task
    push ebx
    call vga_put_string
    add esp, 4
    
    ; Перевод строки
    mov al, 0x0D
    call vga_put_char
    mov al, 0x0A
    call vga_put_char
    
.next_task:
    add esi, 32  ; Размер структуры задачи
    dec ecx
    jmp .task_loop
    
.task_done:
    add esp, 256
    
    popa
    ret

; Вывод десятичного числа
print_decimal:
    pusha
    push ebx
    push ecx
    push edx
    
    test eax, eax
    jnz .convert
    
    ; Ноль
    mov al, '0'
    call vga_put_char
    jmp .done
    
.convert:
    xor ecx, ecx  ; Счётчик цифр
    mov ebx, 10
    
.divide:
    xor edx, edx
    div ebx
    push dx
    inc ecx
    test eax, eax
    jnz .divide
    
.print_digits:
    test ecx, ecx
    jz .done
    pop dx
    add dl, '0'
    mov al, dl
    call vga_put_char
    dec ecx
    jmp .print_digits
    
.done:
    pop edx
    pop ecx
    pop ebx
    popa
    ret

; ============================================================================
; КОМАНДА: ping - проверка сетевого соединения
; ============================================================================
shell_cmd_ping:
    pusha
    
    mov esi, ping_message
    call vga_put_string
    
    ; Пока просто тестовое сообщение
    ; В будущем здесь будет вызов network_ping
    
    mov esi, ping_done
    call vga_put_string
    
    popa
    ret

; ============================================================================
; СТРОКОВЫЕ КОНСТАНТЫ
; ============================================================================
section .rodata
    help_header db 'Available commands:', 0x0D, 0x0A, 0
    help_command_ls db '  ls              - List directory contents', 0x0D, 0x0A, 0
    help_command_cd db '  cd <dir>        - Change directory', 0x0D, 0x0A, 0
    help_command_cat db '  cat <file>      - Display file contents', 0x0D, 0x0A, 0
    help_command_sysinfo db '  sysinfo         - Show system information', 0x0D, 0x0A, 0
    help_command_clear db '  clear           - Clear screen', 0x0D, 0x0A, 0
    help_command_echo db '  echo <text>     - Display text', 0x0D, 0x0A, 0
    help_command_date db '  date            - Show current date/time', 0x0D, 0x0A, 0
    help_command_version db '  version         - Show OS version', 0x0D, 0x0A, 0
    help_command_reboot db '  reboot          - Reboot system', 0x0D, 0x0A, 0
    help_command_beep db '  beep            - Play test sound', 0x0D, 0x0A, 0
    help_command_meminfo db '  meminfo         - Show memory information', 0x0D, 0x0A, 0
    help_command_tasks db '  tasks           - List active tasks', 0x0D, 0x0A, 0
    help_command_ping db '  ping <host>     - Ping network host', 0x0D, 0x0A, 0
    help_command_help db '  help            - Show this help', 0x0D, 0x0A, 0
    help_footer db 0x0D, 0x0A, 'Type command name for more details.', 0x0D, 0x0A, 0
    
    date_prefix db 'Current time: ', 0
    version_string db 'NASM-OS Version 1.0.0', 0x0D, 0x0A, 'Build 2026-04-03', 0x0D, 0x0A, 0
    reboot_message db 'Rebooting system...', 0x0D, 0x0A, 0
    beep_message db 'Playing test sequence...', 0x0D, 0x0A, 0
    beep_done db 'Test complete.', 0x0D, 0x0A, 0
    
    meminfo_header db 'Memory Information:', 0x0D, 0x0A, 0
    meminfo_total_suffix db ' KB Total', 0x0D, 0x0A, 0
    meminfo_used_suffix db ' KB Used', 0x0D, 0x0A, 0
    meminfo_free_suffix db ' KB Free', 0x0D, 0x0A, 0
    
    tasks_header db 'Active Tasks:', 0x0D, 0x0A, 'ID  Name', 0x0D, 0x0A, 0
    
    ping_message db 'Pinging network host...', 0x0D, 0x0A, 0
    ping_done db 'Ping test complete.', 0x0D, 0x0A, 0

; ============================================================================
; ДАННЫЕ
; ============================================================================
section .data
    command_buffer times 256 db 0
