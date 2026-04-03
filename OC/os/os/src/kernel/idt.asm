; Реализация IDT (Interrupt Descriptor Table) на ассемблере
bits 32

section .text
    global idt_init
    global idt_set_gate
    extern paging_handle_page_fault

; Размер IDT
IDT_SIZE equ 256

; Структура дескриптора прерывания
; struct idt_entry {
;     uint16_t offset_low;   // Смещение 0
;     uint16_t selector;     // Смещение 2
;     uint8_t zero;          // Смещение 4
;     uint8_t type_attr;     // Смещение 5
;     uint16_t offset_high;   // Смещение 6
; }  // Всего 8 байт

; Адрес начала IDT
idt_base dd idt

; Лимит IDT (размер - 1)
idt_limit dw IDT_SIZE * 8 - 1

; IDT (256 дескрипторов)
idt:
    times IDT_SIZE * 8 db 0

; Инициализация IDT
idt_init:
    pusha
    
    ; Очистка таблицы
    mov edi, idt
    mov ecx, IDT_SIZE * 8 / 4
    xor eax, eax
    rep stosd
    
    ; Установка обработчиков исключений (первые 32)
    mov ecx, 32
    xor ebx, ebx
.set_exception_loop:
    ; Для простоты используем один и тот же обработчик для большинства исключений
    ; Но для page fault (14) используем специальный обработчик
    cmp ebx, 14
    je .page_fault
    
    ; Обычный обработчик
    push ecx
    push ebx
    
    push 0x8E        ; флаги
    push 0x08        ; селектор
    push exception_handler  ; адрес обработчика
    push ebx         ; номер прерывания
    call idt_set_gate
    add esp, 16      ; очищаем стек от аргументов
    
    pop ebx
    pop ecx
    jmp .next
    
.page_fault:
    ; Специальный обработчик для page fault
    push ecx
    push ebx
    
    push 0x8E        ; флаги
    push 0x08        ; селектор
    push paging_handle_page_fault  ; адрес обработчика page fault
    push ebx         ; номер прерывания (14)
    call idt_set_gate
    add esp, 16
    
    pop ebx
    pop ecx
    
.next:
    inc ebx
    loop .set_exception_loop
    
    ; Загрузка IDT
    lidt [idt_descriptor]
    
    popa
    ret

; Установка дескриптора прерывания
; Вход: ebx - номер прерывания
;       eax - адрес обработчика
;       edx - селектор
;       ecx - флаги
idt_set_gate:
    pusha
    
    ; Вычисляем адрес дескриптора
    mov edi, idt
    movzx esi, bx
    shl esi, 3
    add edi, esi
    
    ; Заполняем дескриптор
    ; offset_low (2 байта)
    mov [edi], ax
    
    ; selector (2 байта)
    mov [edi + 2], dx
    
    ; zero (1 байт)
    mov byte [edi + 4], 0
    
    ; type_attr (1 байт)
    mov [edi + 5], cl
    
    ; offset_high (2 байта)
    shr eax, 16
    mov [edi + 6], ax
    
    popa
    ret

; Обработчик исключений (заглушка)
exception_handler:
    pusha
    
    ; Выводим сообщение об исключении
    mov esi, msg_exception
    call kprint
    
    ; Бесконечный цикл
    jmp $
    
    popa
    iret

section .data
    idt_descriptor:
        dw IDT_SIZE * 8 - 1  ; Лимит
        dd idt               ; База
    
    msg_exception db "Произошло исключение!", 0x0A, 0
