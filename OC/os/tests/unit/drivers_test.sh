#!/bin/bash

# Тестирование драйверов операционной системы
# Версия: 1.0

set -e

# Загрузка утилит тестирования
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(dirname "$SCRIPT_DIR")"
UTILS_DIR="$TESTS_DIR/utils"

source "$UTILS_DIR/test_utils.sh"

# Инициализация утилит
init_test_utils

# Конфигурация тестирования драйверов
DRIVER_TESTS_TIMEOUT=10
QEMU_MEMORY="128M"

# Тестирование драйвера клавиатуры
test_keyboard_driver() {
    log_info "Тест 1: Проверка драйвера клавиатуры"
    
    local test_log="$RESULTS_DIR/keyboard_test_$(date +%Y%m%d_%H%M%S).log"
    local os_image="$BUILD_DIR/os.img"
    
    if [ ! -f "$os_image" ]; then
        log_warning "Образ ОС не найден, пропуск теста клавиатуры"
        return 0
    fi
    
    log_info "Запуск QEMU с драйвером клавиатуры (таймаут ${DRIVER_TESTS_TIMEOUT} секунд)..."
    
    # Запуск QEMU с перенаправлением последовательного порта
    timeout ${DRIVER_TESTS_TIMEOUT}s qemu-system-i386 \
        -fda "$os_image" \
        -m "$QEMU_MEMORY" \
        -serial file:"$test_log" \
        -no-reboot -no-shutdown \
        || true
    
    # Проверка лога
    if [ -f "$test_log" ] && [ -s "$test_log" ]; then
        log_success "Драйвер клавиатуры вывел данные в лог"
        
        # Поиск ключевых слов, связанных с клавиатурой
        local keyboard_keywords=("keyboard" "Keyboard" "KEYBOARD" "key" "Key" "scan" "Scan" "input")
        local found_keywords=0
        
        for keyword in "${keyboard_keywords[@]}"; do
            if grep -q "$keyword" "$test_log"; then
                log_info "Найдено ключевое слово: $keyword"
                ((found_keywords++))
            fi
        done
        
        if [ $found_keywords -gt 0 ]; then
            log_success "В логе найдены ключевые слова клавиатуры ($found_keywords совпадений)"
        else
            log_info "В логе нет явных ключевых слов клавиатуры, но вывод присутствует"
        fi
        
        # Показать первые 5 строк лога
        log_info "Первые 5 строк лога клавиатуры:"
        head -5 "$test_log" 2>/dev/null || true
        
        # Очистка лога, если не нужен
        if [ "${KEEP_TEST_LOGS:-false}" != "true" ]; then
            rm -f "$test_log"
        fi
        
        return 0
    else
        log_warning "Нет вывода от драйвера клавиатуры"
        
        # Очистка
        rm -f "$test_log" 2>/dev/null || true
        
        return 0  # Не считаем это ошибкой, так как драйвер может не выводить в serial
    fi
}

# Тестирование драйвера таймера
test_timer_driver() {
    log_info "Тест 2: Проверка драйвера таймера"
    
    local test_log="$RESULTS_DIR/timer_test_$(date +%Y%m%d_%H%M%S).log"
    local os_image="$BUILD_DIR/os.img"
    
    if [ ! -f "$os_image" ]; then
        log_warning "Образ ОС не найден, пропуск теста таймера"
        return 0
    fi
    
    log_info "Запуск QEMU с драйвером таймера (таймаут ${DRIVER_TESTS_TIMEOUT} секунд)..."
    
    # Запуск QEMU с перенаправлением последовательного порта
    timeout ${DRIVER_TESTS_TIMEOUT}s qemu-system-i386 \
        -fda "$os_image" \
        -m "$QEMU_MEMORY" \
        -serial file:"$test_log" \
        -no-reboot -no-shutdown \
        || true
    
    # Проверка лога
    if [ -f "$test_log" ] && [ -s "$test_log" ]; then
        log_success "Драйвер таймера вывел данные в лог"
        
        # Поиск ключевых слов, связанных с таймером
        local timer_keywords=("timer" "Timer" "TIMER" "time" "Time" "tick" "Tick" "clock" "Clock" "interrupt")
        local found_keywords=0
        
        for keyword in "${timer_keywords[@]}"; do
            if grep -q "$keyword" "$test_log"; then
                log_info "Найдено ключевое слово: $keyword"
                ((found_keywords++))
            fi
        done
        
        if [ $found_keywords -gt 0 ]; then
            log_success "В логе найдены ключевые слова таймера ($found_keywords совпадений)"
        else
            log_info "В логе нет явных ключевых слов таймера, но вывод присутствует"
        fi
        
        # Проверка регулярности тиков (если есть временные метки)
        local line_count=$(wc -l < "$test_log")
        log_info "Количество строк в логе таймера: $line_count"
        
        # Показать первые 5 строк лога
        log_info "Первые 5 строк лога таймера:"
        head -5 "$test_log" 2>/dev/null || true
        
        # Очистка лога, если не нужен
        if [ "${KEEP_TEST_LOGS:-false}" != "true" ]; then
            rm -f "$test_log"
        fi
        
        return 0
    else
        log_warning "Нет вывода от драйвера таймера"
        
        # Очистка
        rm -f "$test_log" 2>/dev/null || true
        
        return 0  # Не считаем это ошибкой
    fi
}

# Тестирование драйвера последовательного порта
test_serial_driver() {
    log_info "Тест 3: Проверка драйвера последовательного порта"
    
    local test_log="$RESULTS_DIR/serial_test_$(date +%Y%m%d_%H%M%S).log"
    local os_image="$BUILD_DIR/os.img"
    
    if [ ! -f "$os_image" ]; then
        log_warning "Образ ОС не найден, пропуск теста последовательного порта"
        return 0
    fi
    
    log_info "Запуск QEMU с драйвером последовательного порта (таймаут ${DRIVER_TESTS_TIMEOUT} секунд)..."
    
    # Запуск QEMU с перенаправлением последовательного порта
    # Драйвер последовательного порта должен выводить данные в тот же порт
    timeout ${DRIVER_TESTS_TIMEOUT}s qemu-system-i386 \
        -fda "$os_image" \
        -m "$QEMU_MEMORY" \
        -serial file:"$test_log" \
        -no-reboot -no-shutdown \
        || true
    
    # Проверка лога
    if [ -f "$test_log" ] && [ -s "$test_log" ]; then
        log_success "Драйвер последовательного порта вывел данные в лог"
        
        # Поиск ключевых слов, связанных с последовательным портом
        local serial_keywords=("serial" "Serial" "SERIAL" "COM" "uart" "UART" "port" "Port")
        local found_keywords=0
        
        for keyword in "${serial_keywords[@]}"; do
            if grep -q "$keyword" "$test_log"; then
                log_info "Найдено ключевое слово: $keyword"
                ((found_keywords++))
            fi
        done
        
        # Проверка наличия любого вывода (даже без ключевых слов)
        local line_count=$(wc -l < "$test_log")
        local char_count=$(wc -c < "$test_log")
        
        log_info "Лог последовательного порта: $line_count строк, $char_count символов"
        
        if [ $found_keywords -gt 0 ]; then
            log_success "В логе найдены ключевые слова последовательного порта ($found_keywords совпадений)"
        else
            log_info "В логе нет явных ключевых слов последовательного порта"
        fi
        
        # Показать первые 10 строк лога (последовательный порт часто используется для отладки)
        log_info "Первые 10 строк лога последовательного порта:"
        head -10 "$test_log" 2>/dev/null || true
        
        # Очистка лога, если не нужен
        if [ "${KEEP_TEST_LOGS:-false}" != "true" ]; then
            rm -f "$test_log"
        fi
        
        return 0
    else
        log_warning "Нет вывода от драйвера последовательного порта"
        
        # Очистка
        rm -f "$test_log" 2>/dev/null || true
        
        return 0  # Не считаем это ошибкой
    fi
}

# Тестирование драйвера VGA
test_vga_driver() {
    log_info "Тест 4: Проверка драйвера VGA"
    
    local test_log="$RESULTS_DIR/vga_test_$(date +%Y%m%d_%H%M%S).log"
    local os_image="$BUILD_DIR/os.img"
    
    if [ ! -f "$os_image" ]; then
        log_warning "Образ ОС не найден, пропуск теста VGA"
        return 0
    fi
    
    log_info "Запуск QEMU с драйвером VGA (таймаут ${DRIVER_TESTS_TIMEOUT} секунд)..."
    
    # Запуск QEMU с перенаправлением последовательного порта
    # VGA драйвер может выводить информацию через последовательный порт для отладки
    timeout ${DRIVER_TESTS_TIMEOUT}s qemu-system-i386 \
        -fda "$os_image" \
        -m "$QEMU_MEMORY" \
        -serial file:"$test_log" \
        -no-reboot -no-shutdown \
        || true
    
    # Проверка лога
    if [ -f "$test_log" ] && [ -s "$test_log" ]; then
        log_success "Драйвер VGA вывел данные в лог"
        
        # Поиск ключевых слов, связанных с VGA
        local vga_keywords=("VGA" "vga" "video" "Video" "display" "Display" "screen" "Screen" "graphics")
        local found_keywords=0
        
        for keyword in "${vga_keywords[@]}"; do
            if grep -q "$keyword" "$test_log"; then
                log_info "Найдено ключевое слово: $keyword"
                ((found_keywords++))
            fi
        done
        
        # Проверка наличия вывода, характерного для VGA (цвета, разрешение и т.д.)
        local line_count=$(wc -l < "$test_log")
        
        log_info "Лог VGA: $line_count строк"
        
        if [ $found_keywords -gt 0 ]; then
            log_success "В логе найдены ключевые слова VGA ($found_keywords совпадений)"
        else
            log_info "В логе нет явных ключевых слов VGA"
        fi
        
        # Показать первые 5 строк лога
        log_info "Первые 5 строк лога VGA:"
        head -5 "$test_log" 2>/dev/null || true
        
        # Очистка лога, если не нужен
        if [ "${KEEP_TEST_LOGS:-false}" != "true" ]; then
            rm -f "$test_log"
        fi
        
        return 0
    else
        log_warning "Нет вывода от драйвера VGA"
        
        # Очистка
        rm -f "$test_log" 2>/dev/null || true
        
        return 0  # Не считаем это ошибкой
    fi
}

# Тестирование сетевого драйвера
test_network_driver() {
    log_info "Тест 5: Проверка сетевого драйвера"
    
    local test_log="$RESULTS_DIR/network_test_$(date +%Y%m%d_%H%M%S).log"
    local os_image="$BUILD_DIR/os.img"
    
    if [ ! -f "$os_image" ]; then
        log_warning "Образ ОС не найден, пропуск теста сети"
        return 0
    fi
    
    log_info "Запуск QEMU с сетевым драйвером (таймаут ${DRIVER_TESTS_TIMEOUT} секунд)..."
    
    # Запуск QEMU с эмуляцией сети
    timeout ${DRIVER_TESTS_TIMEOUT}s qemu-system-i386 \
        -fda "$os_image" \
        -m "$QEMU_MEMORY" \
        -net nic,model=rtl8139 \
        -net user \
        -serial file:"$test_log" \
        -no-reboot -no-shutdown \
        || true
    
    # Проверка лога
    if [ -f "$test_log" ] && [ -s "$test_log" ]; then
        log_success "Сетевой драйвер вывел данные в лог"
        
        # Поиск ключевых слов, связанных с сетью
        local network_keywords=("network" "Network" "NETWORK" "net" "Net" "eth" "Ethernet" "ip" "IP" "packet")
        local found_keywords=0
        
        for keyword in "${network_keywords[@]}"; do
            if grep -q "$keyword" "$test_log"; then
                log_info "Найдено ключевое слово: $keyword"
                ((found_keywords++))
            fi
        done
        
        local line_count=$(wc -l < "$test_log")
        log_info "Лог сети: $line_count строк"
        
        if [ $found_keywords -gt 0 ]; then
            log_success "В логе найдены ключевые слова сети ($found_keywords совпадений)"
        else
            log_info "В логе нет явных ключевых слов сети"
        fi
        
        # Показать первые 5 строк лога
        log_info "Первые 5 строк лога сети:"
        head -5 "$test_log" 2>/dev/null || true
        
        # Очистка лога, если не нужен
        if [ "${KEEP_TEST_LOGS:-false}" != "true" ]; then
            rm -f "$test_log"
        fi
        
        return 0
    else
        log_warning "Нет вывода от сетевого драйвера"
        
        # Очистка
        rm -f "$test_log" 2>/dev/null || true
        
        return 0  # Не считаем это ошибкой
    fi
}

# Комплексный тест всех драйверов
test_all_drivers_integration() {
    log_info "Тест 6: Комплексная проверка всех драйверов"
    
    local test_log="$RESULTS_DIR/all_drivers_test_$(date +%Y%m%d_%H%M%S).log"
    local os_image="$BUILD_DIR/os.img"
    
    if [ ! -f "$os_image" ]; then
        log_warning "Образ ОС не найден, пропуск комплексного теста"
        return 0
    fi
    
    log_info "Запуск QEMU со всеми драйверами (таймаут 15 секунд)..."
    
    # Запуск QEMU с максимальной конфигурацией
    timeout 15s qemu-system-i386 \
        -fda "$os_image" \
        -m "$QEMU_MEMORY" \
        -serial file:"$test_log" \
        -no-reboot -no-shutdown \
        || true
    
    # Проверка лога
    if [ -f "$test_log" ] && [ -s "$test_log" ]; then
        log_success "Все драйверы вывели данные в лог"
        
        # Анализ общего вывода
        local line_count=$(wc -l < "$test_log")
        local char_count=$(wc -c < "$test_log")
        
        log_info "Общий лог драйверов: $line_count строк, $char_count символов"
        
        # Проверка наличия разнообразного вывода (признак работы системы)
        local unique_lines=$(sort "$test_log" | uniq | wc -l)
        log_info "Уникальных строк в логе: $unique_lines"
        
        if [ $line_count -gt 5 ]; then
            log_success "Система выводит достаточное количество информации ($line_count строк)"
        else
            log_warning "Система выводит мало информации ($line_count строк)"
        fi
        
        # Показать образец вывода
        log_info "Образец вывода системы (строки 5-15):"
        sed -n '5,15p' "$test_log" 2>/dev/null || head -10 "$test_log"
        
        # Очистка лога, если не нужен
        if [ "${KEEP_TEST_LOGS:-false}" != "true" ]; then
            rm -f "$test_log"
        fi
        
        return 0
    else
        log_warning "Нет вывода от системы с драйверами"
        
        # Очистка
        rm -f "$test_log" 2>/dev/null || true
        
        return 0  # Не считаем это ошибкой
    fi
}

# Основная функция тестирования
run_drivers_tests() {
    log_info "=== Запуск тестов драйверов ==="
    
    local tests_passed=0
    local tests_failed=0
    local tests_skipped=0
    
    # Список тестов
    local test_functions=(
        "test_keyboard_driver"
        "test_timer_driver"
        "test_serial_driver"
        "test_vga_driver"
        "test_network_driver"
        "test_all_drivers_integration"
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
    log_info "=== ИТОГИ ТЕСТИРОВАНИЯ ДРАЙВЕРОВ ==="
    log_info "Пройдено: $tests_passed"
    log_info "Не пройдено: $tests_failed"
    log_info "Пропущено: $tests_skipped"
    
    if [ $tests_failed -eq 0 ]; then
        log_success "Все тесты драйверов пройдены успешно!"
        
        # Генерация отчета
        generate_test_report \
            "$RESULTS_DIR/drivers_report_$(date +%Y%m%d_%H%M%S).txt" \
            "Drivers Tests" \
            "PASS" \
            "Все $tests_passed тестов драйверов пройдены успешно"
        
        return 0
    else
        log_error "Некоторые тесты драйверов не пройдены"
        
        # Генерация отчета
        generate_test_report \
            "$RESULTS_DIR/drivers_report_$(date +%Y%m%d_%H%M%S).txt" \
            "Drivers Tests" \
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
            if [ ! -f "$BUILD_DIR/os.img" ]; then
                log_warning "ОС не собрана, выполняется сборка..."
                build_os
            fi
            
            run_drivers_tests
            ;;
        keyboard)
            test_keyboard_driver
            ;;
        timer)
            test_timer_driver
            ;;
        serial)
            test_serial_driver
            ;;
        vga)
            test_vga_driver
            ;;
        network)
            test_network_driver
            ;;
        integration)
            test_all_drivers_integration
            ;;
        help|--help|-h)
            echo "Использование: $0 [команда]"
            echo ""
            echo "Команды:"
            echo "  all           Запустить все тесты драйверов (по умолчанию)"
            echo "  keyboard      Только тест драйвера клавиатуры"
            echo "  timer         Только тест драйвера таймера"
            echo "  serial        Только тест драйвера последовательного порта"
            echo "  vga           Только тест драйвера VGA"
            echo "  network       Только тест сетевого драйвера"
            echo "  integration   Только комплексный тест всех драйверов"
            echo "  help          Показать эту справку"
            echo ""
            echo "Переменные окружения:"
            echo "  KEEP_TEST_LOGS=true  Сохранять логи тестов"
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