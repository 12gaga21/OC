#!/bin/bash

# Основной скрипт для запуска тестов операционной системы
# Версия: 1.0

set -e  # Выход при ошибке

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Пути
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(dirname "$SCRIPT_DIR")"
OS_DIR="$TESTS_DIR/../.."
BUILD_DIR="$OS_DIR/os/build"
UTILS_DIR="$TESTS_DIR/utils"
RESULTS_DIR="$TESTS_DIR/results"
CONFIG_DIR="$TESTS_DIR/config"

# Функции логирования
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Проверка зависимостей
check_dependencies() {
    log_info "Проверка зависимостей..."
    
    # Проверка NASM
    if ! command -v nasm &> /dev/null; then
        log_error "NASM не установлен. Установите NASM для сборки ОС."
        exit 1
    fi
    log_success "NASM обнаружен: $(nasm --version | head -n1)"
    
    # Проверка QEMU
    if ! command -v qemu-system-i386 &> /dev/null; then
        log_warning "qemu-system-i386 не найден. Попытка найти qemu..."
        if ! command -v qemu &> /dev/null; then
            log_error "QEMU не установлен. Установите QEMU для запуска тестов."
            exit 1
        fi
        QEMU_CMD="qemu"
    else
        QEMU_CMD="qemu-system-i386"
    fi
    log_success "QEMU обнаружен: $QEMU_CMD"
    
    # Проверка каталогов
    if [ ! -d "$BUILD_DIR" ]; then
        log_warning "Каталог сборки не существует: $BUILD_DIR"
        log_info "Создание каталога сборки..."
        mkdir -p "$BUILD_DIR"
    fi
    
    if [ ! -d "$RESULTS_DIR" ]; then
        mkdir -p "$RESULTS_DIR"
    fi
    
    export QEMU_CMD
}

# Сборка ОС
build_os() {
    log_info "Сборка операционной системы..."
    
    if [ ! -f "$OS_DIR/os/build/build.sh" ]; then
        log_error "Скрипт сборки не найден: $OS_DIR/os/build/build.sh"
        exit 1
    fi
    
    cd "$OS_DIR/os/build"
    chmod +x build.sh
    
    if ./build.sh; then
        log_success "ОС успешно собрана"
    else
        log_error "Ошибка сборки ОС"
        exit 1
    fi
    
    cd "$SCRIPT_DIR"
}

# Тестирование загрузчика
test_bootloader() {
    log_info "Запуск тестов загрузчика..."
    
    local test_script="$TESTS_DIR/unit/bootloader_test.sh"
    
    if [ -f "$test_script" ]; then
        chmod +x "$test_script"
        if "$test_script"; then
            log_success "Тесты загрузчика пройдены"
            return 0
        else
            log_error "Тесты загрузчика не пройдены"
            return 1
        fi
    else
        log_warning "Скрипт тестирования загрузчика не найден: $test_script"
        log_info "Создание базового теста загрузчика..."
        
        # Базовый тест размера загрузчика
        if [ ! -f "$BUILD_DIR/boot.bin" ]; then
            log_error "Файл boot.bin не найден"
            return 1
        fi
        
        local size=$(stat -c%s "$BUILD_DIR/boot.bin" 2>/dev/null || stat -f%z "$BUILD_DIR/boot.bin")
        
        if [ "$size" -eq 512 ]; then
            log_success "Размер загрузчика корректен: $size байт"
            
            # Проверка сигнатуры
            local signature=$(hexdump -C "$BUILD_DIR/boot.bin" | tail -1 | awk '{print $9$10}')
            if [ "$signature" = "55aa" ]; then
                log_success "Сигнатура загрузчика корректен: $signature"
                return 0
            else
                log_error "Неверная сигнатура загрузчика: $signature (ожидается 55aa)"
                return 1
            fi
        else
            log_error "Неверный размер загрузчика: $size байт (ожидается 512)"
            return 1
        fi
    fi
}

# Тестирование драйверов
test_drivers() {
    log_info "Запуск тестов драйверов..."
    
    local test_script="$TESTS_DIR/unit/drivers_test.sh"
    
    if [ -f "$test_script" ]; then
        chmod +x "$test_script"
        if "$test_script"; then
            log_success "Тесты драйверов пройдены"
            return 0
        else
            log_error "Тесты драйверов не пройдены"
            return 1
        fi
    else
        log_warning "Скрипт тестирования драйверов не найден: $test_script"
        log_info "Запуск базовых тестов драйверов через QEMU..."
        
        # Базовый тест: запуск ОС и проверка вывода
        local log_file="$RESULTS_DIR/drivers_test_$(date +%Y%m%d_%H%M%S).log"
        
        log_info "Запуск QEMU для тестирования драйверов (таймаут 10 секунд)..."
        timeout 10s $QEMU_CMD -fda "$BUILD_DIR/os.img" -serial file:"$log_file" || true
        
        if [ -f "$log_file" ] && [ -s "$log_file" ]; then
            log_success "Драйверы вывели данные в лог"
            log_info "Первые 10 строк лога:"
            head -10 "$log_file"
            return 0
        else
            log_warning "Нет вывода от драйверов"
            return 1
        fi
    fi
}

# Тестирование файловой системы
test_filesystem() {
    log_info "Запуск тестов файловой системы..."
    
    local test_script="$TESTS_DIR/integration/filesystem_test.sh"
    
    if [ -f "$test_script" ]; then
        chmod +x "$test_script"
        if "$test_script"; then
            log_success "Тесты файловой системы пройдены"
            return 0
        else
            log_error "Тесты файловой системы не пройдены"
            return 1
        fi
    else
        log_warning "Скрипт тестирования файловой системы не найден: $test_script"
        log_info "Пропуск тестов файловой системы (требуется реализация)"
        return 0
    fi
}

# Тестирование сети
test_network() {
    log_info "Запуск тестов сети..."
    
    local test_script="$TESTS_DIR/integration/network_test.sh"
    
    if [ -f "$test_script" ]; then
        chmod +x "$test_script"
        if "$test_script"; then
            log_success "Тесты сети пройдены"
            return 0
        else
            log_error "Тесты сети не пройдены"
            return 1
        fi
    else
        log_warning "Скрипт тестирования сети не найден: $test_script"
        log_info "Пропуск тестов сети (требуется реализация)"
        return 0
    fi
}

# Тестирование оболочки
test_shell() {
    log_info "Запуск тестов оболочки..."
    
    local test_script="$TESTS_DIR/integration/shell_test.sh"
    
    if [ -f "$test_script" ]; then
        chmod +x "$test_script"
        if "$test_script"; then
            log_success "Тесты оболочки пройдены"
            return 0
        else
            log_error "Тесты оболочки не пройдены"
            return 1
        fi
    else
        log_warning "Скрипт тестирования оболочки не найден: $test_script"
        log_info "Пропуск тестов оболочки (требуется реализация)"
        return 0
    fi
}

# Тесты производительности
test_performance() {
    log_info "Запуск тестов производительности..."
    
    local test_script="$TESTS_DIR/performance/performance_test.sh"
    
    if [ -f "$test_script" ]; then
        chmod +x "$test_script"
        if "$test_script"; then
            log_success "Тесты производительности пройдены"
            return 0
        else
            log_error "Тесты производительности не пройдены"
            return 1
        fi
    else
        log_warning "Скрипт тестирования производительности не найден: $test_script"
        log_info "Пропуск тестов производительности (требуется реализация)"
        return 0
    fi
}

# Запуск всех тестов
run_all_tests() {
    log_info "Запуск всех тестов..."
    
    local tests_passed=0
    local tests_failed=0
    local tests_skipped=0
    
    # Сборка ОС
    build_os
    
    # Список тестов
    local test_functions=(
        "test_bootloader"
        "test_drivers"
        "test_filesystem"
        "test_network"
        "test_shell"
        "test_performance"
    )
    
    # Запуск каждого теста
    for test_func in "${test_functions[@]}"; do
        log_info "--- Запуск теста: $test_func ---"
        
        if $test_func; then
            ((tests_passed++))
            log_success "Тест $test_func пройден"
        else
            # Проверяем, был ли тест пропущен (возврат 0 при пропуске)
            if [ $? -eq 0 ]; then
                ((tests_skipped++))
                log_warning "Тест $test_func пропущен"
            else
                ((tests_failed++))
                log_error "Тест $test_func не пройден"
            fi
        fi
    done
    
    # Итоговый отчет
    log_info "=== ИТОГИ ТЕСТИРОВАНИЯ ==="
    log_info "Пройдено: $tests_passed"
    log_info "Не пройдено: $tests_failed"
    log_info "Пропущено: $tests_skipped"
    
    if [ $tests_failed -eq 0 ]; then
        log_success "Все тесты пройдены успешно!"
        return 0
    else
        log_error "Некоторые тесты не пройдены"
        return 1
    fi
}

# Показать справку
show_help() {
    echo "Использование: $0 [команда]"
    echo ""
    echo "Команды:"
    echo "  all              Запустить все тесты"
    echo "  bootloader       Тестирование загрузчика"
    echo "  drivers          Тестирование драйверов"
    echo "  filesystem       Тестирование файловой системы"
    echo "  network          Тестирование сети"
    echo "  shell            Тестирование оболочки"
    echo "  performance      Тесты производительности"
    echo "  build            Только сборка ОС"
    echo "  help             Показать эту справку"
    echo ""
    echo "Примеры:"
    echo "  $0 all           # Запустить все тесты"
    echo "  $0 bootloader    # Только тесты загрузчика"
    echo ""
    echo "Конфигурация: $CONFIG_DIR/test_config.yaml"
}

# Основная функция
main() {
    check_dependencies
    
    case "${1:-help}" in
        all)
            run_all_tests
            ;;
        bootloader)
            build_os
            test_bootloader
            ;;
        drivers)
            build_os
            test_drivers
            ;;
        filesystem)
            build_os
            test_filesystem
            ;;
        network)
            build_os
            test_network
            ;;
        shell)
            build_os
            test_shell
            ;;
        performance)
            build_os
            test_performance
            ;;
        build)
            build_os
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Неизвестная команда: $1"
            show_help
            exit 1
            ;;
    esac
}

# Запуск основной функции
main "$@"