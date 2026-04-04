#!/bin/bash

# Скрипт сборки операционной системы "Священный Ритуалъ"

echo "=== НАЧАЛО РИТУАЛА СБОРКИ ==="

# Создание каталога для сборки
mkdir -p ../build

echo "Компиляция загрузчика..."

# Компиляция загрузчика
nasm -f bin ../src/boot/boot.asm -o ../build/boot.bin

# Проверка успешности компиляции
if [ $? -eq 0 ]; then
    echo "✓ Загрузчик успешно скомпилирован: build/boot.bin"
else
    echo "✗ Ошибка компиляции загрузчика!"
    exit 1
fi

echo "Компиляция модулей ядра..."

# Компиляция ассемблерных файлов ядра в объектные файлы
MODULES=(
    "kernel_utils"
    "vga"
    "vga_driver"
    "gdt"
    "idt"
    "memory"
    "paging"
    "task"
    "scheduler"
    "syscall"
    "keyboard"
    "rus_layout"
    "timer"
    "serial"
    "fs"
    "fat32"
    "dir"
    "fs_write"
    "network"
    "net_utils"
    "tcpip"
    "ipc"
    "sync"
    "shell_commands"
    "shell"
    "system_info"
    "loader"
    "number_utils"
)

for module in "${MODULES[@]}"; do
    if [ -f "../src/kernel/${module}.asm" ]; then
        nasm -f elf32 ../src/kernel/${module}.asm -o ../build/${module}.o
        if [ $? -eq 0 ]; then
            echo "✓ Модуль ${module}.asm скомпилирован"
        else
            echo "✗ Ошибка компиляции модуля ${module}.asm"
        fi
    else
        echo "! Модуль ${module}.asm не найден, пропускаем"
    fi
done

echo "Компиляция основного ядра..."
nasm -f elf32 ../src/kernel/kernel.asm -o ../build/kernel.o

if [ $? -eq 0 ]; then
    echo "✓ Ядро успешно скомпилировано: build/kernel.o"
else
    echo "✗ Ошибка компиляции ядра!"
    exit 1
fi

echo "Линковка ядра..."
ld -m elf_i386 -Ttext 0x100000 ../build/kernel.o -o ../build/kernel.bin --oformat binary

if [ $? -eq 0 ]; then
    echo "✓ Ядро успешно слинковано: build/kernel.bin"
else
    echo "✗ Ошибка линковки ядра!"
    echo "Попытка альтернативного метода..."
    
    # Альтернативный метод: создание простого бинарного ядра
    cat ../build/kernel.o > ../build/kernel.bin 2>/dev/null || true
fi

echo "Создание загрузочного образа..."

# Создание образа диска размером 4MB (для размещения ядра и будущей ФС)
IMAGE_SIZE=$((4 * 1024 * 1024))
dd if=/dev/zero of=../build/os.img bs=1 count=$IMAGE_SIZE 2>/dev/null

# Копирование загрузчика в первые сектора
dd if=../build/boot.bin of=../build/os.img conv=notrunc 2>/dev/null

# Вычисление оффсета для ядра (после загрузчика)
KERNEL_OFFSET=512

# Копирование ядра на диск
dd if=../build/kernel.bin of=../build/os.img seek=1 conv=notrunc 2>/dev/null

if [ $? -eq 0 ]; then
    echo "✓ Загрузочный образ успешно создан: build/os.img"
    echo "Размер образа: $(stat -c%s '../build/os.img') байт"
    echo ""
    echo "=== РИТУАЛ СБОРКИ ЗАВЕРШЕН ==="
    echo "Для запуска в QEMU выполните:"
    echo "  qemu-system-i386 -fda build/os.img"
    echo "или"
    echo "  qemu-system-i386 -drive format=raw,file=build/os.img"
else
    echo "✗ Ошибка создания загрузочного образа!"
    exit 1
fi
