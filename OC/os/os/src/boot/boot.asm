; Загрузчик операционной системы
; Формат: 16-битный реальный режим

bits 16

; Точка входа загрузчика
section .text
    org 0x7c00
    global _start

_start:
    ; Настройка сегментных регистров
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00  ; Установка стека

    ; Вывод приветственного сообщения
    mov si, welcome_msg
    call print_string

    ; Включение A20 линии
    call enable_a20

    ; Получение информации о памяти
    call get_memory_map

    ; Переключение в 32-битный защищенный режим
    cli             ; Запрет прерываний
    lgdt [gdt_desc] ; Загрузка GDT
    mov eax, cr0
    or eax, 1       ; Установка бита PE (Protection Enable)
    mov cr0, eax

    ; Переход в 32-битный режим
    jmp 0x08:protected_mode

; Функция вывода строки
print_string:
    pusha
    mov ah, 0x0e    ; Функция BIOS для вывода символа
.print_char:
    lodsb           ; Загрузка следующего символа
    cmp al, 0
    je .done        ; Конец строки
    int 0x10        ; Вызов BIOS
    jmp .print_char
.done:
    popa
    ret

; Включение линии A20
enable_a20:
    pusha
    
    ; Использование Fast A20
    in al, 0x92
    or al, 2
    out 0x92, al
    
    popa
    ret

; Получение карты памяти
get_memory_map:
    pusha
    
    ; Здесь будет код для получения карты памяти через BIOS
    ; Пока оставим заглушку
    
    popa
    ret

; Сообщения в кодировке CP866 для корректного отображения в BIOS
welcome_msg db 0x84,0xae,0xa1,0xe0,0xae,0x20,0xaf,0xae,0xa6,0xa0,0xab,0xae,0xa2,0xa0,0xe2,0xec,0x20,0xa2,0x20,0x8e,0x91,0x20,0xad,0xa0,0x20,0xa0,0xe1,0xe1,0xa5,0xac,0xa1,0xab,0xa5,0xe0,0xa5,0x21,0x0D,0x0A,0

; Переход в 32-битный режим
bits 32
protected_mode:
    ; Настройка сегментов в 32-битном режиме
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x90000  ; Установка стека в 32-битном режиме

    ; Вывод сообщения о переходе в 32-битный режим
    ; (для простоты используем простой способ вывода)
    mov edi, 0xb8000  ; Адрес видеопамяти в текстовом режиме
    mov esi, protected_msg
    mov ecx, protected_msg_len
    mov ah, 0x07      ; Светло-серый цвет на черном фоне
.print_protected:
    mov al, [esi]
    mov [edi], ax
    add edi, 2
    inc esi
    loop .print_protected

    ; Здесь будет загрузка ядра и передача управления ему
    ; Пока оставим бесконечный цикл
    jmp $

protected_msg db '32-битный режим активирован'
protected_msg_len equ $ - protected_msg

; GDT (Global Descriptor Table)
gdt_start:
    dq 0x0  ; Нулевая запись

gdt_code:
    dw 0xFFFF    ; Лимит
    dw 0x0       ; База (младшие 16 бит)
    db 0x0       ; База (следующие 8 бит)
    db 10011010b ; Флаги доступа и тип (код, выполняемый/читаемый)
    db 11001111b ; Гранулярность и лимит (старшие 4 бита)
    db 0x0       ; База (старшие 8 бит)

gdt_data:
    dw 0xFFFF    ; Лимит
    dw 0x0       ; База (младшие 16 бит)
    db 0x0       ; База (следующие 8 бит)
    db 10010010b ; Флаги доступа и тип (данные, читаемые/записываемые)
    db 11001111b ; Гранулярность и лимит (старшие 4 бита)
    db 0x0       ; База (старшие 8 бит)

gdt_end:

gdt_desc:
    dw gdt_end - gdt_start - 1  ; Размер GDT
    dd gdt_start                ; Адрес GDT

; Заполнение до 512 байт и сигнатура загрузчика
times 510 - ($-$$) db 0
    dw 0xaa55
