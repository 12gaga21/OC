; Простое ядро для тестирования сборки
bits 32

section .text
    global _start

; Точка входа в ядро
_start:
    ; Установка стека для ядра
    mov esp, stack_top
    
    ; Настройка сегментов
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    
    ; Очистка экрана (заполняем черным)
    mov edi, 0xB8000
    mov ecx, 80*25
    mov ah, 0x07        ; Светло-серый на черном
    mov al, ' '
.clear_loop:
    mov [edi], ax
    add edi, 2
    loop .clear_loop
    
    ; Вывод приветственного сообщения
    mov esi, welcome_msg
    mov edi, 0xB8000
    call print_string32
    
    ; Вывод сообщения об архитектуре
    mov esi, arch_msg
    mov edi, 0xB8000 + 160  ; Вторая строка
    call print_string32
    
    ; Вывод статуса
    mov esi, status_msg
    mov edi, 0xB8000 + 320  ; Третья строка
    call print_string32
    
    ; Бесконечный цикл
.halt:
    hlt
    jmp .halt

; Функция вывода строки в защищенном режиме
; Вход: ESI = адрес строки (ASCIIZ), EDI = адрес видеопамяти
print_string32:
    pusha
    mov ah, 0x07        ; Светло-серый на черном
.print_char:
    lodsb               ; Загружаем символ из [ESI] в AL, инкремент ESI
    test al, al
    jz .done
    mov [edi], ax       ; Записываем символ и атрибут
    add edi, 2
    jmp .print_char
.done:
    popa
    ret

section .data
    ; Сообщения в кодировке CP866 для видеопамяти
    welcome_msg db 0x9f,0xa4,0xe0,0xae,0x20,0xae,0xaf,0xa5,0xe0,0xa0,0xe6,0xa8,0xae,0xad,0xad,0xae,0xa9,0x20,0xe1,0xa8,0xe1,0xe2,0xa5,0xac,0xeb,0x20,0xa7,0xa0,0xa3,0xe0,0xe3,0xa6,0xa5,0xad,0xae,0x21,0
    arch_msg db 0x80,0xe0,0xe5,0xa8,0xe2,0xa5,0xaa,0xe2,0xe3,0xe0,0xa0,0x3a,0x20,0x78,0x38,0x36,0x20,0x33,0x32,0x2d,0x62,0x69,0x74,0
    status_msg db 0x91,0xe2,0xa0,0xe2,0xe3,0xe1,0x3a,0x20,0x90,0xa0,0xa1,0xae,0xe2,0xa0,0xae,0xe2,0x20,0xe3,0xe1,0xaf,0xa5,0xe8,0xad,0xae,0x21,0

section .bss
    ; Резервирование памяти для стека
    stack_bottom:
        resb 16384  ; 16KB стек
    stack_top: