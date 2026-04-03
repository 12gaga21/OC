; Реализация GDT (Global Descriptor Table) на ассемблере
bits 32

section .text
    global gdt_init
    global gdt_set_gate

; Структура дескриптора GDT
; struct gdt_entry {
;     uint16_t limit_low;    // Смещение 0
;     uint16_t base_low;     // Смещение 2
;     uint8_t base_middle;   // Смещение 4
;     uint8_t access;        // Смещение 5
;     uint8_t granularity;    // Смещение 6
;     uint8_t base_high;     // Смещение 7
; }  // Всего 8 байт

; GDT (3 дескриптора)
gdt:
    ; Нулевой дескриптор (обязательный)
    dq 0
    
    ; Дескриптор кода
    dw 0xFFFF    ; limit_low
    dw 0x0       ; base_low
    db 0x0       ; base_middle
    db 0x9A      ; access (P=1, DPL=0, S=1, E=1, C=1, A=0)
    db 0xCF      ; granularity (G=1, D=1, 0, AVL=0, limit_high=0xF)
    db 0x0       ; base_high
    
    ; Дескриптор данных
    dw 0xFFFF    ; limit_low
    dw 0x0       ; base_low
    db 0x0       ; base_middle
    db 0x92      ; access (P=1, DPL=0, S=1, E=0, W=1, A=0)
    db 0xCF      ; granularity (G=1, B=1, 0, AVL=0, limit_high=0xF)
    db 0x0       ; base_high
    
    ; Дескриптор кода пользователя (ring 3)
    dw 0xFFFF    ; limit_low
    dw 0x0       ; base_low
    db 0x0       ; base_middle
    db 0xFA      ; access (P=1, DPL=3, S=1, E=1, C=1, A=0)
    db 0xCF      ; granularity (G=1, D=1, 0, AVL=0, limit_high=0xF)
    db 0x0       ; base_high
    
    ; Дескриптор данных пользователя (ring 3)
    dw 0xFFFF    ; limit_low
    dw 0x0       ; base_low
    db 0x0       ; base_middle
    db 0xF2      ; access (P=1, DPL=3, S=1, E=0, W=1, A=0)
    db 0xCF      ; granularity (G=1, B=1, 0, AVL=0, limit_high=0xF)
    db 0x0       ; base_high

; Инициализация GDT
gdt_init:
    ; Загрузка GDT
    lgdt [gdt_descriptor]
    
    ; Обновление сегментных регистров
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    
    ; Переход на новый сегмент кода
    jmp 0x08:.next
.next:
    ret

; Установка дескриптора GDT
; Вход: ebx - номер дескриптора
;       eax - база
;       ecx - лимит
;       edx - доступ
;       esi - гранулярность
gdt_set_gate:
    pusha
    
    ; Вычисляем адрес дескриптора
    mov edi, gdt
    movzx ebx, bx
    shl ebx, 3
    add edi, ebx
    
    ; Заполняем дескриптор
    ; limit_low (2 байта)
    mov [edi], cx
    
    ; base_low (2 байта)
    mov [edi + 2], ax
    
    ; base_middle (1 байт)
    shr eax, 16
    mov [edi + 4], al
    
    ; access (1 байт)
    mov [edi + 5], dl
    
    ; granularity (1 байт)
    mov [edi + 6], sil
    
    ; base_high (1 байт)
    shr eax, 8
    mov [edi + 7], al
    
    popa
    ret

section .data
    gdt_descriptor:
        dw 5 * 8 - 1  ; Лимит (5 дескрипторов * 8 байт - 1)
        dd gdt        ; База