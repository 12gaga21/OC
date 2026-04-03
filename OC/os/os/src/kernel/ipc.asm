; Реализация межпроцессного взаимодействия (IPC) для ядра ОС на ассемблере
bits 32

section .text
    global ipc_init
    global ipc_send
    global ipc_receive
    global ipc_queue_status
    extern task_get_current_id

; Конфигурация IPC
MAX_TASKS equ 16
MAX_MESSAGES_PER_QUEUE equ 8
MESSAGE_SIZE equ 20  ; 20 байт на сообщение (4 байта отправитель, 4 байта тип, 12 байт данные)

; Структура сообщения
; struct ipc_message {
;     uint32_t sender_id;   ; ID отправителя
;     uint32_t msg_type;    ; тип сообщения
;     uint8_t data[12];     ; данные сообщения
; }

; Структура очереди сообщений
; struct ipc_queue {
;     uint32_t head;        ; индекс головы (чтение)
;     uint32_t tail;        ; индекс хвоста (запись)
;     uint32_t count;       ; количество сообщений в очереди
;     uint8_t buffer[MAX_MESSAGES_PER_QUEUE * MESSAGE_SIZE];  ; буфер сообщений
; }

; Массив очередей IPC (по одной на задачу)
ipc_queues:
    times MAX_TASKS * (12 + MAX_MESSAGES_PER_QUEUE * MESSAGE_SIZE) db 0

; Инициализация системы IPC
ipc_init:
    pusha
    
    ; Инициализация всех очередей
    mov edi, ipc_queues
    mov ecx, MAX_TASKS
    
.init_loop:
    ; head = 0
    mov dword [edi], 0
    
    ; tail = 0
    mov dword [edi + 4], 0
    
    ; count = 0
    mov dword [edi + 8], 0
    
    ; Переход к следующей очереди
    add edi, 12 + MAX_MESSAGES_PER_QUEUE * MESSAGE_SIZE
    loop .init_loop
    
    popa
    ret

; Отправка сообщения
; Вход: ebx - ID получателя
;       ecx - тип сообщения
;       edx - указатель на данные (12 байт)
; Выход: eax - 0 при успехе, -1 при ошибке
ipc_send:
    pusha
    push ebx
    push ecx
    push edx
    push esi
    push edi
    
    ; Проверка допустимости ID получателя
    cmp ebx, MAX_TASKS
    jge .error
    
    ; Получаем указатель на очередь получателя
    mov eax, 12 + MAX_MESSAGES_PER_QUEUE * MESSAGE_SIZE
    mul ebx
    mov edi, ipc_queues
    add edi, eax
    
    ; Проверка переполнения очереди
    mov eax, [edi + 8]  ; count
    cmp eax, MAX_MESSAGES_PER_QUEUE
    jge .error
    
    ; Получаем текущий ID отправителя
    call task_get_current_id
    mov esi, eax  ; sender_id
    
    ; Вычисляем позицию для записи в буфере
    mov eax, [edi + 4]  ; tail
    mov ebx, MESSAGE_SIZE
    mul ebx
    add eax, 12  ; пропускаем head, tail, count
    add edi, eax
    
    ; Записываем sender_id
    mov [edi], esi
    
    ; Записываем msg_type
    mov [edi + 4], ecx
    
    ; Копируем данные (12 байт)
    push ecx
    mov ecx, 3  ; 3 двойных слова = 12 байт
    mov esi, edx
    add edi, 8
.copy_data:
    mov eax, [esi]
    mov [edi], eax
    add esi, 4
    add edi, 4
    loop .copy_data
    pop ecx
    
    ; Обновляем tail и count
    mov edi, ipc_queues
    mov eax, 12 + MAX_MESSAGES_PER_QUEUE * MESSAGE_SIZE
    mul ebx  ; ebx всё ещё содержит ID получателя
    add edi, eax
    
    ; Увеличиваем tail (кольцевой буфер)
    mov eax, [edi + 4]
    inc eax
    cmp eax, MAX_MESSAGES_PER_QUEUE
    jl .no_wrap
    xor eax, eax
.no_wrap:
    mov [edi + 4], eax
    
    ; Увеличиваем count
    inc dword [edi + 8]
    
    ; Успех
    xor eax, eax
    jmp .done
    
.error:
    mov eax, -1
    
.done:
    mov [esp + 28], eax  ; Сохраняем результат в eax перед popa
    
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    popa
    ret

; Получение сообщения
; Вход: ebx - указатель на буфер для сообщения (20 байт)
; Выход: eax - 0 при успехе, -1 если очередь пуста
ipc_receive:
    pusha
    push ebx
    push ecx
    push edx
    push esi
    push edi
    
    ; Получаем текущий ID задачи
    call task_get_current_id
    mov esi, eax  ; task_id
    
    ; Получаем указатель на очередь текущей задачи
    mov eax, 12 + MAX_MESSAGES_PER_QUEUE * MESSAGE_SIZE
    mul esi
    mov edi, ipc_queues
    add edi, eax
    
    ; Проверка пустоты очереди
    mov eax, [edi + 8]  ; count
    test eax, eax
    jz .error
    
    ; Вычисляем позицию для чтения из буфера
    mov eax, [edi]  ; head
    mov ecx, MESSAGE_SIZE
    mul ecx
    add eax, 12  ; пропускаем head, tail, count
    add edi, eax
    
    ; Копируем сообщение в буфер пользователя
    mov esi, edi
    mov edi, [esp + 28]  ; получаем ebx из стека (буфер)
    
    ; Копируем 20 байт (5 двойных слов)
    mov ecx, 5
.copy_message:
    mov eax, [esi]
    mov [edi], eax
    add esi, 4
    add edi, 4
    loop .copy_message
    
    ; Обновляем head и count
    mov edi, ipc_queues
    mov eax, 12 + MAX_MESSAGES_PER_QUEUE * MESSAGE_SIZE
    mul esi
    add edi, eax
    
    ; Увеличиваем head (кольцевой буфер)
    mov eax, [edi]
    inc eax
    cmp eax, MAX_MESSAGES_PER_QUEUE
    jl .no_wrap2
    xor eax, eax
.no_wrap2:
    mov [edi], eax
    
    ; Уменьшаем count
    dec dword [edi + 8]
    
    ; Успех
    xor eax, eax
    jmp .done2
    
.error:
    mov eax, -1
    
.done2:
    mov [esp + 28], eax  ; Сохраняем результат в eax перед popa
    
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    popa
    ret

; Получение статуса очереди
; Вход: ebx - ID задачи (или -1 для текущей)
; Выход: eax - количество сообщений в очереди, -1 при ошибке
ipc_queue_status:
    pusha
    push ebx
    
    ; Если ebx = -1, используем текущую задачу
    cmp ebx, -1
    jne .not_current
    call task_get_current_id
    mov ebx, eax
    
.not_current:
    ; Проверка допустимости ID
    cmp ebx, MAX_TASKS
    jge .error3
    
    ; Получаем указатель на очередь
    mov eax, 12 + MAX_MESSAGES_PER_QUEUE * MESSAGE_SIZE
    mul ebx
    mov edi, ipc_queues
    add edi, eax
    
    ; Получаем count
    mov eax, [edi + 8]
    jmp .done3
    
.error3:
    mov eax, -1
    
.done3:
    mov [esp + 24], eax  ; Сохраняем результат в eax перед popa
    
    pop ebx
    popa
    ret