; Реализация примитивов синхронизации (семафоры и мьютексы) для ядра ОС на ассемблере
bits 32

section .text
    global sync_init
    global semaphore_create
    global semaphore_wait
    global semaphore_signal
    global mutex_create
    global mutex_lock
    global mutex_unlock
    extern task_get_current_id

; Конфигурация синхронизации
MAX_SEMAPHORES equ 8
MAX_MUTEXES equ 8

; Структура семафора
; struct semaphore {
;     uint32_t value;        ; текущее значение семафора
;     uint32_t max_value;    ; максимальное значение
;     uint32_t waiting_list[MAX_TASKS];  ; список ожидающих задач
;     uint32_t waiting_count; ; количество ожидающих задач
; }

; Структура мьютекса
; struct mutex {
;     uint32_t locked;       ; 0 = свободен, 1 = занят
;     uint32_t owner;        ; ID задачи-владельца
;     uint32_t waiting_list[MAX_TASKS];  ; список ожидающих задач
;     uint32_t waiting_count; ; количество ожидающих задач
; }

; Массив семафоров
semaphores:
    times MAX_SEMAPHORES * (4 + 4 + MAX_TASKS * 4 + 4) db 0

; Массив мьютексов
mutexes:
    times MAX_MUTEXES * (4 + 4 + MAX_TASKS * 4 + 4) db 0

; Инициализация системы синхронизации
sync_init:
    pusha
    
    ; Инициализация всех семафоров
    mov edi, semaphores
    mov ecx, MAX_SEMAPHORES
    
.init_sem_loop:
    ; value = 0
    mov dword [edi], 0
    
    ; max_value = 0
    mov dword [edi + 4], 0
    
    ; waiting_count = 0
    mov dword [edi + 8 + MAX_TASKS * 4], 0
    
    ; Переход к следующему семафору
    add edi, 4 + 4 + MAX_TASKS * 4 + 4
    loop .init_sem_loop
    
    ; Инициализация всех мьютексов
    mov edi, mutexes
    mov ecx, MAX_MUTEXES
    
.init_mutex_loop:
    ; locked = 0
    mov dword [edi], 0
    
    ; owner = -1 (нет владельца)
    mov dword [edi + 4], -1
    
    ; waiting_count = 0
    mov dword [edi + 8 + MAX_TASKS * 4], 0
    
    ; Переход к следующему мьютексу
    add edi, 4 + 4 + MAX_TASKS * 4 + 4
    loop .init_mutex_loop
    
    popa
    ret

; Создание семафора
; Вход: ebx - начальное значение
;       ecx - максимальное значение
; Выход: eax - ID семафора (-1 при ошибке)
semaphore_create:
    pusha
    push ebx
    push ecx
    push edx
    push esi
    push edi
    
    ; Поиск свободного семафора
    mov edi, semaphores
    mov ecx, MAX_SEMAPHORES
    xor edx, edx  ; индекс
    
.find_free_sem:
    cmp dword [edi + 4], 0  ; max_value = 0 означает свободный слот
    je .found_free_sem
    
    add edi, 4 + 4 + MAX_TASKS * 4 + 4
    inc edx
    loop .find_free_sem
    
    ; Не найден свободный слот
    mov eax, -1
    jmp .done_sem_create
    
.found_free_sem:
    ; Инициализация семафора
    mov eax, [esp + 28]  ; получаем ebx из стека (начальное значение)
    mov [edi], eax       ; value = начальное значение
    
    mov eax, [esp + 24]  ; получаем ecx из стека (максимальное значение)
    mov [edi + 4], eax   ; max_value = максимальное значение
    
    ; waiting_count = 0
    mov dword [edi + 8 + MAX_TASKS * 4], 0
    
    ; Возвращаем ID семафора
    mov eax, edx
    
.done_sem_create:
    mov [esp + 36], eax  ; Сохраняем результат в eax перед popa
    
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    popa
    ret

; Ожидание семафора (P-операция)
; Вход: ebx - ID семафора
; Выход: eax - 0 при успехе, -1 при ошибке
semaphore_wait:
    pusha
    push ebx
    push ecx
    push edx
    push esi
    push edi
    
    ; Проверка допустимости ID
    cmp ebx, MAX_SEMAPHORES
    jge .error_sem_wait
    
    ; Получаем указатель на семафор
    mov eax, 4 + 4 + MAX_TASKS * 4 + 4
    mul ebx
    mov edi, semaphores
    add edi, eax
    
    ; Атомарно уменьшаем value
.try_again:
    mov eax, [edi]  ; value
    test eax, eax
    jz .block  ; если value = 0, блокируем задачу
    
    ; Пытаемся атомарно уменьшить value
    lock dec dword [edi]
    jns .success  ; если после декремента не отрицательное
    
    ; Если стало отрицательным, откатываем
    lock inc dword [edi]
    jmp .block
    
.block:
    ; Добавляем задачу в список ожидания
    call task_get_current_id
    mov esi, eax
    
    ; Получаем waiting_count
    mov edx, [edi + 8 + MAX_TASKS * 4]
    cmp edx, MAX_TASKS
    jge .error_sem_wait  ; список ожидания переполнен
    
    ; Добавляем задачу в waiting_list
    mov ecx, edx
    shl ecx, 2  ; умножение на 4
    add ecx, 8  ; пропускаем value и max_value
    mov [edi + ecx], esi
    
    ; Увеличиваем waiting_count
    inc dword [edi + 8 + MAX_TASKS * 4]
    
    ; Блокируем задачу (переводим в состояние BLOCKED)
    ; Для этого нужно вызвать функцию блокировки задачи
    ; Пока просто возвращаем ошибку (в реальной реализации нужно блокировать)
    mov eax, -2  ; специальный код "заблокирован"
    jmp .done_sem_wait
    
.success:
    xor eax, eax
    jmp .done_sem_wait
    
.error_sem_wait:
    mov eax, -1
    
.done_sem_wait:
    mov [esp + 28], eax  ; Сохраняем результат в eax перед popa
    
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    popa
    ret

; Сигнал семафора (V-операция)
; Вход: ebx - ID семафора
; Выход: eax - 0 при успехе, -1 при ошибке
semaphore_signal:
    pusha
    push ebx
    push ecx
    push edx
    push esi
    push edi
    
    ; Проверка допустимости ID
    cmp ebx, MAX_SEMAPHORES
    jge .error_sem_signal
    
    ; Получаем указатель на семафор
    mov eax, 4 + 4 + MAX_TASKS * 4 + 4
    mul ebx
    mov edi, semaphores
    add edi, eax
    
    ; Проверяем, есть ли ожидающие задачи
    mov edx, [edi + 8 + MAX_TASKS * 4]  ; waiting_count
    test edx, edx
    jnz .wakeup
    
    ; Нет ожидающих задач - просто увеличиваем value
    mov eax, [edi + 4]  ; max_value
    cmp [edi], eax      ; сравниваем value с max_value
    jge .error_sem_signal  ; value уже равно max_value
    
    lock inc dword [edi]
    xor eax, eax
    jmp .done_sem_signal
    
.wakeup:
    ; Будим первую задачу из списка ожидания
    mov esi, [edi + 8]  ; первая задача в waiting_list
    
    ; Сдвигаем список ожидания
    mov ecx, edx
    dec ecx
    jz .no_shift  ; если только одна задача
    
    ; Копируем оставшиеся задачи
    mov edx, edi
    add edx, 12  ; waiting_list[1]
    mov eax, edi
    add eax, 8   ; waiting_list[0]
    
.shift_loop:
    mov ebx, [edx]
    mov [eax], ebx
    add edx, 4
    add eax, 4
    loop .shift_loop
    
.no_shift:
    ; Уменьшаем waiting_count
    dec dword [edi + 8 + MAX_TASKS * 4]
    
    ; Разблокируем задачу (в реальной реализации)
    ; Пока просто возвращаем успех
    xor eax, eax
    jmp .done_sem_signal
    
.error_sem_signal:
    mov eax, -1
    
.done_sem_signal:
    mov [esp + 28], eax  ; Сохраняем результат в eax перед popa
    
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    popa
    ret

; Создание мьютекса
; Выход: eax - ID мьютекса (-1 при ошибке)
mutex_create:
    pusha
    push ebx
    push ecx
    push edx
    push esi
    push edi
    
    ; Поиск свободного мьютекса
    mov edi, mutexes
    mov ecx, MAX_MUTEXES
    xor edx, edx  ; индекс
    
.find_free_mutex:
    cmp dword [edi + 4], -1  ; owner = -1 означает свободный слот
    je .found_free_mutex
    
    add edi, 4 + 4 + MAX_TASKS * 4 + 4
    inc edx
    loop .find_free_mutex
    
    ; Не найден свободный слот
    mov eax, -1
    jmp .done_mutex_create
    
.found_free_mutex:
    ; Инициализация мьютекса
    mov dword [edi], 0       ; locked = 0
    mov dword [edi + 4], -1  ; owner = -1
    mov dword [edi + 8 + MAX_TASKS * 4], 0  ; waiting_count = 0
    
    ; Возвращаем ID мьютекса
    mov eax, edx
    
.done_mutex_create:
    mov [esp + 36], eax  ; Сохраняем результат в eax перед popa
    
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    popa
    ret

; Захват мьютекса
; Вход: ebx - ID мьютекса
; Выход: eax - 0 при успехе, -1 при ошибке
mutex_lock:
    pusha
    push ebx
    push ecx
    push edx
    push esi
    push edi
    
    ; Проверка допустимости ID
    cmp ebx, MAX_MUTEXES
    jge .error_mutex_lock
    
    ; Получаем указатель на мьютекс
    mov eax, 4 + 4 + MAX_TASKS * 4 + 4
    mul ebx
    mov edi, mutexes
    add edi, eax
    
    ; Получаем ID текущей задачи
    call task_get_current_id
    mov esi, eax
    
    ; Пытаемся атомарно захватить мьютекс
.try_lock:
    mov eax, [edi]  ; locked
    test eax, eax
    jnz .already_locked  ; уже заблокирован
    
    ; Пытаемся установить locked = 1 и owner = текущая задача
    ; Нужна атомарная операция сравнения и обмена (CAS)
    ; Для простоты используем спин-лок
    mov eax, 1
    xchg eax, [edi]  ; атомарно обмениваем locked с 1
    test eax, eax
    jnz .already_locked  ; кто-то успел захватить
    
    ; Устанавливаем owner
    mov [edi + 4], esi
    
    xor eax, eax
    jmp .done_mutex_lock
    
.already_locked:
    ; Проверяем, не владеем ли мы уже мьютексом (рекурсивный захват)
    mov eax, [edi + 4]  ; owner
    cmp eax, esi
    je .error_mutex_lock  ; рекурсивный захват не поддерживается
    
    ; Добавляем задачу в список ожидания
    mov edx, [edi + 8 + MAX_TASKS * 4]  ; waiting_count
    cmp edx, MAX_TASKS
    jge .error_mutex_lock  ; список ожидания переполнен
    
    ; Добавляем задачу в waiting_list
    mov ecx, edx
    shl ecx, 2  ; умножение на 4
    add ecx, 8  ; пропускаем locked и owner
    mov [edi + ecx], esi
    
    ; Увеличиваем waiting_count
    inc dword [edi + 8 + MAX_TASKS * 4]
    
    ; Блокируем задачу
    mov eax, -2  ; специальный код "заблокирован"
    jmp .done_mutex_lock
    
.error_mutex_lock:
    mov eax, -1
    
.done_mutex_lock:
    mov [esp + 28], eax  ; Сохраняем результат в eax перед popa
    
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    popa
    ret

; Освобождение мьютекса
; Вход: ebx - ID мьютекса
; Выход: eax - 0 при успехе, -1 при ошибке
mutex_unlock:
    pusha
    push ebx
    push ecx
    push edx
    push esi
    push edi
    
    ; Проверка допустимости ID
    cmp ebx, MAX_MUTEXES
    jge .error_mutex_unlock
    
    ; Получаем указатель на мьютекс
    mov eax, 4 + 4 + MAX_TASKS * 4 + 4
    mul ebx
    mov edi, mutexes
    add edi, eax
    
    ; Получаем ID текущей задачи
    call task_get_current_id
    mov esi, eax
    
    ; Проверяем, владеем ли мы мьютексом
    mov eax, [edi + 4]  ; owner
    cmp eax, esi
    jne .error_mutex_unlock  ; не владеем
    
    ; Проверяем, есть ли ожидающие задачи
    mov edx, [edi + 8 + MAX_TASKS * 4]  ; waiting_count
    test edx, edx
    jnz .wakeup_mutex
    
    ; Нет ожидающих задач - просто освобождаем мьютекс
    mov dword [edi], 0       ; locked = 0
    mov dword [edi + 4], -1  ; owner = -1
    xor eax, eax
    jmp .done_mutex_unlock
    
.wakeup_mutex:
    ; Будим первую задачу из списка ожидания
    mov ecx, [edi + 8]  ; первая задача в waiting_list
    
    ; Устанавливаем нового владельца
    mov [edi + 4], ecx  ; owner = задача из списка ожидания
    ; locked остаётся = 1 (мьютекс всё ещё заблокирован)
    
    ; Сдвигаем список ожидания
    dec edx
    jz .no_shift_mutex  ; если только одна задача
    
    ; Копируем оставшиеся задачи
    mov eax, edi
    add eax, 12  ; waiting_list[1]
    mov ebx, edi
    add ebx, 8   ; waiting_list[0]
    
.shift_mutex_loop:
    mov esi, [eax]
    mov [ebx], esi
    add eax, 4
    add ebx, 4
    dec edx
    jnz .shift_mutex_loop
    
.no_shift_mutex:
    ; Уменьшаем waiting_count
    dec dword [edi + 8 + MAX_TASKS * 4]
    
    ; Разблокируем задачу (в реальной реализации)
    xor eax, eax
    jmp .done_mutex_unlock
    
.error_mutex_unlock:
    mov eax, -1
    
.done_mutex_unlock:
    mov [esp + 28], eax  ; Сохраняем результат в eax перед popa
    
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    popa
    ret