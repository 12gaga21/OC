; Работа с FAT таблицей для ОС
bits 32

section .text
    global fat_init
    global fat_get_next_cluster
    global fat_cluster_to_sector
    global fat_read_fat
    extern printf

; Инициализация FAT
fat_init:
    pusha
    
    ; Пока просто инициализируем переменные
    mov dword [fat_initialized], 1
    
    popa
    ret

; Чтение FAT таблицы в память
fat_read_fat:
    pusha
    push es
    
    ; Установка сегмента ES на адрес буфера для FAT
    mov ax, 0x3000  ; Сегмент для буфера FAT
    mov es, ax
    
    ; Вычисление количества секторов для чтения FAT
    movzx eax, word [sectors_per_fat]
    movzx ecx, ax   ; Количество секторов
    
    ; Чтение FAT таблицы
    mov ah, 0x02    ; Функция чтения секторов
    mov al, cl      ; Количество секторов для чтения
    mov ch, 0       ; Номер дорожки (временно 0)
    mov cl, [fat_start]  ; Номер сектора начала FAT
    mov dh, 0       ; Номер головки
    mov dl, 0x80    ; Номер диска
    mov bx, 0       ; Смещение в сегменте ES
    int 0x13        ; Вызов BIOS
    
    pop es
    popa
    ret

; Получение следующего кластера в цепочке
; Вход: eax - номер текущего кластера
; Выход: eax - номер следующего кластера (0xFFFFFFFF если последний)
fat_get_next_cluster:
    pusha
    push es
    
    ; Установка сегмента ES на адрес буфера FAT
    mov ax, 0x3000  ; Сегмент для буфера FAT
    mov es, ax
    
    ; Вычисление смещения в FAT для текущего кластера
    ; Для FAT16 каждый элемент занимает 2 байта
    mov ebx, 2
    mul ebx
    mov ebx, [bytes_per_sector]
    div ebx
    movzx ecx, ax   ; Номер сектора относительно начала FAT
    mov edx, edx    ; Смещение внутри сектора
    
    ; Чтение сектора FAT, содержащего нужный элемент
    mov ah, 0x02    ; Функция чтения секторов
    mov al, 1       ; Количество секторов для чтения
    mov ch, 0       ; Номер дорожки (временно 0)
    mov cl, [fat_start]
    add cl, cl      ; Добавление смещения сектора
    mov dh, 0       ; Номер головки
    mov dl, 0x80    ; Номер диска
    mov bx, 0       ; Смещение в сегменте ES
    int 0x13        ; Вызов BIOS
    
    ; Получение значения следующего кластера
    movzx eax, word [es:edx]  ; Чтение 2-байтного значения
    
    ; Проверка на признак последнего кластера
    cmp eax, 0xFFF8
    jae .last_cluster
    
    jmp .done
    
.last_cluster:
    mov eax, 0xFFFFFFFF  ; Признак последнего кластера
    
.done:
    mov [esp + 28], eax  ; Сохранение результата в стеке
    pop es
    popa
    ret

; Преобразование номера кластера в номер сектора
; Вход: eax - номер кластера
; Выход: eax - номер сектора
fat_cluster_to_sector:
    ; Проверка валидности номера кластера
    cmp eax, 2
    jb .invalid_cluster
    
    cmp eax, 0xFFFFFFF8
    jae .invalid_cluster
    
    ; Преобразование номера кластера в номер сектора
    sub eax, 2      ; Кластеры начинаются с 2
    movzx ebx, byte [sectors_per_cluster]
    mul ebx
    add eax, [data_start]
    
    jmp .done
    
.invalid_cluster:
    xor eax, eax    ; Возврат 0 для невалидного кластера
    
.done:
    ret

section .data
    ; Эти переменные должны быть инициализированы из fs.asm
    extern bytes_per_sector
    extern sectors_per_cluster
    extern fat_start
    extern data_start
    extern sectors_per_fat
    
    fat_initialized dd 0   ; Флаг инициализации FAT

section .bss
    ; Здесь могут быть неинициализированные данные, если потребуется