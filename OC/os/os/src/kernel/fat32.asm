; Модуль для работы с файловой системой FAT32
bits 32

section .text
    global fat32_init
    global fat32_get_next_cluster
    global fat32_cluster_to_sector
    global fat32_read_fat
    global fat32_get_root_dir_cluster
    global fat32_detect_type

; Константы FAT32
FAT32_SIGNATURE equ 0x0B  ; Смещение сигнатуры FAT32 в BPB
FAT32_MAGIC equ 0x29      ; Сигнатура FAT32

; Переменные FAT32
fat32_root_dir_cluster dd 0   ; Кластер корневой директории
fat32_fs_info_sector dd 0     ; Сектор FSInfo
fat32_backup_boot_sector dd 0 ; Резервный загрузочный сектор
fat32_type db 0               ; Тип FAT: 0 - неизвестно, 1 - FAT12, 2 - FAT16, 3 - FAT32

; Инициализация FAT32
; Вход: eax - адрес BPB (прочитанного сектора)
; Выход: eax - 1 если FAT32, 0 если нет
fat32_init:
    pusha
    push es
    
    ; Сохраняем адрес BPB
    mov esi, eax
    
    ; Проверяем сигнатуру FAT32
    mov al, [esi + FAT32_SIGNATURE]
    cmp al, FAT32_MAGIC
    jne .not_fat32
    
    ; Читаем важные параметры FAT32 из BPB
    ; Секторов на FAT (32-битное значение)
    mov eax, [esi + 36]        ; Смещение 36: sectors_per_fat32
    mov [fat32_sectors_per_fat], eax
    
    ; Флаги FAT32
    mov ax, [esi + 40]         ; Смещение 40: fat32_flags
    mov [fat32_flags], ax
    
    ; Версия FAT32
    mov ax, [esi + 42]         ; Смещение 42: fat32_version
    mov [fat32_version], ax
    
    ; Кластер корневой директории
    mov eax, [esi + 44]        ; Смещение 44: fat32_root_cluster
    mov [fat32_root_dir_cluster], eax
    
    ; Сектор FSInfo
    mov ax, [esi + 48]         ; Смещение 48: fat32_fs_info_sector
    mov [fat32_fs_info_sector], ax
    
    ; Резервный загрузочный сектор
    mov ax, [esi + 50]         ; Смещение 50: fat32_backup_boot_sector
    mov [fat32_backup_boot_sector], ax
    
    ; Устанавливаем тип FAT32
    mov byte [fat32_type], 3
    
    ; Вычисляем начало FAT (используем зарезервированные секторы)
    movzx eax, word [esi + 14] ; reserved_sectors
    mov [fat32_fat_start], eax
    
    ; Вычисляем начало области данных
    movzx ebx, byte [esi + 16] ; num_fats
    mov eax, [fat32_sectors_per_fat]
    mul ebx
    add eax, [fat32_fat_start]
    mov [fat32_data_start], eax
    
    ; Успешно определили FAT32
    mov eax, 1
    jmp .done
    
.not_fat32:
    xor eax, eax

.done:
    mov [esp + 28], eax  ; Сохраняем результат в стеке
    pop es
    popa
    ret

; Получение следующего кластера в цепочке FAT32
; Вход: eax - номер текущего кластера
; Выход: eax - номер следующего кластера (0xFFFFFFFF если последний)
fat32_get_next_cluster:
    pusha
    push es
    
    ; Установка сегмента ES на адрес буфера FAT
    mov ax, 0x3000  ; Сегмент для буфера FAT
    mov es, ax
    
    ; Вычисление смещения в FAT для текущего кластера
    ; Для FAT32 каждый элемент занимает 4 байта
    mov ebx, 4
    mul ebx
    mov ebx, [bytes_per_sector]
    div ebx
    movzx ecx, ax   ; Номер сектора относительно начала FAT
    mov edx, edx    ; Смещение внутри сектора
    
    ; Чтение сектора FAT, содержащего нужный элемент
    mov ah, 0x02    ; Функция чтения секторов
    mov al, 1       ; Количество секторов для чтения
    mov ch, 0       ; Номер дорожки (временно 0)
    mov cl, [fat32_fat_start]
    add cl, cl      ; Добавление смещения сектора
    mov dh, 0       ; Номер головки
    mov dl, 0x80    ; Номер диска
    mov bx, 0       ; Смещение в сегменте ES
    int 0x13        ; Вызов BIOS
    
    ; Получение значения следующего кластера (32 бита)
    mov eax, [es:edx]  ; Чтение 4-байтного значения
    
    ; Проверка на признак последнего кластера
    ; В FAT32: 0x0FFFFFF8 - 0x0FFFFFFF означают последний кластер
    and eax, 0x0FFFFFFF  ; Игнорируем старшие 4 бита
    cmp eax, 0x0FFFFFF8
    jae .last_cluster
    
    jmp .done
    
.last_cluster:
    mov eax, 0xFFFFFFFF  ; Признак последнего кластера
    
.done:
    mov [esp + 28], eax  ; Сохраняем результат в стеке
    pop es
    popa
    ret

; Преобразование номера кластера в номер сектора для FAT32
; Вход: eax - номер кластера
; Выход: eax - номер сектора
fat32_cluster_to_sector:
    ; Проверка валидности номера кластера
    cmp eax, 2
    jb .invalid_cluster
    
    cmp eax, 0x0FFFFFF6  ; Максимальный валидный кластер FAT32
    jae .invalid_cluster
    
    ; Преобразование номера кластера в номер сектора
    sub eax, 2      ; Кластеры начинаются с 2
    movzx ebx, byte [sectors_per_cluster]
    mul ebx
    add eax, [fat32_data_start]
    
    jmp .done
    
.invalid_cluster:
    xor eax, eax    ; Возврат 0 для невалидного кластера
    
.done:
    ret

; Чтение FAT таблицы в память (FAT32)
fat32_read_fat:
    pusha
    push es
    
    ; Установка сегмента ES на адрес буфера для FAT
    mov ax, 0x3000  ; Сегмент для буфера FAT
    mov es, ax
    
    ; Вычисление количества секторов для чтения FAT
    mov eax, [fat32_sectors_per_fat]
    movzx ecx, ax   ; Количество секторов
    
    ; Чтение FAT таблицы
    mov ah, 0x02    ; Функция чтения секторов
    mov al, cl      ; Количество секторов для чтения
    mov ch, 0       ; Номер дорожки (временно 0)
    mov cl, [fat32_fat_start]  ; Номер сектора начала FAT
    mov dh, 0       ; Номер головки
    mov dl, 0x80    ; Номер диска
    mov bx, 0       ; Смещение в сегменте ES
    int 0x13        ; Вызов BIOS
    
    pop es
    popa
    ret

; Получение кластера корневой директории FAT32
; Выход: eax - номер кластера корневой директории
fat32_get_root_dir_cluster:
    mov eax, [fat32_root_dir_cluster]
    ret

; Определение типа FAT (FAT12/FAT16/FAT32)
; Вход: eax - адрес BPB
; Выход: al - тип: 1=FAT12, 2=FAT16, 3=FAT32, 0=неизвестно
fat32_detect_type:
    push esi
    mov esi, eax
    
    ; Проверяем общее количество кластеров
    ; Для FAT32: total_sectors_32 > 0
    mov eax, [esi + 32]  ; total_sectors_32
    test eax, eax
    jnz .check_fat32
    
    ; Для FAT16/FAT12: используем total_sectors_16
    movzx eax, word [esi + 19]  ; total_sectors_16
    
    ; Вычисляем количество кластеров
    movzx ebx, byte [esi + 13]  ; sectors_per_cluster
    movzx ecx, word [esi + 17]  ; root_entries
    mov edx, 32
    mul edx
    mov edx, eax
    movzx eax, word [esi + 11]  ; bytes_per_sector
    div eax
    ; eax содержит количество секторов, занимаемых корневой директорией
    
    ; Пропускаем сложные вычисления, просто проверяем сигнатуру
    mov al, [esi + FAT32_SIGNATURE]
    cmp al, FAT32_MAGIC
    je .is_fat32
    
    ; Эвристика: если sectors_per_fat == 0, возможно FAT32
    movzx eax, word [esi + 22]  ; sectors_per_fat
    test eax, eax
    jz .is_fat32
    
    ; Для простоты считаем FAT16 (в реальной ОС нужна точная логика)
    mov al, 2
    jmp .done
    
.check_fat32:
    mov al, [esi + FAT32_SIGNATURE]
    cmp al, FAT32_MAGIC
    je .is_fat32
    
    ; Если total_sectors_32 > 0 и нет сигнатуры FAT32, всё равно считаем FAT32
    mov al, 3
    jmp .done
    
.is_fat32:
    mov al, 3
    
.done:
    pop esi
    ret

section .data
    ; Эти переменные должны быть инициализированы из fs.asm
    extern bytes_per_sector
    extern sectors_per_cluster
    extern sectors_per_fat
    
    ; Переменные FAT32
    fat32_sectors_per_fat dd 0
    fat32_flags dw 0
    fat32_version dw 0
    fat32_fat_start dd 0
    fat32_data_start dd 0

section .bss
    ; Дополнительные переменные могут быть здесь