; ============================================================================
; ПРИМѢРЪ ПРОГРАММЫ ДЛЯ ОС "ЗОЛОТОЙ МЕХАНИКУСЪ"
; Файлъ: hello.asm
; Назначеніе: Демонстрація использованія Священной Библіотеки
; Стиль: Злато-Изумрудный Ритуалъ
; ============================================================================

BITS 32
SECTION .text
GLOBAL _start

; Импортируемъ функции изъ Священной Библіотеки
EXTERN sl_init, sl_print_string, sl_clear_screen
EXTERN sl_print_hex, sl_print_dec, sl_set_cursor
EXTERN sl_delay, sl_rand, sl_rand_seed

SECTION .data
    ; Приветственныя сообщенія
    msg_title db '† † † СЛАВА ОМНИССІИ! † † †', 0
    msg_welcome db 'Добро пожаловать въ систему "Золотой Механикусъ"', 0
    msg_test db 'Тестированіе Священной Библіотеки...', 0
    msg_random db 'Случайное число: ', 0
    msg_hex db 'Число въ HEX: 0x', 0
    msg_complete db 'Тестированіе завершено успешно!', 0
    msg_farewell db 'Слава Отечеству! Слава Вѣрѣ!', 0
    
    ; Число для демонстраціи
    test_num dd 0xCAFE1234

SECTION .text
_start:
    ; ========================================
    ; ИНИЦИАЛИЗАЦІЯ
    ; ========================================
    call sl_init              ; Очистка экрана, сбросъ курсора
    
    ; ========================================
    ; ВЫВОДЪ ЗАГОЛОВКА
    ; ========================================
    mov esi, msg_title
    call sl_print_string
    
    ; Переходъ на слѣдующую строку
    mov ax, 0
    mov bx, 2
    call sl_set_cursor
    
    mov esi, msg_welcome
    call sl_print_string
    
    ; ========================================
    ; ДЕMONSTRATION ВЫВОДА ЧИСЕЛЪ
    ; ========================================
    mov ax, 0
    mov bx, 5
    call sl_set_cursor
    
    mov esi, msg_test
    call sl_print_string
    
    ; Выводъ числа въ DEC
    mov ax, 0
    mov bx, 7
    call sl_set_cursor
    
    mov eax, 12345
    call sl_print_dec
    
    ; Выводъ числа въ HEX
    mov ax, 20
    mov bx, 7
    call sl_set_cursor
    
    mov esi, msg_hex
    call sl_print_string
    
    mov eax, [test_num]
    call sl_print_hex
    
    ; ========================================
    ; ГЕНЕРАЦІЯ СЛУЧАЙНАГО ЧИСЛА
    ; ========================================
    mov ax, 0
    mov bx, 10
    call sl_set_cursor
    
    mov esi, msg_random
    call sl_print_string
    
    ; Инициализація генератора
    mov eax, 77777
    call sl_rand_seed
    
    ; Полученіе случайнаго числа
    call sl_rand
    call sl_print_dec
    
    ; ========================================
    ; ЗАДЕРЖКА И ФИНАЛЬНЫЯ СООБЩЕНІЯ
    ; ========================================
    mov ecx, 50000000       ; Задержка ~1 секунда
    call sl_delay
    
    mov ax, 0
    mov bx, 12
    call sl_set_cursor
    
    mov esi, msg_complete
    call sl_print_string
    
    mov ax, 0
    mov bx, 14
    call sl_set_cursor
    
    mov esi, msg_farewell
    call sl_print_string
    
    ; ========================================
    ; БЕЗКОНЕЧНЫЙ ЦИКЛЪ (HALT)
    ; ========================================
.halt:
    jmp .halt               ; Ожиданіе перезагрузки

; ----------------------------------------------------------------------------
; КОНЕЦЪ ПРОГРАММЫ
; ----------------------------------------------------------------------------
SECTION .note
    db 'Примѣръ программы Hello World', 0
    db 'Версія 1.0', 0
    db 'Для ОС "Золотой Механикусъ"', 0
