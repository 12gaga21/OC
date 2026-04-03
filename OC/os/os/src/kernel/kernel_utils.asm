; Вспомогательные функции ядра операционной системы
bits 32

section .text
    global strlen
    global strcpy
    global strcmp
    global memset
    global memcpy

; Вычисление длины строки
; Вход: esi - указатель на строку
; Выход: eax - длина строки
strlen:
    push esi
    xor eax, eax
    
.loop:
    cmp byte [esi], 0
    je .done
    inc eax
    inc esi
    jmp .loop
    
.done:
    pop esi
    ret

; Копирование строки
; Вход: edi - указатель на целевую строку
;       esi - указатель на исходную строку
strcpy:
    push edi
    push esi
    
.loop:
    mov al, [esi]
    mov [edi], al
    test al, al
    jz .done
    inc esi
    inc edi
    jmp .loop
    
.done:
    pop esi
    pop edi
    ret

; Сравнение строк
; Вход: esi - указатель на первую строку
;       edi - указатель на вторую строку
; Выход: eax - 0 если строки равны, < 0 если первая < второй, > 0 если первая > второй
strcmp:
    push esi
    push edi
    
.loop:
    mov al, [esi]
    mov bl, [edi]
    cmp al, bl
    jl .less
    jg .greater
    test al, al
    jz .equal
    inc esi
    inc edi
    jmp .loop
    
.less:
    mov eax, -1
    jmp .done
    
.greater:
    mov eax, 1
    jmp .done
    
.equal:
    xor eax, eax
    
.done:
    pop edi
    pop esi
    ret

; Заполнение памяти значением
; Вход: edi - указатель на область памяти
;       eax - значение для заполнения
;       ecx - количество байт
memset:
    push edi
    push ecx
    
    ; Проверка, можно ли использовать двойные слова
    test ecx, ecx
    jz .done
    
    ; Заполнение байтами
    rep stosb
    
.done:
    pop ecx
    pop edi
    ret

; Копирование памяти
; Вход: edi - указатель на целевую область памяти
;       esi - указатель на исходную область памяти
;       ecx - количество байт
memcpy:
    push edi
    push esi
    push ecx
    
    ; Проверка, можно ли использовать двойные слова
    test ecx, ecx
    jz .done
    
    ; Копирование байтами
    rep movsb
    
.done:
    pop ecx
    pop esi
    pop edi
    ret
