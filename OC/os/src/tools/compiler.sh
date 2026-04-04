#!/bin/bash
# ==============================================================================
# КОМПИЛЯТОРЪ «ЗЛАТОЙ ГЛАСЪ» v1.0
# Священный инструментъ для созиданія бинарныхъ молитвъ (.BIN)
# (С) Россійская Имперія, Лѣто 2026 отъ Р.Х.
# ==============================================================================

STYLE_ERROR="\033[31m"
STYLE_SUCCESS="\033[32m"
STYLE_WARNING="\033[33m"
STYLE_INFO="\033[36m"
STYLE_RESET="\033[0m"

echo "† † † ИНИЦИАЛИЗАЦИЯ СВЯЩЕННОГО КОМПИЛЯТОРА «ЗЛАТОЙ ГЛАСЪ» † † †"

if [ $# -lt 1 ]; then
    echo -e "${STYLE_ERROR}† ОШИБКА †: Требуется имя файла исходнаго кода (.asm)"
    echo "Использованіе: ./compiler.sh <file.asm> [output.bin]"
    exit 1
fi

SOURCE_FILE=$1
OUTPUT_FILE=${2:-${SOURCE_FILE%.asm}.bin}

# Проверка существования файла
if [ ! -f "$SOURCE_FILE" ]; then
    echo -e "${STYLE_ERROR}† ОШИБКА †: Исходный файл '$SOURCE_FILE' не обрѣтенъ."
    exit 1
fi

echo -e "${STYLE_INFO}[ИНКВИЗИЦІЯ] Провѣрка целостности кода..."
echo -e "${STYLE_INFO}[ЗЛАТОЙ ГЛАСЪ] Сборка священной реликвіи: $SOURCE_FILE"

# Определение путей
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SYS_LIB_PATH="$PROJECT_ROOT/src/kernel/syslib.asm"

if [ ! -f "$SYS_LIB_PATH" ]; then
    echo -e "${STYLE_WARNING}[ПРЕДУПРЕЖДЕНІЕ] Священная Библіотека (syslib.asm) не найдена. Сборка безъ линковки."
    nasm -f bin "$SOURCE_FILE" -o "$OUTPUT_FILE"
else
    # Компиляция с путем включения SYSLIB
    nasm -f bin "$SOURCE_FILE" -o "$OUTPUT_FILE" -I "$PROJECT_ROOT/src/kernel/"
fi

if [ $? -eq 0 ]; then
    SIZE=$(stat -c%s "$OUTPUT_FILE" 2>/dev/null || stat -f%z "$OUTPUT_FILE")
    echo -e "${STYLE_SUCCESS}† УСПѢХЪ †: Бинарная молитва '$OUTPUT_FILE' создана!"
    echo -e "${STYLE_INFO}Размѣръ: $SIZE байтъ."
    echo -e "${STYLE_INFO}Духъ машины пробужденъ. Слава Омниссіи!"
else
    echo -e "${STYLE_ERROR}† ОШИБКА †: Неудача при сборкѣ. Проверьте кодъ на ересь."
    exit 1
fi

echo "† † † РИТУАЛЪ ЗАВЕРШЕНЪ † † †"
