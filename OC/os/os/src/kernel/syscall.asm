; Реализация системных вызовов для ядра операционной системы на ассемблере
bits 32

section .text
    global syscall_handler
    global syscall_init
    extern kprint
    extern scheduler_yield
    extern scheduler_set_priority
    extern scheduler_get_priority
    extern ipc_send
    extern ipc_receive
    extern ipc_queue_status
    extern semaphore_create
    extern semaphore_wait
    extern semaphore_signal
    extern mutex_create
    extern mutex_lock
    extern mutex_unlock

; Номера системных вызовов
SYSCALL_PRINT equ 1
SYSCALL_EXIT equ 2
SYSCALL_CREATE_TASK equ 3
SYSCALL_GET_PID equ 4
SYSCALL_SCHED_YIELD equ 5
SYSCALL_SET_PRIORITY equ 6
SYSCALL_GET_PRIORITY equ 7
SYSCALL_IPC_SEND equ 8
SYSCALL_IPC_RECEIVE equ 9
SYSCALL_IPC_QUEUE_STATUS equ 10
SYSCALL_SEM_CREATE equ 11
SYSCALL_SEM_WAIT equ 12
SYSCALL_SEM_SIGNAL equ 13
SYSCALL_MUTEX_CREATE equ 14
SYSCALL_MUTEX_LOCK equ 15
SYSCALL_MUTEX_UNLOCK equ 16

; Обработчик системных вызовов
; Вход: eax - номер системного вызова
;       ebx - первый аргумент
;       ecx - второй аргумент
;       edx - третий аргумент
syscall_handler:
    pusha
    
    ; Сохраняем аргументы
    push edx
    push ecx
    push ebx
    push eax
    
    ; Проверяем номер системного вызова
    cmp eax, SYSCALL_PRINT
    je .syscall_print
    cmp eax, SYSCALL_EXIT
    je .syscall_exit
    cmp eax, SYSCALL_CREATE_TASK
    je .syscall_create_task
    cmp eax, SYSCALL_GET_PID
    je .syscall_get_pid
    cmp eax, SYSCALL_SCHED_YIELD
    je .syscall_sched_yield
    cmp eax, SYSCALL_SET_PRIORITY
    je .syscall_set_priority
    cmp eax, SYSCALL_GET_PRIORITY
    je .syscall_get_priority
    cmp eax, SYSCALL_IPC_SEND
    je .syscall_ipc_send
    cmp eax, SYSCALL_IPC_RECEIVE
    je .syscall_ipc_receive
    cmp eax, SYSCALL_IPC_QUEUE_STATUS
    je .syscall_ipc_queue_status
    cmp eax, SYSCALL_SEM_CREATE
    je .syscall_sem_create
    cmp eax, SYSCALL_SEM_WAIT
    je .syscall_sem_wait
    cmp eax, SYSCALL_SEM_SIGNAL
    je .syscall_sem_signal
    cmp eax, SYSCALL_MUTEX_CREATE
    je .syscall_mutex_create
    cmp eax, SYSCALL_MUTEX_LOCK
    je .syscall_mutex_lock
    cmp eax, SYSCALL_MUTEX_UNLOCK
    je .syscall_mutex_unlock
    
    ; Неизвестный системный вызов
    mov esi, msg_unknown_syscall
    call kprint
    jmp .done
    
.syscall_print:
    ; Аргумент в ebx - указатель на строку
    mov esi, ebx
    call kprint
    jmp .done
    
.syscall_exit:
    ; Для простоты просто выводим сообщение
    mov esi, msg_task_exit
    call kprint
    jmp .done
    
.syscall_create_task:
    ; Для простоты просто выводим сообщение
    mov esi, msg_task_create
    call kprint
    jmp .done
    
.syscall_get_pid:
    ; Для простоты просто выводим сообщение
    mov esi, msg_get_pid
    call kprint
    jmp .done

.syscall_sched_yield:
    call scheduler_yield
    jmp .done

.syscall_set_priority:
    ; ebx = task_id, ecx = priority
    push ecx
    push ebx
    call scheduler_set_priority
    add esp, 8
    jmp .done

.syscall_get_priority:
    ; ebx = task_id
    push ebx
    call scheduler_get_priority
    add esp, 4
    jmp .done

.syscall_ipc_send:
    ; ebx = receiver_id, ecx = msg_type, edx = data_ptr
    push edx
    push ecx
    push ebx
    call ipc_send
    add esp, 12
    jmp .done

.syscall_ipc_receive:
    ; ebx = buffer_ptr
    push ebx
    call ipc_receive
    add esp, 4
    jmp .done

.syscall_ipc_queue_status:
    ; ebx = task_id (-1 for current)
    push ebx
    call ipc_queue_status
    add esp, 4
    jmp .done

.syscall_sem_create:
    ; ebx = initial_value, ecx = max_value
    push ecx
    push ebx
    call semaphore_create
    add esp, 8
    jmp .done

.syscall_sem_wait:
    ; ebx = sem_id
    push ebx
    call semaphore_wait
    add esp, 4
    jmp .done

.syscall_sem_signal:
    ; ebx = sem_id
    push ebx
    call semaphore_signal
    add esp, 4
    jmp .done

.syscall_mutex_create:
    call mutex_create
    jmp .done

.syscall_mutex_lock:
    ; ebx = mutex_id
    push ebx
    call mutex_lock
    add esp, 4
    jmp .done

.syscall_mutex_unlock:
    ; ebx = mutex_id
    push ebx
    call mutex_unlock
    add esp, 4
    jmp .done
    
.done:
    ; Восстанавливаем аргументы
    pop eax
    pop ebx
    pop ecx
    pop edx
    
    popa
    ret

; Инициализация системных вызовов
syscall_init:
    pusha
    
    mov esi, msg_syscall_init
    call kprint
    
    popa
    ret

section .data
    msg_unknown_syscall db "Неизвестный системный вызов", 0x0A, 0
    msg_syscall_init db "Системные вызовы инициализированы", 0x0A, 0
    msg_task_exit db "Завершение задачи", 0x0A, 0
    msg_task_create db "Создание задачи", 0x0A, 0
    msg_get_pid db "Получение PID", 0x0A, 0
