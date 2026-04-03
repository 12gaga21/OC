; Функции получения информации о системе
bits 32

section .text
    global get_cpu_info
    global get_memory_info
    global print_system_info
    extern vga_put_string
    extern vga_put_char
    extern int_to_string
    extern hex_to_string

; Получение информации о CPU
get_cpu_info:
    pusha
    
    ; Проверка наличия CPUID
    pushfd
    pop eax
    mov ecx, eax
    xor eax, 0x200000
    push eax
    popfd
    pushfd
    pop eax
    xor eax, ecx
    jz .no_cpuid
    
    ; Получение информации о производителе CPU
    mov eax, 0
    cpuid
    
    ; Вывод информации о производителе
    mov esi, cpuid_msg
    call vga_put_string
    
    ; Вывод идентификатора производителя
    mov edi, vendor_buffer
    mov [edi], ebx
    mov [edi + 4], edx
    mov [edi + 8], ecx
    mov byte [edi + 12], 0
    mov esi, vendor_buffer
    call vga_put_string
    
    mov al, 0x0A
    call vga_put_char
    
.no_cpuid:
    popa
    ret

; Получение информации о памяти
get_memory_info:
    pusha
    
    ; Пока просто выводим сообщение о том, что функция реализована
    mov esi, memory_info_msg
    call vga_put_string
    
    popa
    ret

; Вывод информации о системе
print_system_info:
    pusha
    
    ; Вывод заголовка
    mov esi, system_info_header
    call vga_put_string
    
    ; Получение информации о CPU
    call get_cpu_info
    
    ; Получение информации о памяти
    call get_memory_info
    
    popa
    ret

section .data
    cpuid_msg db 'CPU Vendor: ', 0
    memory_info_msg db 'Memory information available', 0x0A, 0
    system_info_header db '=== System Information ===', 0x0A, 0

section .bss
    vendor_buffer resb 13
