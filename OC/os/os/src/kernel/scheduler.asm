; Планировщик задач с приоритетами для ядра ОС
bits 32

section .text
    global scheduler_init
    global scheduler_add_task
    global scheduler_remove_task
    global scheduler_get_next_task
    global scheduler_yield
    global scheduler_set_priority
    global scheduler_get_priority

; Максимальное количество задач в планировщике
MAX_SCHEDULER_TASKS equ 32

; Приоритеты задач
PRIORITY_IDLE      equ 0    ; Фоновые задачи
PRIORITY_LOW       equ 1    ; Низкий приоритет
PRIORITY_NORMAL    equ 2    ; Нормальный приоритет (по умолчанию)
PRIORITY_HIGH      equ 3    ; Высокий приоритет
PRIORITY_REALTIME  equ 4    ; Задачи реального времени

; Структура элемента планировщика
; struct scheduler_entry {
;     uint32_t task_id;      ; ID задачи (0)
;     uint32_t priority;     ; Приоритет (4)
;     uint32_t time_slice;   ; Оставшееся время (8)
;     uint32_t state;        ; Состояние (12)
;     uint32_t next;         ; Следующий элемент (16)
;     uint32_t prev;         ; Предыдущий элемент (20)
; }  // Всего 24 байта

; Массив элементов планировщика
scheduler_entries:
    times MAX_SCHEDULER_TASKS * 24 db 0

; Голова списка готовых задач (индекс в массиве)
ready_list_head dd -1

; Хвост списка готовых задач
ready_list_tail dd -1

; Свободный список (индексы свободных элементов)
free_list_head dd 0

; Текущая выполняемая задача
current_scheduled_task dd -1

; Счётчик тиков для планировщика
scheduler_ticks dd 0

; Инициализация планировщика
scheduler_init:
    pusha
    
    ; Инициализация массива элементов
    mov edi, scheduler_entries
    mov ecx, MAX_SCHEDULER_TASKS
    mov eax, 0
    
.init_loop:
    ; Инициализация элемента
    mov dword [edi], -1           ; task_id = -1 (не используется)
    mov dword [edi + 4], PRIORITY_NORMAL  ; priority = нормальный
    mov dword [edi + 8], 10       ; time_slice = 10 тиков
    mov dword [edi + 12], 0       ; state = 0 (не используется)
    
    ; Настройка связей свободного списка
    mov ebx, eax
    inc ebx
    cmp ebx, MAX_SCHEDULER_TASKS
    jl .set_next
    mov ebx, -1                   ; Последний элемент
    
.set_next:
    mov [edi + 16], ebx           ; next = следующий индекс
    mov [edi + 20], eax           ; prev = предыдущий индекс (для первого 0)
    
    add edi, 24
    inc eax
    loop .init_loop
    
    ; Настройка головы свободного списка
    mov dword [free_list_head], 0
    
    ; Инициализация списка готовых задач
    mov dword [ready_list_head], -1
    mov dword [ready_list_tail], -1
    
    ; Текущая задача не установлена
    mov dword [current_scheduled_task], -1
    
    ; Сброс счётчика тиков
    mov dword [scheduler_ticks], 0
    
    popa
    ret

; Добавление задачи в планировщик
; Вход: eax - ID задачи
;       ebx - приоритет (опционально, по умолчанию PRIORITY_NORMAL)
; Выход: eax - 0 при успехе, -1 при ошибке
scheduler_add_task:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    
    ; Проверка наличия свободного элемента
    mov ecx, [free_list_head]
    cmp ecx, -1
    je .error_no_free
    
    ; Сохраняем параметры
    mov edx, eax  ; task_id
    mov esi, ebx  ; priority
    
    ; Получаем элемент из свободного списка
    mov edi, scheduler_entries
    mov eax, ecx
    mov ebx, 24
    mul ebx
    add edi, eax
    
    ; Удаляем элемент из свободного списка
    mov ecx, [free_list_head]
    mov ebx, [edi + 16]  ; next элемента
    mov [free_list_head], ebx
    
    ; Инициализация элемента
    mov [edi], edx           ; task_id
    cmp esi, 0
    jg .priority_ok
    mov esi, PRIORITY_NORMAL ; приоритет по умолчанию
.priority_ok:
    mov [edi + 4], esi       ; priority
    
    ; Вычисление time_slice на основе приоритета
    mov eax, 10
    cmp esi, PRIORITY_IDLE
    je .set_time_slice
    mov eax, 5
    cmp esi, PRIORITY_LOW
    je .set_time_slice
    mov eax, 10
    cmp esi, PRIORITY_NORMAL
    je .set_time_slice
    mov eax, 20
    cmp esi, PRIORITY_HIGH
    je .set_time_slice
    mov eax, 40              ; PRIORITY_REALTIME
.set_time_slice:
    mov [edi + 8], eax       ; time_slice
    
    ; Добавление в список готовых задач
    call .add_to_ready_list
    
    ; Успех
    mov eax, 0
    jmp .done
    
.error_no_free:
    mov eax, -1
    
.done:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

; Внутренняя функция: добавление элемента в список готовых задач
.add_to_ready_list:
    push eax
    push ebx
    push ecx
    
    ; Получаем индекс элемента
    mov eax, edi
    sub eax, scheduler_entries
    xor edx, edx
    mov ebx, 24
    div ebx
    mov ecx, eax  ; индекс элемента
    
    ; Если список пуст
    cmp dword [ready_list_head], -1
    jne .not_empty
    
    ; Устанавливаем как единственный элемент
    mov [ready_list_head], ecx
    mov [ready_list_tail], ecx
    mov dword [edi + 16], -1  ; next = -1
    mov dword [edi + 20], -1  ; prev = -1
    jmp .add_done
    
.not_empty:
    ; Вставляем в конец списка (FIFO с учётом приоритетов)
    ; Для простоты вставляем в конец, планировщик будет выбирать по приоритету
    mov eax, [ready_list_tail]
    mov ebx, scheduler_entries
    mov edx, eax
    imul edx, 24
    add ebx, edx  ; адрес хвостового элемента
    
    ; Обновляем связи
    mov [ebx + 16], ecx  ; next хвоста -> новый элемент
    mov [edi + 20], eax  ; prev нового элемента -> хвост
    mov [edi + 16], -1   ; next нового элемента -> -1
    mov [ready_list_tail], ecx  ; обновляем хвост
    
.add_done:
    pop ecx
    pop ebx
    pop eax
    ret

; Удаление задачи из планировщика
; Вход: eax - ID задачи
; Выход: eax - 0 при успехе, -1 при ошибке
scheduler_remove_task:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    
    ; Поиск задачи в списке готовых
    mov ebx, [ready_list_head]
    mov ecx, -1  ; предыдущий элемент
    
.search_loop:
    cmp ebx, -1
    je .not_found
    
    ; Получаем адрес элемента
    mov edi, scheduler_entries
    mov edx, ebx
    imul edx, 24
    add edi, edx
    
    ; Проверяем task_id
    cmp [edi], eax
    je .found
    
    ; Переход к следующему элементу
    mov ecx, ebx
    mov ebx, [edi + 16]
    jmp .search_loop
    
.found:
    ; Удаляем элемент из списка
    call .remove_from_list
    
    ; Возвращаем элемент в свободный список
    mov edx, [free_list_head]
    mov [edi + 16], edx  ; next -> старая голова свободного списка
    mov [free_list_head], ebx  ; новая голова
    
    ; Очищаем task_id
    mov dword [edi], -1
    
    ; Успех
    mov eax, 0
    jmp .done
    
.not_found:
    ; Проверяем, не текущая ли это задача
    mov ebx, [current_scheduled_task]
    cmp ebx, -1
    je .error_not_found
    
    mov edi, scheduler_entries
    mov edx, ebx
    imul edx, 24
    add edi, edx
    
    cmp [edi], eax
    jne .error_not_found
    
    ; Если это текущая задача, просто очищаем current_scheduled_task
    mov dword [current_scheduled_task], -1
    mov eax, 0
    jmp .done
    
.error_not_found:
    mov eax, -1
    
.done:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

; Внутренняя функция: удаление элемента из списка
.remove_from_list:
    push eax
    push ebx
    push ecx
    
    ; ebx - индекс удаляемого элемента
    ; ecx - индекс предыдущего элемента (или -1)
    
    ; Получаем адрес элемента
    mov edi, scheduler_entries
    mov eax, ebx
    imul eax, 24
    add edi, eax
    
    ; Получаем next и prev
    mov eax, [edi + 16]  ; next
    mov edx, [edi + 20]  ; prev
    
    ; Обновляем предыдущий элемент
    cmp edx, -1
    je .no_prev
    mov ecx, scheduler_entries
    push eax
    mov eax, edx
    imul eax, 24
    add ecx, eax
    pop eax
    mov [ecx + 16], eax  ; prev->next = наш next
    jmp .update_next
    
.no_prev:
    ; Мы голова списка
    mov [ready_list_head], eax
    
.update_next:
    ; Обновляем следующий элемент
    cmp eax, -1
    je .no_next
    mov ecx, scheduler_entries
    push edx
    mov edx, eax
    imul edx, 24
    add ecx, edx
    pop edx
    mov [ecx + 20], edx  ; next->prev = наш prev
    jmp .update_tail
    
.no_next:
    ; Мы хвост списка
    mov [ready_list_tail], edx
    
.update_tail:
    ; Если удаляемый элемент был хвостом
    cmp [ready_list_tail], ebx
    jne .remove_done
    mov [ready_list_tail], edx
    
.remove_done:
    pop ecx
    pop ebx
    pop eax
    ret

; Получение следующей задачи для выполнения
; Выход: eax - ID следующей задачи, -1 если нет задач
scheduler_get_next_task:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    
    ; Если список готовых задач пуст
    mov eax, [ready_list_head]
    cmp eax, -1
    je .no_tasks
    
    ; Поиск задачи с наивысшим приоритетом
    mov ebx, eax  ; текущий элемент
    mov ecx, -1   ; лучший элемент (индекс)
    mov edx, 0    ; лучший приоритет
    
.search_best:
    cmp ebx, -1
    je .best_found
    
    ; Получаем адрес элемента
    mov edi, scheduler_entries
    mov esi, ebx
    imul esi, 24
    add edi, esi
    
    ; Сравниваем приоритет
    mov esi, [edi + 4]  ; priority
    cmp esi, edx
    jle .not_better
    
    ; Нашли задачу с более высоким приоритетом
    mov ecx, ebx
    mov edx, esi
    
.not_better:
    ; Переход к следующему элементу
    mov ebx, [edi + 16]
    jmp .search_best
    
.best_found:
    cmp ecx, -1
    je .no_tasks
    
    ; Получаем адрес лучшего элемента
    mov edi, scheduler_entries
    mov eax, ecx
    imul eax, 24
    add edi, eax
    
    ; Уменьшаем time_slice
    dec dword [edi + 8]
    
    ; Возвращаем ID задачи
    mov eax, [edi]
    
    ; Обновляем текущую задачу
    mov [current_scheduled_task], ecx
    
    jmp .done
    
.no_tasks:
    mov eax, -1
    
.done:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

; Добровольная передача управления (yield)
; Выход: eax - ID следующей задачи
scheduler_yield:
    push ebx
    push ecx
    push edx
    
    ; Получаем текущую задачу
    mov eax, [current_scheduled_task]
    cmp eax, -1
    je .no_current
    
    ; Получаем адрес текущего элемента
    mov edi, scheduler_entries
    mov ebx, eax
    imul ebx, 24
    add edi, ebx
    
    ; Если time_slice > 0, уменьшаем и продолжаем
    mov ecx, [edi + 8]
    cmp ecx, 0
    jg .continue_current
    
    ; Time_slice исчерпан, сбрасываем и ищем следующую задачу
    ; Восстанавливаем time_slice на основе приоритета
    mov edx, [edi + 4]  ; priority
    mov ecx, 10
    cmp edx, PRIORITY_IDLE
    je .reset_time_slice
    mov ecx, 5
    cmp edx, PRIORITY_LOW
    je .reset_time_slice
    mov ecx, 10
    cmp edx, PRIORITY_NORMAL
    je .reset_time_slice
    mov ecx, 20
    cmp edx, PRIORITY_HIGH
    je .reset_time_slice
    mov ecx, 40
    
.reset_time_slice:
    mov [edi + 8], ecx
    
    ; Ищем следующую задачу
    call scheduler_get_next_task
    jmp .done
    
.continue_current:
    ; Продолжаем текущую задачу
    mov eax, [edi]
    jmp .done
    
.no_current:
    ; Нет текущей задачи, ищем следующую
    call scheduler_get_next_task
    
.done:
    pop edx
    pop ecx
    pop ebx
    ret

; Установка приоритета задачи
; Вход: eax - ID задачи
;       ebx - новый приоритет
; Выход: eax - 0 при успехе, -1 при ошибке
scheduler_set_priority:
    push ecx
    push edx
    push esi
    push edi
    
    ; Поиск задачи
    mov ecx, [ready_list_head]
    
.search_loop:
    cmp ecx, -1
    je .check_current
    
    ; Получаем адрес элемента
    mov edi, scheduler_entries
    mov edx, ecx
    imul edx, 24
    add edi, edx
    
    ; Проверяем task_id
    cmp [edi], eax
    je .found
    
    ; Следующий элемент
    mov ecx, [edi + 16]
    jmp .search_loop
    
.check_current:
    ; Проверяем текущую задачу
    mov ecx, [current_scheduled_task]
    cmp ecx, -1
    je .not_found
    
    mov edi, scheduler_entries
    mov edx, ecx
    imul edx, 24
    add edi, edx
    
    cmp [edi], eax
    jne .not_found
    
.found:
    ; Устанавливаем новый приоритет
    mov [edi + 4], ebx
    
    ; Обновляем time_slice на основе нового приоритета
    mov edx, 10
    cmp ebx, PRIORITY_IDLE
    je .set_time
    mov edx, 5
    cmp ebx, PRIORITY_LOW
    je .set_time
    mov edx, 10
    cmp ebx, PRIORITY_NORMAL
    je .set_time
    mov edx, 20
    cmp ebx, PRIORITY_HIGH
    je .set_time
    mov edx, 40
    
.set_time:
    mov [edi + 8], edx
    
    mov eax, 0
    jmp .done
    
.not_found:
    mov eax, -1
    
.done:
    pop edi
    pop esi
    pop edx
    pop ecx
    ret

; Получение приоритета задачи
; Вход: eax - ID задачи
; Выход: eax - приоритет, -1 при ошибке
scheduler_get_priority:
    push ecx
    push edx
    push edi
    
    ; Поиск задачи
    mov ecx, [ready_list_head]
    
.search_loop:
    cmp ecx, -1
    je .check_current
    
    ; Получаем адрес элемента
    mov edi, scheduler_entries
    mov edx, ecx
    imul edx, 24
    add edi, edx
    
    ; Проверяем task_id
    cmp [edi], eax
    je .found
    
    ; Следующий элемент
    mov ecx, [edi + 16]
    jmp .search_loop
    
.check_current:
    ; Проверяем текущую задачу
    mov ecx, [current_scheduled_task]
    cmp ecx, -1
    je .not_found
    
    mov edi, scheduler_entries
    mov edx, ecx
    imul edx, 24
    add edi, edx
    
    cmp [edi], eax
    jne .not_found
    
.found:
    ; Возвращаем приоритет
    mov eax, [edi + 4]
    jmp .done
    
.not_found:
    mov eax, -1
    
.done:
    pop edi
    pop edx
    pop ecx
    ret

; Обработчик тика таймера для планировщика
; Должен вызываться из обработчика прерывания таймера
global scheduler_tick
scheduler_tick:
    push eax
    
    ; Увеличиваем счётчик тиков
    inc dword [scheduler_ticks]
    
    ; Проверяем, нужно ли переключить задачу
    ; (здесь можно добавить логику квантования времени)
    
    pop eax
    ret

; Получение количества активных задач
global scheduler_get_task_count
scheduler_get_task_count:
    push ebx
    push ecx
    push edx
    
    mov eax, 0  ; счётчик
    mov ebx, [ready_list_head]
    
.count_loop:
    cmp ebx, -1
    je .count_done
    
    inc eax
    
    ; Получаем следующий элемент
    mov edi, scheduler_entries
    mov edx, ebx
    imul edx, 24
    add edi, edx
    mov ebx, [edi + 16]
    
    jmp .count_loop
    
.count_done:
    ; Добавляем текущую задачу, если она есть
    cmp dword [current_scheduled_task], -1
    je .done
    inc eax
    
.done:
    pop edx
    pop ecx
    pop ebx
    ret