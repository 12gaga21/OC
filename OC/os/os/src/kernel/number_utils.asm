; Функции для работы с числами в ядре операционной системы
bits 32

section .text
    global int_to_string
    global string_to_int
    global hex_to_string

; Преобразование целого числа в строку
; Вход: eax - число для преобразования
;       edi - указатель на буфер для строки (минимум 12 байт)
int_to_string:
    push eax
    push ebx
    push ecx
    push edx
    push edi
    
    ; Сохраняем указатель на буфер
    mov ebx, edi
    
    ; Проверка на отрицательное число
    test eax, eax
    jns .positive
    
    ; Отрицательное число
    mov byte [edi], '-'
    inc edi
    neg eax
    
.positive:
    ; Сохраняем число в ecx
    mov ecx, eax
    
    ; Подсчитываем количество цифр
    mov edx, 0
    mov eax, ecx
    mov ebx, 10
    
.count_digits:
    test eax, eax
    jz .convert
    inc edx
    xor edx, edx
    div ebx
    jmp .count_digits
    
.convert:
    ; Если число 0, то выводим 0
    test ecx, ecx
    jnz .not_zero
    mov byte [edi], '0'
    inc edi
    mov byte [edi], 0
    jmp .done
    
.not_zero:
    ; Сохраняем позицию начала числа
    mov esi, edi
    
    ; Преобразуем число в строку (в обратном порядке)
    mov eax, ecx
    mov ebx, 10
    
.convert_loop:
    test eax, eax
    jz .reverse
    xor edx, edx
    div ebx
    add dl, '0'
    mov [edi], dl
    inc edi
    jmp .convert_loop
    
.reverse:
    ; Завершаем строку нулем
    mov byte [edi], 0
    
    ; Переворачиваем строку
    dec edi
    mov ecx, edi
    sub ecx, esi
    shr ecx, 1
    inc ecx
    
.reverse_loop:
    dec edi
    mov al, [esi]
    mov bl, [edi]
    mov [esi], bl
    mov [edi], al
    inc esi
    cmp esi, edi
    jl .reverse_loop
    
.done:
    pop edi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

; Преобразование строки в целое число
; Вход: esi - указатель на строку
; Выход: eax - преобразованное число
string_to_int:
    push ebx
    push ecx
    push edx
    push esi
    
    xor eax, eax
    xor ebx, ebx
    xor ecx, ecx
    
    ; Проверка на отрицательное число
    cmp byte [esi], '-'
    jne .convert_loop
    inc esi
    mov ebx, 1
    
.convert_loop:
    mov cl, [esi]
    
    ; Проверка на конец строки
    cmp cl, 0
    je .done
    
    ; Проверка на недопустимый символ
    cmp cl, '0'
    jl .done
    cmp cl, '9'
    jg .done
    
    ; Преобразование символа в цифру
    sub cl, '0'
    
    ; Умножение результата на 10
    mov edx, 10
    mul edx
    
    ; Добавление цифры
    add eax, ecx
    
    inc esi
    jmp .convert_loop
    
.done:
    ; Если число отрицательное, меняем знак
    test ebx, ebx
    jz .positive
    neg eax
    
.positive:
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

; Преобразование числа в шестнадцатеричную строку
; Вход: eax - число для преобразования
;       edi - указатель на буфер для строки (минимум 11 байт)
hex_to_string:
    push eax
    push ebx
    push ecx
    push edx
    push edi
    
    ; Сохраняем указатель на буфер
    mov ebx, edi
    
    ; Добавляем префикс "0x"
    mov byte [edi], '0'
    inc edi
    mov byte [edi], 'x'
    inc edi
    
    ; Если число 0, то выводим 0
    test eax, eax
    jnz .convert
    mov byte [edi], '0'
    inc edi
    mov byte [edi], 0
    jmp .done
    
.convert:
    ; Сохраняем позицию начала числа
    mov esi, edi
    
    ; Преобразуем число в строку (в обратном порядке)
    mov ecx, eax
    
.convert_loop:
    test ecx, ecx
    jz .reverse
    mov eax, ecx
    mov ebx, 16
    xor edx, edx
    div ebx
    mov ecx, eax
    
    ; Преобразование остатка в символ
    cmp edx, 9
    jle .digit
    add edx, 'A' - 10
    jmp .store
    
.digit:
    add edx, '0'
    
.store:
    mov [edi], dl
    inc edi
    jmp .convert_loop
    
.reverse:
    ; Завершаем строку нулем
    mov byte [edi], 0
    
    ; Переворачиваем строку
    dec edi
    mov ecx, edi
    sub ecx, esi
    shr ecx, 1
    inc ecx
    
.reverse_loop:
    dec edi
    mov al, [esi]
    mov bl, [edi]
    mov [esi], bl
    mov [edi], al
    inc esi
    cmp esi, edi
    jl .reverse_loop
    
.done:
    pop edi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret
