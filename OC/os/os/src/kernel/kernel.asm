; Ядро операционной системы
bits 32

section .text
    global _start
    global kmain
    extern vga_init
    extern vga_put_string
    extern vga_put_char
    extern gdt_init
    extern idt_init
    extern task_init
    extern scheduler_init
    extern syscall_init
    extern memory_init
    extern paging_init
    extern paging_enable
    extern keyboard_init
    extern encoding_init
    extern timer_init
    extern serial_init
    extern fs_init
    extern network_init
    extern shell_init
    extern shell_run
    extern task_switch
    extern scheduler_yield
    extern print_system_info

; Точка входа в ядро
_start:
    ; Установка стека для ядра
    mov esp, stack_top
    
    ; Вызов основной функции ядра
    call kmain
    
    ; Бесконечный цикл, если kmain завершится
    jmp $

; Основная функция ядра
kmain:
    pusha
    
    ; Инициализация драйвера VGA
    call vga_init
    
    ; Вывод приветственного сообщения
    mov esi, welcome_msg
    call vga_put_string
    mov esi, arch_msg
    call vga_put_string
    mov esi, status_msg
    call vga_put_string
    
    ; Инициализация GDT
    call gdt_init
    
    ; Инициализация IDT
    call idt_init
    
    ; Инициализация системы задач
    call task_init
    
    ; Инициализация планировщика
    call scheduler_init
    
    ; Инициализация системных вызовов
    call syscall_init
    
    ; Инициализация менеджера памяти
    call memory_init
    
    ; Инициализация страничной памяти
    call paging_init
    call paging_enable
    
    ; Инициализация драйверов устройств
    call keyboard_init
    call encoding_init
    call timer_init
    call serial_init
    
    ; Инициализация файловой системы
    call fs_init
    
    ; Инициализация сетевых возможностей
    call network_init
    
    ; Инициализация оболочки
    call shell_init
    
    ; Включение прерываний
    sti
    
    ; Основной цикл ядра
.main_loop:
    ; Запуск оболочки
    call shell_run
    
    ; Переключение задач через планировщик
    call scheduler_yield
    
    ; Небольшая задержка для предотвращения излишней нагрузки на процессор
    mov ecx, 1000000
.delay_loop:
    nop
    loop .delay_loop
    
    ; Переход к следующей итерации
    jmp .main_loop
    
    popa
    ret

; Обработчик прерываний (заглушка)
interrupt_handler:
    ; Сохранение регистров
    pusha
    push ds
    push es
    push fs
    push gs
    
    ; Здесь будет обработка прерывания
    
    ; Восстановление регистров
    pop gs
    pop fs
    pop es
    pop ds
    popa
    iret

; Обработчики исключений

; Добавим обработчики для всех 32 исключений
%assign i 0
%rep 32
    exception_handler_%+i:
        push dword 0    ; Фиктивный код ошибки (для исключений без кода ошибки)
        push dword i    ; Номер исключения
        jmp exception_handler
    %assign i i+1
%endrep

; Общий обработчик исключений
exception_handler:
    ; Здесь будет код обработки исключений
    ; Пока просто останавливаем систему
    cli
    hlt
    
    ; Вывод сообщения об ошибке
    mov esi, exception_msg
    call vga_put_string
    
    ; Бесконечный цикл
    jmp $

section .data
    welcome_msg db 'Ядро операционной системы загружено!', 0x0A, 0
    arch_msg db 'Архитектура: x86 32-bit', 0x0A, 0
    status_msg db 'Статус: Работает', 0x0A, 0x0A, 0
    exception_msg db 'Произошло исключение!', 0x0A, 0

section .bss
    ; Резервирование памяти для стека
    stack_bottom:
        resb 16384  ; 16KB стек
    stack_top:
