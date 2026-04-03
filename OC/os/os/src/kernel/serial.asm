; Драйвер последовательного порта (COM1) для ОС
bits 32

section .text
    global serial_init
    global serial_write
    global serial_read
    global serial_write_str

; Инициализация последовательного порта (COM1)
serial_init:
    ; Отключение прерываний
    mov dx, 0x3FB
    mov al, 0x80
    out dx, al
    
    ; Установка скорости 38400 бод (делитель 3)
    mov dx, 0x3F8
    mov al, 0x03
    out dx, al
    
    mov dx, 0x3F9
    mov al, 0x00
    out dx, al
    
    ; Установка 8 бит данных, 1 стоп-бит, без четности
    mov dx, 0x3FB
    mov al, 0x03
    out dx, al
    
    ; Включение FIFO, очистка буферов, размер буфера 14 байт
    mov dx, 0x3FA
    mov al, 0xC7
    out dx, al
    
    ; Включение прерываний (если потребуется)
    mov dx, 0x3FC
    mov al, 0x0B
    out dx, al
    
    ret

; Отправка байта через последовательный порт
; Вход: al - байт для отправки
serial_write:
    push dx
    push eax
    
    ; Ожидание готовности передатчика
.wait:
    mov dx, 0x3FD
    in al, dx
    and al, 0x20
    test al, al
    jz .wait
    
    ; Отправка байта
    mov dx, 0x3F8
    mov al, [esp + 8]  ; Получаем байт из стека
    out dx, al
    
    pop eax
    pop dx
    ret

; Получение байта из последовательного порта
; Выход: al - полученный байт
serial_read:
    push dx
    
    ; Ожидание данных
.wait:
    mov dx, 0x3FD
    in al, dx
    and al, 0x01
    test al, al
    jz .wait
    
    ; Чтение байта
    mov dx, 0x3F8
    in al, dx
    
    pop dx
    ret

; Отправка строки через последовательный порт
; Вход: esi - адрес строки (завершается нулем)
serial_write_str:
    push esi
    push eax
    
.loop:
    mov al, [esi]
    test al, al
    jz .done
    
    call serial_write
    inc esi
    jmp .loop
    
.done:
    pop eax
    pop esi
    ret

section .data
    ; Здесь могут быть данные, если потребуется

section .bss
    ; Здесь могут быть неинициализированные данные, если потребуется