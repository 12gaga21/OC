; Драйвер таймера для ОС
bits 32

section .text
    global timer_init
    global timer_handler
    global get_tick_count
    extern interrupt_handler
    extern scheduler_tick

; Инициализация таймера
timer_init:
    ; Установка частоты таймера (100 Гц)
    ; Частота PIT = 1193182 Гц
    ; Делитель = 1193182 / 100 = 11931
    mov al, 0x36
    out 0x43, al
    
    ; Установка делителя 11931 (0x2E9B)
    mov ax, 11931
    out 0x40, al
    mov al, ah
    out 0x40, al
    
    ; Разрешение прерываний от таймера (IRQ0)
    ; Отправка команды контроллеру прерываний
    mov al, 0x20
    out 0x20, al
    
    ret

; Обработчик прерываний таймера
timer_handler:
    ; Сохранение регистров
    pusha
    push ds
    push es
    push fs
    push gs
    
    ; Увеличение счетчика тиков
    inc dword [tick_count]
    
    ; Вызов планировщика для обработки тика
    call scheduler_tick
    
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

; Функция получения количества тиков
get_tick_count:
    mov eax, [tick_count]
    ret

section .data
    tick_count dd 0    ; Счетчик тиков

section .bss
    ; Здесь можно разместить дополнительные переменные, если потребуется