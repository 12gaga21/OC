; Работа с директориями для ОС
bits 32

section .text
    global dir_init
    global dir_read
    global dir_find_entry
    global dir_change
    extern printf

; Инициализация работы с директориями
dir_init:
    pusha
    
    ; Инициализация переменных
    mov dword [current_dir_cluster], 0  ; Корневая директория по умолчанию
    mov dword [dir_initialized], 1
    
    popa
    ret

; Чтение содержимого директории
; Вход: eax - номер кластера директории (0 для корневой директории)
;       edi - адрес буфера для чтения данных
; Выход: ecx - количество прочитанных байт
dir_read:
    pusha
    push es
    
    ; Сохранение адреса буфера
    mov [read_buffer], edi
    
    ; Проверка, является ли это корневой директорией
    test eax, eax
    jz .read_root_dir
    
    ; Чтение подкаталога
    ; Преобразование номера кластера в номер сектора
    push eax
    call fat_cluster_to_sector
    pop eax
    
    ; Чтение секторов директории
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
    mov [bytes_read], eax
    
    jmp .done
    
.read_root_dir:
    ; Чтение корневой директории
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
    mov bx, [read_buffer]  ; Смещение в сегменте ES
    int 0x13        ; Вызов BIOS
    
    ; Добавление количества прочитанных байт
    movzx eax, word [root_entries]
    mov ebx, 32  ; Размер записи в корневой директории
    mul ebx
    mov [bytes_read], eax
    
.done:
    mov ecx, [bytes_read]  ; Возврат количества прочитанных байт
    pop es
    popa
    ret

; Поиск записи в директории
; Вход: esi - адрес имени файла/директории (8.3 формат, 11 байт)
;       edi - адрес буфера с содержимым директории
;       ecx - количество записей в директории
; Выход: eax - номер кластера (0 если не найден)
dir_find_entry:
    pusha
    
    ; Поиск записи в директории
    mov ebx, 0     ; Индекс записи
    
.find_loop:
    ; Проверка, достигнут ли конец директории
    test ecx, ecx
    jz .not_found
    
    ; Проверка, является ли запись пустой
    mov al, [edi]
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
    
    ; Запись найдена, извлечение номера кластера
    movzx eax, word [edi + 26]  ; Младшее слово номера кластера
    movzx ebx, word [edi + 20]  ; Старшее слово номера кластера (для FAT32)
    ; Для FAT16 старшее слово игнорируется
    jmp .found
    
.next_entry:
    add edi, 32     ; Переход к следующей записи (32 байта на запись)
    dec ecx
    jmp .find_loop
    
.not_found:
    xor eax, eax    ; Возврат 0 если запись не найдена
    jmp .done
    
.found:
    ; eax уже содержит номер кластера
    
.done:
    mov [esp + 28], eax  ; Сохранение результата в стеке
    popa
    ret

; Смена текущей директории
; Вход: eax - номер кластера новой директории
dir_change:
    ; Проверка валидности номера кластера
    test eax, eax
    jz .set_root    ; 0 означает корневую директорию
    
    cmp eax, 0xFFFFFFF8
    jae .invalid_cluster
    
    ; Установка новой текущей директории
    mov [current_dir_cluster], eax
    ret
    
.set_root:
    mov dword [current_dir_cluster], 0
    ret
    
.invalid_cluster:
    ; Неверный номер кластера, оставляем текущую директорию
    ret

section .data
    ; Эти переменные должны быть инициализированы из fs.asm
    extern bytes_per_sector
    extern sectors_per_cluster
    extern root_entries
    extern root_dir_start
    extern fat_cluster_to_sector
    
    dir_initialized dd 0           ; Флаг инициализации работы с директориями
    current_dir_cluster dd 0       ; Номер кластера текущей директории
    bytes_read dd 0                ; Количество прочитанных байт
    read_buffer dd 0               ; Адрес буфера для чтения

section .bss
    ; Здесь могут быть неинициализированные данные, если потребуется