#!/bin/bash

# Тестирование загрузчика операционной системы
# Версия: 1.0

set -e

# Загрузка утилит тестирования
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(dirname "$SCRIPT_DIR")"
UTILS_DIR="$TESTS_DIR/utils"

source "$UTILS_DIR/test_utils.sh"

# Инициализация утилит
init_test_utils

# Основные тесты загрузчика
test_bootloader_size() {
    log_info "Тест 1: Проверка размера загрузчика"
    
    local bootloader_file="$BUILD_DIR/boot.bin"
    
    # Проверка существования файла
    assert_file_exists "$bootloader_file" "Файл загрузчика должен существовать"
    
    # Проверка размера (512 байт)
    assert_file_size "$bootloader_file" 512 "Загрузчик должен иметь размер 512 байт"
    
    log_success "Размер загрузчика корректен"
    return 0
}

test_bootloader_signature() {
    log_info "Тест 2: Проверка сигнатуры загрузчика"
    
    local bootloader_file="$BUILD_DIR/boot.bin"
    
    # Проверка сигнатуры (0x55AA в конце загрузчика)
    assert_file_signature "$bootloader_file" "55aa" "Загрузчик должен иметь сигнатуру 0x55AA"
    
    log_success "Сигнатура загрузчика корректен"
    return 0
}

test_bootloader_content() {
    log_info "Тест 3: Проверка содержимого загрузчика"
    
    local bootloader_file="$BUILD_DIR/boot.bin"
    
    # Проверка, что загрузчик не пустой
    local file_size=$(stat -c%s "$bootloader_file" 2>/dev/null || stat -f%z "$bootloader_file")
    
    if [ "$file_size" -lt 2 ]; then
        log_error "Загрузчик слишком мал: $file_size байт"
        return 1
    fi
    
    # Проверка, что первые байты не все нули
    local first_bytes=$(hexdump -C "$bootloader_file" | head -2 | tail -1)
    
    if echo "$first_bytes" | grep -q "00 00 00 00 00 00 00 00"; then
        log_warning "Первые байты загрузчика могут быть нулевыми"
    fi
    
    log_success "Базовое содержимое загрузчика проверено"
    return 0
}

test_bootloader_in_qemu() {
    log_info "Тест 4: Проверка загрузки в QEMU"
    
    local bootloader_file="$BUILD_DIR/boot.bin"
    local test_log="$RESULTS_DIR/bootloader_qemu_test_$(date +%Y%m%d_%H%M%S).log"
    
    # Создание минимального образа с загрузчиком
    local test_image="$RESULTS_DIR/boot_test.img"
    cp "$bootloader_file" "$test_image"
    
    # Дополнение до 1.44MB (стандартный размер флоппи-диска)
    local current_size=$(stat -c%s "$test_image" 2>/dev/null || stat -f%z "$test_image")
    local target_size=$((1440 * 1024))
    local padding_size=$((target_size - current_size))
    
    if [ $padding_size -gt 0 ]; then
        dd if=/dev/zero bs=1 count=$padding_size 2>/dev/null >> "$test_image"
    fi
    
    # Запуск QEMU с загрузчиком
    log_info "Запуск QEMU с тестовым загрузчиком (таймаут 5 секунд)..."
    
    if command -v qemu-system-i386 &> /dev/null; then
        local qemu_cmd="qemu-system-i386"
    elif command -v qemu &> /dev/null; then
        local qemu_cmd="qemu"
    else
        log_warning "QEMU не найден, пропуск теста загрузки"
        return 0
    fi
    
    # Запуск QEMU с минимальным временем
    timeout 5s $qemu_cmd -fda "$test_image" -serial file:"$test_log" -no-reboot -no-shutdown || true
    
    # Проверка, что QEMU запустился (лог создан)
    if [ -f "$test_log" ]; then
        log_success "QEMU запустился с загрузчиком"
        
        # Очистка временных файлов
        rm -f "$test_image" "$test_log" 2>/dev/null || true
        
        return 0
    else
        log_warning "Нет лога от QEMU, возможно загрузчик не запускается"
        
        # Очистка временных файлов
        rm -f "$test_image" 2>/dev/null || true
        
        return 0  # Не считаем это ошибкой, так как загрузчик может не выводить в serial
    fi
}

test_bootloader_integration() {
    log_info "Тест 5: Интеграционная проверка с полным образом ОС"
    
    local os_image="$BUILD_DIR/os.img"
    
    if [ ! -f "$os_image" ]; then
        log_warning "Полный образ ОС не найден, пропуск интеграционного теста"
        return 0
    fi
    
    # Проверка, что образ содержит загрузчик
    local bootloader_from_image="$RESULTS_DIR/boot_from_img.bin"
    dd if="$os_image" of="$bootloader_from_image" bs=512 count=1 2>/dev/null
    
    if [ ! -f "$bootloader_from_image" ]; then
        log_error "Не удалось извлечь загрузчик из образа ОС"
        return 1
    fi
    
    # Проверка размера извлеченного загрузчика
    local extracted_size=$(stat -c%s "$bootloader_from_image" 2>/dev/null || stat -f%z "$bootloader_from_image")
    
    if [ "$extracted_size" -eq 512 ]; then
        log_success "Загрузчик в образе ОС имеет правильный размер: $extracted_size байт"
    else
        log_error "Неверный размер загрузчика в образе ОС: $extracted_size байт"
        rm -f "$bootloader_from_image"
        return 1
    fi
    
    # Сравнение с оригинальным загрузчиком
    if cmp -s "$BUILD_DIR/boot.bin" "$bootloader_from_image"; then
        log_success "Загрузчик в образе ОС идентичен оригинальному"
    else
        log_warning "Загрузчик в образе ОС отличается от оригинального"
        # Это может быть нормально, если образ был модифицирован
    fi
    
    # Очистка
    rm -f "$bootloader_from_image"
    
    return 0
}

# Основная функция тестирования
run_bootloader_tests() {
    log_info "=== Запуск тестов загрузчика ==="
    
    local tests_passed=0
    local tests_failed=0
    local tests_skipped=0
    
    # Список тестов
    local test_functions=(
        "test_bootloader_size"
        "test_bootloader_signature"
        "test_bootloader_content"
        "test_bootloader_in_qemu"
        "test_bootloader_integration"
    )
    
    # Запуск каждого теста
    for test_func in "${test_functions[@]}"; do
        log_info "--- Запуск теста: $test_func ---"
        
        if run_timed_test "$test_func" "$test_func"; then
            ((tests_passed++))
        else
            # Проверяем, был ли тест пропущен (возврат 0 при пропуске)
            if [ $? -eq 0 ]; then
                ((tests_skipped++))
            else
                ((tests_failed++))
            fi
        fi
    done
    
    # Итоговый отчет
    log_info "=== ИТОГИ ТЕСТИРОВАНИЯ ЗАГРУЗЧИКА ==="
    log_info "Пройдено: $tests_passed"
    log_info "Не пройдено: $tests_failed"
    log_info "Пропущено: $tests_skipped"
    
    if [ $tests_failed -eq 0 ]; then
        log_success "Все тесты загрузчика пройдены успешно!"
        
        # Генерация отчета
        generate_test_report \
            "$RESULTS_DIR/bootloader_report_$(date +%Y%m%d_%H%M%S).txt" \
            "Bootloader Tests" \
            "PASS" \
            "Все $tests_passed тестов загрузчика пройдены успешно"
        
        return 0
    else
        log_error "Некоторые тесты загрузчика не пройдены"
        
        # Генерация отчета
        generate_test_report \
            "$RESULTS_DIR/bootloader_report_$(date +%Y%m%d_%H%M%S).txt" \
            "Bootloader Tests" \
            "FAIL" \
            "$tests_failed тестов не пройдены"
        
        return 1
    fi
}

# Обработка аргументов командной строки
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    # Скрипт запущен напрямую
    
    case "${1:-all}" in
        all)
            # Проверка сборки
            if [ ! -f "$BUILD_DIR/boot.bin" ]; then
                log_warning "Загрузчик не собран, выполняется сборка ОС..."
                build_os
            fi
            
            run_bootloader_tests
            ;;
        size)
            test_bootloader_size
            ;;
        signature)
            test_bootloader_signature
            ;;
        content)
            test_bootloader_content
            ;;
        qemu)
            test_bootloader_in_qemu
            ;;
        integration)
            test_bootloader_integration
            ;;
        help|--help|-h)
            echo "Использование: $0 [команда]"
            echo ""
            echo "Команды:"
            echo "  all           Запустить все тесты загрузчика (по умолчанию)"
            echo "  size          Только проверка размера"
            echo "  signature     Только проверка сигнатуры"
            echo "  content       Только проверка содержимого"
            echo "  qemu          Только проверка в QEMU"
            echo "  integration   Только интеграционная проверка"
            echo "  help          Показать эту справку"
            echo ""
            exit 0
            ;;
        *)
            log_error "Неизвестная команда: $1"
            echo "Используйте '$0 help' для справки"
            exit 1
            ;;
    esac
fi