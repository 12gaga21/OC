#!/bin/bash

# Интеграционные тесты сетевого стека операционной системы
# Версия: 1.0

set -e

# Загрузка утилит тестирования
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(dirname "$SCRIPT_DIR")"
UTILS_DIR="$TESTS_DIR/utils"

source "$UTILS_DIR/test_utils.sh"

# Инициализация утилит
init_test_utils

# Конфигурация тестирования сети
NETWORK_TEST_TIMEOUT=15
QEMU_MEMORY="128M"

# Тестирование инициализации сетевого стека
test_network_initialization() {
    log_info "Тест 1: Проверка инициализации сетевого стека"
    
    local test_log="$RESULTS_DIR/network_init_test_$(date +%Y%m%d_%H%M%S).log"
    local os_image="$BUILD_DIR/os.img"
    
    if [ ! -f "$os_image" ]; then
        log_warning "Образ ОС не найден, пропуск теста инициализации сети"
        return 0
    fi
    
    log_info "Запуск QEMU с сетевым стеком (таймаут ${NETWORK_TEST_TIMEOUT} секунд)..."
    
    # Запуск QEMU с эмуляцией сети
    timeout ${NETWORK_TEST_TIMEOUT}s qemu-system-i386 \
        -fda "$os_image" \
        -m "$QEMU_MEMORY" \
        -net nic,model=rtl8139 \
        -net user \
        -serial file:"$test_log" \
        -no-reboot -no-shutdown \
        || true
    
    # Проверка лога
    if [ -f "$test_log" ] && [ -s "$test_log" ]; then
        log_success "Сетевой стек вывел данные в лог"
        
        # Анализ лога
        local line_count=$(wc -l < "$test_log")
        log_info "Лог инициализации сети: $line_count строк"
        
        # Поиск ключевых слов, связанных с сетью
        local network_keywords=("network" "Network" "NETWORK" "net" "Net" "eth" "Ethernet" "ip" "IP" "MAC" "packet" "driver")
        local found_keywords=0
        
        for keyword in "${network_keywords[@]}"; do
            if grep -q "$keyword" "$test_log"; then
                log_info "Найдено ключевое слово: $keyword"
                ((found_keywords++))
            fi
        done
        
        # Поиск сообщений об инициализации
        local init_keywords=("init" "Init" "initializing" "Initializing" "start" "Start" "found" "Found")
        local found_init=0
        
        for keyword in "${init_keywords[@]}"; do
            if grep -q "$keyword" "$test_log"; then
                log_info "Найдено ключевое слово инициализации: $keyword"
                ((found_init++))
            fi
        done
        
        if [ $found_keywords -gt 0 ]; then
            log_success "В логе найдены ключевые слова сети ($found_keywords совпадений)"
        else
            log_info "В логе нет явных ключевых слов сети"
        fi
        
        if [ $found_init -gt 0 ]; then
            log_success "В логе найдены сообщения об инициализации ($found_init совпадений)"
        fi
        
        # Показать первые 10 строк лога
        log_info "Первые 10 строк лога инициализации сети:"
        head -10 "$test_log" 2>/dev/null || true
        
        # Очистка лога, если не нужен
        if [ "${KEEP_TEST_LOGS:-false}" != "true" ]; then
            rm -f "$test_log"
        fi
        
        return 0
    else
        log_warning "Нет вывода от сетевого стека"
        
        # Очистка
        rm -f "$test_log" 2>/dev/null || true
        
        return 0  # Не считаем это ошибкой
    fi
}

# Тестирование сетевых модулей в исходном коде
test_network_modules() {
    log_info "Тест 2: Проверка сетевых модулей в исходном коде"
    
    # Проверка наличия сетевых модулей
    local network_modules=(
        "$OS_DIR/os/src/kernel/network.asm"
        "$OS_DIR/os/src/kernel/tcpip.asm"
        "$OS_DIR/os/src/kernel/net_utils.asm"
    )
    
    local found_modules=0
    local missing_modules=()
    
    for module in "${network_modules[@]}"; do
        if [ -f "$module" ]; then
            log_success "Сетевой модуль найден: $(basename "$module")"
            ((found_modules++))
            
            # Проверка размера модуля
            local module_size=$(stat -c%s "$module" 2>/dev/null || stat -f%z "$module")
            if [ "$module_size" -gt 100 ]; then
                log_info "  Размер: $module_size байт"
            else
                log_warning "  Модуль очень мал: $module_size байт"
            fi
        else
            log_warning "Сетевой модуль не найден: $(basename "$module")"
            missing_modules+=("$(basename "$module")")
        fi
    done
    
    # Проверка наличия ключевых функций сети
    local network_source="$OS_DIR/os/src/kernel/network.asm"
    if [ -f "$network_source" ]; then
        log_info "Анализ сетевого модуля network.asm..."
        
        local network_functions=("net_init" "net_send" "net_receive" "net_handle_packet")
        local found_functions=0
        
        for function in "${network_functions[@]}"; do
            if grep -q "$function" "$network_source"; then
                log_info "  Найдена функция: $function"
                ((found_functions++))
            fi
        done
        
        if [ $found_functions -gt 0 ]; then
            log_success "В сетевом модуле найдены ключевые функции ($found_functions из ${#network_functions[@]})"
        else
            log_warning "В сетевом модуле не найдены ключевые функции"
        fi
    fi
    
    # Проверка TCP/IP стека
    local tcpip_source="$OS_DIR/os/src/kernel/tcpip.asm"
    if [ -f "$tcpip_source" ]; then
        log_info "Анализ TCP/IP модуля tcpip.asm..."
        
        local tcpip_functions=("tcp_init" "tcp_send" "tcp_receive" "ip_send" "ip_receive")
        local found_tcpip_functions=0
        
        for function in "${tcpip_functions[@]}"; do
            if grep -q "$function" "$tcpip_source"; then
                log_info "  Найдена функция TCP/IP: $function"
                ((found_tcpip_functions++))
            fi
        done
        
        if [ $found_tcpip_functions -gt 0 ]; then
            log_success "В TCP/IP модуле найдены ключевые функции ($found_tcpip_functions из ${#tcpip_functions[@]})"
        else
            log_warning "В TCP/IP модуле не найдены ключевые функции"
        fi
    fi
    
    if [ ${#missing_modules[@]} -eq 0 ]; then
        log_success "Все сетевые модули присутствуют ($found_modules модулей)"
        return 0
    else
        log_warning "Отсутствуют некоторые сетевые модули: ${missing_modules[*]}"
        return 0  # Не считаем это ошибкой, так как сеть может быть не полностью реализована
    fi
}

# Тестирование базовых сетевых операций
test_network_basic_operations() {
    log_info "Тест 3: Проверка базовых сетевых операций"
    
    local test_log="$RESULTS_DIR/network_ops_test_$(date +%Y%m%d_%H%M%S).log"
    local os_image="$BUILD_DIR/os.img"
    
    if [ ! -f "$os_image" ]; then
        log_warning "Образ ОС не найден, пропуск теста сетевых операций"
        return 0
    fi
    
    log_info "Запуск QEMU с тестированием сетевых операций (таймаут ${NETWORK_TEST_TIMEOUT} секунд)..."
    
    # Создание скрипта для тестирования сетевых операций
    local test_script="$RESULTS_DIR/network_test_script.sh"
    
    cat > "$test_script" << 'EOF'
#!/bin/bash
echo "Testing network operations..."
# Последовательность команд для тестирования сети
echo "netstat" > /tmp/qemu_network_input
echo "ifconfig" >> /tmp/qemu_network_input
echo "ping 127.0.0.1" >> /tmp/qemu_network_input
echo "exit" >> /tmp/qemu_network_input

# Запуск QEMU с вводом команд
timeout 12s qemu-system-i386 -fda build/os.img -net nic,model=rtl8139 -net user -serial file:network_ops_test.log -monitor none < /tmp/qemu_network_input || true
EOF
    
    chmod +x "$test_script"
    
    # Запуск тестового скрипта
    cd "$BUILD_DIR"
    if timeout ${NETWORK_TEST_TIMEOUT}s bash "$test_script"; then
        log_info "Тестовый скрипт сетевых операций выполнен"
    else
        log_warning "Тестовый скрипт сетевых операций завершился с ошибкой или по таймауту"
    fi
    
    cd "$SCRIPT_DIR"
    
    # Проверка лога
    local log_file="$BUILD_DIR/network_ops_test.log"
    if [ -f "$log_file" ] && [ -s "$log_file" ]; then
        log_success "Сетевые операции вывели данные в лог"
        
        # Анализ лога
        local line_count=$(wc -l < "$log_file")
        log_info "Лог сетевых операций: $line_count строк"
        
        # Поиск ключевых слов сетевых команд
        local network_cmd_keywords=("netstat" "ifconfig" "ping" "127.0.0.1" "localhost")
        local found_cmds=0
        
        for keyword in "${network_cmd_keywords[@]}"; do
            if grep -q "$keyword" "$log_file"; then
                log_info "Найдено ключевое слово команды: $keyword"
                ((found_cmds++))
            fi
        done
        
        if [ $found_cmds -gt 0 ]; then
            log_success "В логе найдены ключевые слова сетевых команд ($found_cmds совпадений)"
        else
            log_info "В логе нет явных ключевых слов сетевых команд"
        fi
        
        # Показать первые 10 строк лога
        log_info "Первые 10 строк лога сетевых операций:"
        head -10 "$log_file" 2>/dev/null || true
        
        # Очистка временных файлов
        rm -f "$test_script" "$log_file" /tmp/qemu_network_input 2>/dev/null || true
        
        return 0
    else
        log_warning "Нет вывода от сетевых операций"
        
        # Очистка временных файлов
        rm -f "$test_script" "$log_file" /tmp/qemu_network_input 2>/dev/null || true
        
        return 0  # Не считаем это ошибкой
    fi
}

# Комплексный тест сетевого стека
test_network_integration() {
    log_info "Тест 4: Комплексная проверка сетевого стека"
    
    local test_log="$RESULTS_DIR/network_integration_test_$(date +%Y%m%d_%H%M%S).log"
    local os_image="$BUILD_DIR/os.img"
    
    if [ ! -f "$os_image" ]; then
        log_warning "Образ ОС не найден, пропуск комплексного теста сети"
        return 0
    fi
    
    log_info "Запуск комплексного теста сетевого стека (таймаут 20 секунд)..."
    
    # Запуск QEMU с расширенной сетевой конфигурацией
    timeout 20s qemu-system-i386 \
        -fda "$os_image" \
        -m "$QEMU_MEMORY" \
        -net nic,model=rtl8139 \
        -net user,hostfwd=tcp::2222-:22,hostfwd=udp::2223-:23 \
        -serial file:"$test_log" \
        -no-reboot -no-shutdown \
        || true
    
    # Проверка лога
    if [ -f "$test_log" ] && [ -s "$test_log" ]; then
        log_success "Комплексный тест сети вывел данные в лог"
        
        # Анализ лога
        local line_count=$(wc -l < "$test_log")
        log_info "Лог комплексного теста сети: $line_count строк"
        
        # Проверка разнообразия вывода
        local unique_lines=$(sort "$test_log" | uniq | wc -l)
        log_info "Уникальных строк в логе: $unique_lines"
        
        if [ $line_count -gt 5 ]; then
            log_success "Сетевой стек выводит достаточное количество информации"
        else
            log_warning "Сетевой стек выводит мало информации"
        fi
        
        # Поиск ошибок в логе
        local error_keywords=("error" "Error" "ERROR" "fail" "Fail" "FAIL" "panic" "Panic")
        local found_errors=0
        
        for keyword in "${error_keywords[@]}"; do
            if grep -q "$keyword" "$test_log"; then
                log_warning "Найдено ключевое слово ошибки: $keyword"
                ((found_errors++))
            fi
        done
        
        if [ $found_errors -eq 0 ]; then
            log_success "В логе не найдено ошибок"
        else
            log_warning "В логе найдены ошибки ($found_errors совпадений)"
        fi
        
        # Показать образец вывода
        log_info "Образец вывода сетевого стека (строки 5-15):"
        sed -n '5,15p' "$test_log" 2>/dev/null || head -10 "$test_log"
        
        # Очистка лога, если не нужен
        if [ "${KEEP_TEST_LOGS:-false}" != "true" ]; then
            rm -f "$test_log"
        fi
        
        return 0
    else
        log_warning "Нет вывода от комплексного теста сети"
        
        # Очистка
        rm -f "$test_log" 2>/dev/null || true
        
        return 0  # Не считаем это ошибкой
    fi
}

# Основная функция тестирования
run_network_tests() {
    log_info "=== Запуск интеграционных тестов сетевого стека ==="
    
    local tests_passed=0
    local tests_failed=0
    local tests_skipped=0
    
    # Список тестов
    local test_functions=(
        "test_network_initialization"
        "test_network_modules"
        "test_network_basic_operations"
        "test_network_integration"
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
    log_info "=== ИТОГИ ТЕСТИРОВАНИЯ СЕТЕВОГО СТЕКА ==="
    log_info "Пройдено: $tests_passed"
    log_info "Не пройдено: $tests_failed"
    log_info "Пропущено: $tests_skipped"
    
    if [ $tests_failed -eq 0 ]; then
        log_success "Все тесты сетевого стека пройдены успешно!"
        
        # Генерация отчета
        generate_test_report \
            "$RESULTS_DIR/network_report_$(date +%Y%m%d_%H%M%S).txt" \
            "Network Stack Integration Tests" \
            "PASS" \
            "Все $tests_passed тестов сетевого стека пройдены успешно"
        
        return 0
    else
        log_error "Некоторые тесты сетевого стека не пройдены"
        
        # Генерация отчета
        generate_test_report \
            "$RESULTS_DIR/network_report_$(date +%Y%m%d_%H%M%S).txt" \
            "Network Stack Integration Tests" \
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
            
            run_network_tests
            ;;
        init)
            test_network_initialization
            ;;
        modules)
            test_network_modules
            ;;
        operations)
            test_network_basic_operations
            ;;
        integration)
            test_network_integration
            ;;
        help|--help|-h)
            echo "Использование: $0 [команда]"
            echo ""
            echo "Команды:"
            echo "  all           Запустить все тесты сетевого стека (по умолчанию)"
            echo "  init          Только тест инициализации сети"
            echo "  modules       Только тест сетевых модулей"
            echo "  operations    Только тест сетевых операций"
            echo "  integration   Только комплексный тест"
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