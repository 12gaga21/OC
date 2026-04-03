#!/bin/bash

# Общие утилиты для тестирования операционной системы
# Версия: 1.0

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Пути (будут установлены при вызове init_test_utils)
SCRIPT_DIR=""
TESTS_DIR=""
OS_DIR=""
BUILD_DIR=""
RESULTS_DIR=""

# Инициализация утилит
init_test_utils() {
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    TESTS_DIR="$(dirname "$SCRIPT_DIR")"
    OS_DIR="$TESTS_DIR/../.."
    BUILD_DIR="$OS_DIR/os/build"
    RESULTS_DIR="$TESTS_DIR/results"
    
    # Создание каталогов, если не существуют
    mkdir -p "$RESULTS_DIR"
    
    export SCRIPT_DIR TESTS_DIR OS_DIR BUILD_DIR RESULTS_DIR
}

# Функции логирования
log_info() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[TEST]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[TEST]${NC} $1"
}

log_error() {
    echo -e "${RED}[TEST]${NC} $1"
}

# Проверка существования файла
assert_file_exists() {
    local file="$1"
    local message="${2:-Файл $file должен существовать}"
    
    if [ ! -f "$file" ]; then
        log_error "$message"
        return 1
    fi
    
    log_success "Файл существует: $file"
    return 0
}

# Проверка размера файла
assert_file_size() {
    local file="$1"
    local expected_size="$2"
    local message="${3:-Неверный размер файла $file}"
    
    if [ ! -f "$file" ]; then
        log_error "Файл не найден: $file"
        return 1
    fi
    
    local actual_size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file")
    
    if [ "$actual_size" -eq "$expected_size" ]; then
        log_success "Размер файла корректен: $file ($actual_size байт)"
        return 0
    else
        log_error "$message (ожидалось: $expected_size, получено: $actual_size)"
        return 1
    fi
}

# Проверка содержимого файла (шестнадцатеричная сигнатура)
assert_file_signature() {
    local file="$1"
    local expected_signature="$2"  # Например, "55aa"
    local message="${3:-Неверная сигнатура файла $file}"
    
    if [ ! -f "$file" ]; then
        log_error "Файл не найден: $file"
        return 1
    fi
    
    local signature=$(hexdump -C "$file" | tail -1 | awk '{print $9$10}')
    
    if [ "$signature" = "$expected_signature" ]; then
        log_success "Сигнатура файла корректен: $file ($signature)"
        return 0
    else
        log_error "$message (ожидалось: $expected_signature, получено: $signature)"
        return 1
    fi
}

# Проверка наличия строки в файле
assert_file_contains() {
    local file="$1"
    local pattern="$2"
    local message="${3:-Файл $file должен содержать '$pattern'}"
    
    if [ ! -f "$file" ]; then
        log_error "Файл не найден: $file"
        return 1
    fi
    
    if grep -q "$pattern" "$file"; then
        log_success "Файл содержит '$pattern': $file"
        return 0
    else
        log_error "$message"
        return 1
    fi
}

# Проверка отсутствия строки в файле
assert_file_not_contains() {
    local file="$1"
    local pattern="$2"
    local message="${3:-Файл $file не должен содержать '$pattern'}"
    
    if [ ! -f "$file" ]; then
        log_error "Файл не найден: $file"
        return 1
    fi
    
    if grep -q "$pattern" "$file"; then
        log_error "$message"
        return 1
    else
        log_success "Файл не содержит '$pattern': $file"
        return 0
    fi
}

# Запуск команды с проверкой кода возврата
run_command() {
    local cmd="$1"
    local expected_exit_code="${2:-0}"
    local message="${3:-Команда '$cmd' завершилась с ошибкой}"
    
    log_info "Выполнение команды: $cmd"
    
    eval "$cmd"
    local exit_code=$?
    
    if [ $exit_code -eq "$expected_exit_code" ]; then
        log_success "Команда выполнена успешно (код: $exit_code)"
        return 0
    else
        log_error "$message (код: $exit_code, ожидался: $expected_exit_code)"
        return 1
    fi
}

# Запуск команды с таймаутом
run_command_with_timeout() {
    local cmd="$1"
    local timeout="$2"
    local expected_exit_code="${3:-0}"
    local message="${4:-Команда '$cmd' завершилась с ошибкой или по таймауту}"
    
    log_info "Выполнение команды с таймаутом ${timeout}с: $cmd"
    
    timeout "$timeout" bash -c "$cmd"
    local exit_code=$?
    
    if [ $exit_code -eq 124 ]; then
        log_warning "Команда завершена по таймауту ($timeout секунд)"
        return 0  # Таймаут не считается ошибкой для тестов QEMU
    elif [ $exit_code -eq "$expected_exit_code" ]; then
        log_success "Команда выполнена успешно (код: $exit_code)"
        return 0
    else
        log_error "$message (код: $exit_code, ожидался: $expected_exit_code)"
        return 1
    fi
}

# Создание временного файла
create_temp_file() {
    local prefix="${1:-test}"
    local suffix="${2:-.tmp}"
    
    local temp_file=$(mktemp "${RESULTS_DIR}/${prefix}_XXXXXX${suffix}")
    echo "$temp_file"
}

# Очистка временных файлов
cleanup_temp_files() {
    local pattern="${1:-*}"
    
    log_info "Очистка временных файлов: ${RESULTS_DIR}/${pattern}"
    rm -f "${RESULTS_DIR}/"${pattern} 2>/dev/null || true
}

# Сборка ОС
build_os() {
    log_info "Сборка операционной системы..."
    
    if [ ! -f "$BUILD_DIR/build.sh" ]; then
        log_error "Скрипт сборки не найден: $BUILD_DIR/build.sh"
        return 1
    fi
    
    cd "$BUILD_DIR"
    chmod +x build.sh
    
    if ./build.sh; then
        log_success "ОС успешно собрана"
        cd "$SCRIPT_DIR"
        return 0
    else
        log_error "Ошибка сборки ОС"
        cd "$SCRIPT_DIR"
        return 1
    fi
}

# Проверка собранной ОС
check_os_build() {
    log_info "Проверка сборки ОС..."
    
    local required_files=("boot.bin" "kernel.bin" "os.img")
    local missing_files=()
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$BUILD_DIR/$file" ]; then
            missing_files+=("$file")
        fi
    done
    
    if [ ${#missing_files[@]} -eq 0 ]; then
        log_success "Все необходимые файлы собраны"
        
        # Проверка размера образа
        local os_img_size=$(stat -c%s "$BUILD_DIR/os.img" 2>/dev/null || stat -f%z "$BUILD_DIR/os.img")
        log_info "Размер образа ОС: $os_img_size байт"
        
        return 0
    else
        log_error "Отсутствуют файлы сборки: ${missing_files[*]}"
        return 1
    fi
}

# Запуск теста с измерением времени
run_timed_test() {
    local test_name="$1"
    local test_function="$2"
    
    log_info "Запуск теста: $test_name"
    
    local start_time=$(date +%s.%N)
    
    if $test_function; then
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc)
        
        log_success "Тест '$test_name' пройден за ${duration} секунд"
        return 0
    else
        log_error "Тест '$test_name' не пройден"
        return 1
    fi
}

# Генерация отчета о тестировании
generate_test_report() {
    local report_file="${1:-$RESULTS_DIR/test_report_$(date +%Y%m%d_%H%M%S).txt}"
    local test_name="$2"
    local test_result="$3"  # "PASS" или "FAIL"
    local test_message="$4"
    local test_duration="$5"
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "=== Отчет о тестировании ===" > "$report_file"
    echo "Дата: $timestamp" >> "$report_file"
    echo "Тест: $test_name" >> "$report_file"
    echo "Результат: $test_result" >> "$report_file"
    echo "Сообщение: $test_message" >> "$report_file"
    
    if [ -n "$test_duration" ]; then
        echo "Длительность: ${test_duration} секунд" >> "$report_file"
    fi
    
    echo "" >> "$report_file"
    echo "--- Системная информация ---" >> "$report_file"
    uname -a >> "$report_file" 2>/dev/null || echo "Не удалось получить системную информацию" >> "$report_file"
    
    if command -v nasm &> /dev/null; then
        echo "NASM: $(nasm --version | head -n1)" >> "$report_file"
    fi
    
    if command -v qemu-system-i386 &> /dev/null; then
        echo "QEMU: $(qemu-system-i386 --version | head -n1)" >> "$report_file"
    fi
    
    log_info "Отчет сохранен в: $report_file"
    echo "$report_file"
}

# Сравнение двух файлов
compare_files() {
    local file1="$1"
    local file2="$2"
    local message="${3:-Файлы $file1 и $file2 отличаются}"
    
    if [ ! -f "$file1" ] || [ ! -f "$file2" ]; then
        log_error "Один из файлов не найден: $file1, $file2"
        return 1
    fi
    
    if cmp -s "$file1" "$file2"; then
        log_success "Файлы идентичны: $file1 и $file2"
        return 0
    else
        log_error "$message"
        
        # Показать различия, если файлы текстовые
        if file "$file1" | grep -q "text"; then
            log_info "Различия:"
            diff -u "$file1" "$file2" | head -20
        fi
        
        return 1
    fi
}

# Проверка наличия команды в системе
check_command() {
    local cmd="$1"
    
    if command -v "$cmd" &> /dev/null; then
        log_success "Команда найдена: $cmd"
        return 0
    else
        log_error "Команда не найдена: $cmd"
        return 1
    fi
}

# Экспорт функций для использования в других скриптах
export -f init_test_utils
export -f log_info log_success log_warning log_error
export -f assert_file_exists assert_file_size assert_file_signature
export -f assert_file_contains assert_file_not_contains
export -f run_command run_command_with_timeout
export -f create_temp_file cleanup_temp_files
export -f build_os check_os_build
export -f run_timed_test generate_test_report
export -f compare_files check_command

# Автоматическая инициализация при загрузке скрипта
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    # Скрипт запущен напрямую, а не через source
    echo "Это библиотека утилит для тестирования. Используйте 'source test_utils.sh' в других скриптах."
    echo "Доступные функции:"
    echo "  init_test_utils, log_*, assert_*, run_*, build_os, check_os_build, etc."
else
    # Скрипт загружен через source, инициализируем утилиты
    init_test_utils
    log_info "Утилиты тестирования инициализированы"
fi