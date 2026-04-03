; Базовая файловая система FAT16/FAT32 для ОС
bits 32

section .text
    global fs_init
    global fs_read_root_dir
    global fs_find_file
    global fs_read_file
    extern printf
    extern fat32_detect_type
    extern fat32_init
    extern fat32_get_root_dir_cluster
    extern fat32_cluster_to_sector

; Инициализация файловой системы FAT16/FAT32
fs_init:
    pusha
    push es
    
    ; Установка сегмента ES на адрес буфера для чтения BPB
    mov ax, 0x1000  ; Сегмент для буфера BPB
    mov es, ax
    
    ; Чтение первого сектора (BPB) с диска
    ; Используем INT 13h для чтения сектора
    mov ah, 0x02    ; Функция чтения секторов
    mov al, 1       ; Количество секторов для чтения
    mov ch, 0       ; Номер дорожки
    mov cl, 1       ; Номер сектора (1-основанный)
    mov dh, 0       ; Номер головки
    mov dl, 0x80    ; Номер диска (0x80 - первый жесткий диск)
    mov bx, 0       ; Смещение в сегменте ES
    int 0x13        ; Вызов BIOS
    
    ; Проверка на ошибки
    jc .error
    
    ; Извлечение параметров из BPB
    ; Байты на сектор (смещение 11, 2 байта)
    mov ax, [es:0x0B]
    mov [bytes_per_sector], ax
    
    ; Секторов на кластер (смещение 13, 1 байт)
    mov al, [es:0x0D]
    mov [sectors_per_cluster], al
    
    ; Зарезервированных секторов (смещение 14, 2 байта)
    mov ax, [es:0x0E]
    mov [reserved_sectors], ax
    
    ; Количество таблиц FAT (смещение 16, 1 байт)
    mov al, [es:0x10]
    mov [num_fats], al
    
    ; Записей в корневой директории (смещение 17, 2 байта)
    mov ax, [es:0x11]
    mov [root_entries], ax
    
    ; Всего секторов (смещение 19, 2 байта)
    mov ax, [es:0x13]
    mov [total_sectors], ax
    
    ; Секторов на FAT (смещение 22, 2 байта)
    mov ax, [es:0x16]
    mov [sectors_per_fat], ax
    
    ; Определение типа FAT (FAT16/FAT32)
    mov eax, 0x1000  ; Адрес BPB в сегменте ES (смещение 0)
    call fat32_detect_type  ; al = тип FAT (1=FAT12, 2=FAT16, 3=FAT32, 0=неизвестно)
    mov [fat_type], al
    
    ; Если FAT32, вызываем инициализацию FAT32
    cmp al, 3
    jne .not_fat32
    
    ; Инициализация FAT32
    mov eax, 0x1000
    call fat32_init
    test eax, eax
    jz .not_fat32  ; Если инициализация не удалась, продолжаем как FAT16
    
    ; Для FAT32 корневая директория находится в области данных, а не в отдельном секторе
    ; Устанавливаем root_dir_start = 0 (будет использоваться кластер корневой директории)
    mov word [root_dir_start], 0
    jmp .skip_fat16_calc
    
.not_fat32:
    ; Номер сектора начала первой FAT
    mov ax, [reserved_sectors]
    mov [fat_start], ax
    
    ; Номер сектора начала корневой директории
    movzx eax, byte [num_fats]
    movzx ebx, word [sectors_per_fat]
    mul ebx
    add ax, [fat_start]
    mov [root_dir_start], ax
    
    ; Номер сектора начала области данных
    movzx eax, word [root_entries]
    mov ebx, 32  ; Размер записи в корневой директории
    mul ebx
    mov ebx, [bytes_per_sector]
    div ebx
    add ax, [root_dir_start]
    mov [data_start], ax
    
.skip_fat16_calc:
    pop es
    popa
    ret

.error:
    ; Обработка ошибки чтения BPB
    pop es
    popa
    stc  ; Установка флага переноса для указания ошибки
    ret

; Чтение корневой директории
fs_read_root_dir:
    pusha
    push es
    
    ; Проверка типа FAT
    mov al, [fat_type]
    cmp al, 3
    je .fat32_root
    
    ; FAT16: стандартное чтение корневой директории
    ; Установка сегмента ES на адрес буфера для корневой директории
    mov ax, 0x2000  ; Сегмент для буфера корневой директории
    mov es, ax
    
    ; Вычисление количества секторов для чтения корневой директории
    movzx eax, word [root_entries]
    mov ebx, 32  ; Размер записи в корневой директории
    mul ebx
    movzx ebx, word [bytes_per_sector]
    div ebx
    movzx ecx, ax  ; Количество секторов
    
    ; Чтение корневой директории
    mov ah, 0x02    ; Функция чтения секторов
    mov al, cl      ; Количество секторов для чтения
    mov ch, 0       ; Номер дорожки (временно 0)
    mov cl, [root_dir_start]  ; Номер сектора начала корневой директории
    mov dh, 0       ; Номер головки
    mov dl, 0x80    ; Номер диска
    mov bx, 0       ; Смещение в сегменте ES
    int 0x13        ; Вызов BIOS
    
    jmp .done
    
.fat32_root:
    ; FAT32: чтение корневой директории из области данных
    ; Установка сегмента ES на адрес буфера для корневой директории
    mov ax, 0x2000  ; Сегмент для буфера корневой директории
    mov es, ax
    
    ; Получение кластера корневой директории
    call fat32_get_root_dir_cluster  ; eax = номер кластера корневой директории
    test eax, eax
    jz .error_fat32  ; Если кластер = 0, ошибка
    
    ; Преобразование кластера в сектор
    call fat32_cluster_to_sector  ; eax = номер сектора
    test eax, eax
    jz .error_fat32
    
    ; Чтение одного кластера корневой директории (предполагаем, что достаточно)
    movzx ebx, byte [sectors_per_cluster]
    mov ecx, ebx  ; Количество секторов = sectors_per_cluster
    
    ; Чтение корневой директории
    mov ah, 0x02    ; Функция чтения секторов
    mov al, cl      ; Количество секторов для чтения
    mov ch, 0       ; Номер дорожки (временно 0)
    mov cl, al      ; Номер сектора (младший байт)
    mov dh, 0       ; Номер головки
    mov dl, 0x80    ; Номер диска
    mov bx, 0       ; Смещение в сегменте ES
    int 0x13        ; Вызов BIOS
    
    jc .error_fat32  ; Если ошибка чтения
    
    jmp .done
    
.error_fat32:
    ; Ошибка чтения корневой директории FAT32
    stc
    jmp .done_cleanup
    
.done:
    clc  ; Успех
    
.done_cleanup:
    pop es
    popa
    ret

; Поиск файла в корневой директории
; Вход: esi - адрес имени файла (8.3 формат, 11 байт)
; Выход: eax - кластер файла (0 если не найден)
fs_find_file:
    pusha
    push es
    
    ; Установка сегмента ES на адрес буфера корневой директории
    mov ax, 0x2000  ; Сегмент для буфера корневой директории
    mov es, ax
    
    ; Поиск файла в корневой директории
    movzx ecx, word [root_entries]
    mov edi, 0      ; Индекс в буфере корневой директории
    
.find_loop:
    ; Проверка, достигнут ли конец корневой директории
    test ecx, ecx
    jz .not_found
    
    ; Проверка, является ли запись файлом (не удаленной)
    mov al, [es:edi]
    test al, al
    jz .next_entry  ; Пустая запись
    
    cmp al, 0xE5
    je .next_entry  ; Удаленная запись
    
    ; Сравнение имени файла
    push ecx
    push edi
    mov ecx, 11     ; Длина имени файла в формате 8.3
    repe cmpsb
    pop edi
    pop ecx
    
    jne .next_entry  ; Имена не совпадают
    
    ; Файл найден, извлечение номера кластера
    movzx eax, word [es:edi + 26]  ; Младшее слово номера кластера
    movzx ebx, word [es:edi + 20]  ; Старшее слово номера кластера (для FAT32)
    ; Для FAT16 старшее слово игнорируется
    jmp .found
    
.next_entry:
    add edi, 32     ; Переход к следующей записи (32 байта на запись)
    dec ecx
    jmp .find_loop
    
.not_found:
    xor eax, eax    ; Возврат 0 если файл не найден
    jmp .done
    
.found:
    ; eax уже содержит номер кластера
    
.done:
    mov [esp + 28], eax  ; Сохранение результата в стеке
    pop es
    popa
    ret

; Чтение содержимого файла
; Вход: eax - номер первого кластера файла
;       edi - адрес буфера для чтения данных
; Выход: ecx - количество прочитанных байт
fs_read_file:
    pusha
    push es
    
    ; Сохранение адреса буфера
    mov [read_buffer], edi
    
    ; Инициализация количества прочитанных байт
    xor ecx, ecx
    mov [bytes_read], ecx
    
.read_cluster:
    ; Проверка, является ли кластер последним
    test eax, 0xFFFFFFF8
    jnz .valid_cluster
    
    ; Неверный номер кластера
    pop es
    popa
    ret
    
.valid_cluster:
    ; Преобразование номера кластера в номер сектора
    sub eax, 2      ; Кластеры начинаются с 2
    movzx ebx, byte [sectors_per_cluster]
    mul ebx
    add eax, [data_start]
    
    ; Чтение секторов кластера
    mov ah, 0x02    ; Функция чтения секторов
    mov al, [sectors_per_cluster]  ; Количество секторов для чтения
    mov ch, 0       ; Номер дорожки (временно 0)
    mov cl, al      ; Номер сектора
    mov dh, 0       ; Номер головки
    mov dl, 0x80    ; Номер диска
    mov bx, [read_buffer]  ; Смещение в сегменте ES
    int 0x13        ; Вызов BIOS
    
    ; Добавление количества прочитанных байт
    movzx ebx, byte [sectors_per_cluster]
    movzx eax, word [bytes_per_sector]
    mul ebx
    add [bytes_read], eax
    
    ; Получение номера следующего кластера из FAT
    ; (временно возвращаемся к первому кластеру)
    mov eax, [esp + 32]  ; Номер первого кластера из стека
    
    ; Для упрощения, предполагаем, что файл состоит из одного кластера
    jmp .done
    
.done:
    mov ecx, [bytes_read]  ; Возврат количества прочитанных байт
    pop es
    popa
    ret

section .data
    bytes_per_sector dw 0      ; Байт на сектор
    sectors_per_cluster db 0   ; Секторов на кластер
    reserved_sectors dw 0      ; Зарезервированных секторов
    num_fats db 0              ; Количество таблиц FAT
    root_entries dw 0          ; Записей в корневой директории
    total_sectors dw 0         ; Всего секторов
    sectors_per_fat dw 0        ; Секторов на FAT
    fat_start dw 0            ; Начало FAT
    root_dir_start dw 0        ; Начало корневой директории
    data_start dw 0            ; Начало области данных
    bytes_read dd 0            ; Количество прочитанных байт
    read_buffer dd 0          ; Адрес буфера для чтения
    fat_type db 0             ; Тип FAT: 0=неизвестно, 1=FAT12, 2=FAT16, 3=FAT32

section .bss
    ; Здесь могут быть неинициализированные данные, если потребуется