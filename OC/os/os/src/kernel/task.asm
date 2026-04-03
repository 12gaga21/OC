; Реализация многозадачности для ядра операционной системы на ассемблере
bits 32

section .text
    global task_init
    global task_create
    global task_switch
    global task_get_current_id
    global task_set_state
    extern scheduler_add_task
    extern paging_create_address_space
    extern paging_map_page_in_space
    extern allocate_physical_page
    extern free_physical_page

; Максимальное количество задач
MAX_TASKS equ 16

; Состояния задач
TASK_RUNNING equ 0
TASK_READY   equ 1
TASK_BLOCKED equ 2
TASK_STOPPED equ 3

; Структура задачи
; struct task {
;     uint32_t esp;        // Смещение 0
;     uint32_t ebp;        // Смещение 4
;     uint32_t eip;        // Смещение 8
;     uint32_t cr3;       // Смещение 12
;     uint32_t state;      // Смещение 16
;     uint32_t priority;   // Смещение 20
;     uint32_t stack;      // Смещение 24
;     uint32_t id;         // Смещение 28
; }  // Всего 32 байта

; Массив задач (16 задач по 32 байта каждая)
tasks:
    times MAX_TASKS * 32 db 0

; Текущая задача
current_task dd 0

; Количество активных задач
num_tasks dd 0

; Инициализация системы задач
task_init:
    pusha
    
    ; Инициализация массива задач
    mov edi, tasks
    mov ecx, MAX_TASKS
    xor eax, eax
    
.init_loop:
    ; state = TASK_STOPPED
    mov dword [edi + 16], TASK_STOPPED
    
    ; id = i
    mov ebx, MAX_TASKS
    sub ebx, ecx
    mov [edi + 28], ebx
    
    ; Переход к следующей задаче
    add edi, 32
    loop .init_loop
    
    ; Инициализация текущей задачи (ядро)
    mov edi, tasks
    mov dword [edi + 16], TASK_RUNNING  ; state = TASK_RUNNING
    mov dword [edi + 20], 0            ; priority = 0
    mov dword [edi + 24], 0x90000       ; stack = 0x90000
    mov dword [edi], 0x90000            ; esp = 0x90000
    mov dword [edi + 4], 0x90000        ; ebp = 0x90000
    mov dword [edi + 8], 0              ; eip = 0
    mov dword [edi + 12], 0             ; cr3 = 0
    
    ; current_task = 0
    mov dword [current_task], 0
    
    ; num_tasks = 1
    mov dword [num_tasks], 1
    
    popa
    ret

; Создание новой задачи
; Вход: eax - адрес точки входа
; Выход: eax - идентификатор задачи (-1 если ошибка)
task_create:
    pusha
    push ebx
    push ecx
    push edx
    push esi
    push edi
    
    ; Сохраняем точку входа
    mov ebx, eax
    
    ; Проверка на максимальное количество задач
    mov eax, [num_tasks]
    cmp eax, MAX_TASKS
    jl .find_slot
    
    ; Достигнуто максимальное количество задач
    mov eax, -1
    jmp .done
    
.find_slot:
    ; Поиск свободного слота (начиная с 1)
    mov esi, tasks
    add esi, 32  ; Пропускаем задачу 0 (ядро)
    mov ecx, MAX_TASKS - 1
    mov edx, 1   ; task_id
    
.find_loop:
    cmp dword [esi + 16], TASK_STOPPED  ; state
    je .found_slot
    
    add esi, 32
    inc edx
    loop .find_loop
    
    ; Не найден свободный слот
    mov eax, -1
    jmp .done
    
.found_slot:
    ; Инициализация новой задачи
    mov dword [esi + 16], TASK_READY     ; state = TASK_READY
    mov dword [esi + 20], 2              ; priority = PRIORITY_NORMAL (2)
    
    ; Выделение стека
    mov eax, 0xA0000
    mov edi, edx
    shl edi, 12  ; task_id * 0x1000
    add eax, edi
    mov [esi + 24], eax                  ; stack
    mov [esi], eax                       ; esp
    mov [esi + 4], eax                   ; ebp
    
    mov [esi + 8], ebx                  ; eip = точка входа
    
    ; Создание адресного пространства для задачи
    call paging_create_address_space
    test eax, eax
    jz .create_address_space_error
    mov [esi + 12], eax                  ; cr3 = адрес каталога страниц
    
    ; Увеличение количества задач
    inc dword [num_tasks]
    
    ; Возвращаем идентификатор задачи
    mov eax, edx
    
    ; Добавляем задачу в планировщик
    push eax
    push ebx
    push ecx
    push edx
    mov eax, edx          ; task_id
    mov ebx, 2            ; priority = PRIORITY_NORMAL
    call scheduler_add_task
    pop edx
    pop ecx
    pop ebx
    pop eax
    jmp .done
    
.create_address_space_error:
    ; Не удалось создать адресное пространство
    mov dword [esi + 16], TASK_STOPPED   ; помечаем слот как свободный
    mov eax, -1
    
.done:
    mov [esp + 20], eax  ; Сохраняем результат в eax перед popa
    
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    popa
    ret

; Переключение задач
task_switch:
    pusha
    push ebx
    push ecx
    push edx
    push esi
    push edi
    
    ; Получаем указатель на текущую задачу
    mov eax, [current_task]
    mov ebx, 32
    mul ebx
    mov esi, tasks
    add esi, eax
    
    ; Сохранение состояния текущей задачи
    mov [esi], esp      ; esp
    mov [esi + 4], ebp   ; ebp
    
    ; Поиск следующей задачи
    mov ecx, MAX_TASKS - 1
    mov eax, [current_task]
    inc eax
    
.find_next:
    xor edx, edx
    mov ebx, MAX_TASKS
    div ebx
    mov eax, edx
    
    ; Проверяем состояние задачи
    mov ebx, 32
    mul ebx
    mov edi, tasks
    add edi, eax
    cmp dword [edi + 16], TASK_READY  ; state
    je .switch_to_task
    
    mov ebx, [current_task]
    inc ebx
    mov eax, ebx
    loop .find_next
    
    ; Нет готовых задач, восстанавливаем esp и ebp
    mov esp, [esi]
    mov ebp, [esi + 4]
    
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    popa
    ret
    
.switch_to_task:
    ; Переключение на следующую задачу
    mov [current_task], edx
    
    ; Получаем указатель на новую задачу
    mov eax, edx
    mov ebx, 32
    mul ebx
    mov edi, tasks
    add edi, eax
    
    ; Восстановление состояния новой задачи
    mov esp, [edi]       ; esp
    mov ebp, [edi + 4]    ; ebp
    
    ; Загрузка CR3 (адресного пространства) если не нулевой
    mov eax, [edi + 12]   ; cr3
    test eax, eax
    jz .skip_cr3_load
    mov cr3, eax
.skip_cr3_load:
    
    ; Переход к новой задаче
    push dword [edi + 8]  ; eip
    ret
    
; Получение идентификатора текущей задачи
task_get_current_id:
    mov eax, [current_task]
    ret

; Установка состояния задачи
; Вход: eax - идентификатор задачи
;       ebx - состояние
task_set_state:
    pusha
    
    ; Проверка корректности идентификатора задачи
    cmp eax, 0
    jl .done
    cmp eax, MAX_TASKS
    jge .done
    
    ; Вычисляем адрес задачи
    mov ebx, 32
    mul ebx
    mov edi, tasks
    add edi, eax
    
    ; Устанавливаем состояние
    mov [edi + 16], ebx
    
.done:
    popa
    ret
