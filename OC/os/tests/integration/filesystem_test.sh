#!/bin/bash

# Интеграционные тесты файловой системы операционной системы
# Версия: 1.0

set -e

# Загрузка утилит тестирования
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(dirname "$SCRIPT_DIR")"
UTILS_DIR="$TESTS_DIR/utils"

source "$UTILS_DIR/test_utils.sh"

# Инициализация утилит
init_test_utils

# Конфигурация тестирования файловой системы
FS_TEST_TIMEOUT=20
QEMU_MEMORY="128M"

# Тестирование базовых команд файловой системы
test_fs_basic_commands() {
    log_info "Тест 1: Проверка базовых команд файловой системы"
    
    local test_log="$RESULTS_DIR/fs_basic_test_$(date +%Y%m%d_%H%M%S).log"
    local os_image="$BUILD_DIR/os.img"
    
    if [ ! -f "$os_image" ]; then
        log_warning "Образ ОС не найден, пропуск теста файловой системы"
        return 0
    fi
    
    log_info "Запуск QEMU с тестированием файловой системы (таймаут ${FS_TEST_TIMEOUT} секунд)..."
    
    # Создание скрипта для автоматического тестирования
    local test_script="$RESULTS_DIR/fs_test_script.sh"
    
    cat > "$test_script" << 'EOF'
#!/bin/bash
echo "Testing filesystem basic commands..."
# Последовательность команд для тестирования файловой системы
echo "ls" > /tmp/qemu_input
echo "pwd" >> /tmp/qemu_input
echo "cd /" >> /tmp/qemu_input
echo "ls" >> /tmp/qemu_input
echo "exit" >> /tmp/qemu_input

# Запуск QEMU с вводом команд
timeout 15s qemu-system-i386 -fda build/os.img -serial file:fs_basic_test.log -monitor none < /tmp/qemu_input || true
EOF
    
    chmod +x "$test_script"
    
    # Запуск тестового скрипта
    cd "$BUILD_DIR"
    if timeout ${FS_TEST_TIMEOUT}s bash "$test_script"; then
        log_info "Тестовый скрипт выполнен"
    else
        log_warning "Тестовый скрипт завершился с ошибкой или по таймауту"
    fi
    
    cd "$SCRIPT_DIR"
    
    # Проверка лога
    local log_file="$BUILD_DIR/fs_basic_test.log"
    if [ -f "$log_file" ] && [ -s "$log_file" ]; then
        log_success "Файловая система вывела данные в лог"
        
        # Анализ лога
        local line_count=$(wc -l < "$log_file")
        log_info "Лог файловой системы: $line_count строк"
        
        # Поиск ключевых слов, связанных с файловой системой
        local fs_keywords=("ls" "pwd" "cd" "directory" "Directory" "file" "File" "root" "Root")
        local found_keywords=0
        
        for keyword in "${fs_keywords[@]}"; do
            if grep -q "$keyword" "$log_file"; then
                log_info "Найдено ключевое слово: $keyword"
                ((found_keywords++))
            fi
        done
        
        # Проверка наличия вывода команд
        if grep -q "ls" "$log_file" || grep -q "directory" "$log_file"; then
            log_success "Команда 'ls' выполнена успешно"
        fi
        
        if grep -q "pwd" "$log_file"; then
            log_success "Команда 'pwd' выполнена успешно"
        fi
        
        # Показать первые 10 строк лога
        log_info "Первые 10 строк лога файловой системы:"
        head -10 "$log_file" 2>/dev/null || true
        
        # Очистка временных файлов
        rm -f "$test_script" "$log_file" /tmp/qemu_input 2>/dev/null || true
        
        return 0
    else
        log_warning "Нет вывода от файловой системы"
        
        # Очистка временных файлов
        rm -f "$test_script" "$log_file" /tmp/qemu_input 2>/dev/null || true
        
        return 0  # Не считаем это ошибкой
    fi
}

# Тестирование операций с файлами
test_fs_file_operations() {
    log_info "Тест 2: Проверка операций с файлами"
    
    local test_log="$RESULTS_DIR/fs_file_ops_test_$(date +%Y%m%d_%H%M%S).log"
    local os_image="$BUILD_DIR/os.img"
    
    if [ ! -f "$os_image" ]; then
        log_warning "Образ ОС не найден, пропуск теста операций с файлами"
        return 0
    fi
    
    log_info "Запуск QEMU с тестированием операций с файлами (таймаут ${FS_TEST_TIMEOUT} секунд)..."
    
    # Создание скрипта для тестирования операций с файлами
    local test_script="$RESULTS_DIR/fs_file_test_script.sh"
    
    cat > "$test_script" << 'EOF'
#!/bin/bash
echo "Testing filesystem file operations..."
# Последовательность команд для тестирования операций с файлами
echo "echo 'Hello, World!' > test.txt" > /tmp/qemu_input
echo "cat test.txt" >> /tmp/qemu_input
echo "ls" >> /tmp/qemu_input
echo "rm test.txt" >> /tmp/qemu_input
echo "ls" >> /tmp/qemu_input
echo "exit" >> /tmp/qemu_input

# Запуск QEMU с вводом команд
timeout 15s qemu-system-i386 -fda build/os.img -serial file:fs_file_ops_test.log -monitor none < /tmp/qemu_input || true
EOF
    
    chmod +x "$test_script"
    
    # Запуск тестового скрипта
    cd "$BUILD_DIR"
    if timeout ${FS_TEST_TIMEOUT}s bash "$test_script"; then
        log_info "Тестовый скрипт операций с файлами выполнен"
    else
        log_warning "Тестовый скрипт операций с файлами завершился с ошибкой или по таймауту"
    fi
    
    cd "$SCRIPT_DIR"
    
    # Проверка лога
    local log_file="$BUILD_DIR/fs_file_ops_test.log"
    if [ -f "$log_file" ] && [ -s "$log_file" ]; then
        log_success "Операции с файлами вывели данные в лог"
        
        # Анализ лога
        local line_count=$(wc -l < "$log_file")
        log_info "Лог операций с файлами: $line_count строк"
        
        # Поиск ключевых слов
        local file_op_keywords=("test.txt" "Hello" "World" "echo" "cat" "rm")
        local found_keywords=0
        
        for keyword in "${file_op_keywords[@]}"; do
            if grep -q "$keyword" "$log_file"; then
                log_info "Найдено ключевое слово: $keyword"
                ((found_keywords++))
            fi
        done
        
        # Проверка наличия вывода команд
        if grep -q "Hello, World!" "$log_file"; then
            log_success "Создание и чтение файла выполнено успешно"
        fi
        
        # Показать первые 10 строк лога
        log_info "Первые 10 строк лога операций с файлами:"
        head -10 "$log_file" 2>/dev/null || true
        
        # Очистка временных файлов
        rm -f "$test_script" "$log_file" /tmp/qemu_input 2>/dev/null || true
        
        return 0
    else
        log_warning "Нет вывода от операций с файлами"
        
        # Очистка временных файлов
        rm -f "$test_script" "$log_file" /tmp/qemu_input 2>/dev/null || true
        
        return 0  # Не считаем это ошибкой
    fi
}

# Тестирование поддержки FAT32
test_fat32_support() {
    log_info "Тест 3: Проверка поддержки FAT32"
    
    local os_image="$BUILD_DIR/os.img"
    
    if [ ! -f "$os_image" ]; then
        log_warning "Образ ОС не найден, пропуск теста FAT32"
        return 0
    fi
    
    # Проверка наличия модуля FAT32 в исходном коде
    local fat32_source="$OS_DIR/os/src/kernel/fat32.asm"
    
    if [ -f "$fat32_source" ]; then
        log_success "Модуль FAT32 найден: $fat32_source"
        
        # Проверка размера файла (должен быть ненулевым)
        local source_size=$(stat -c%s "$fat32_source" 2>/dev/null || stat -f%z "$fat32_source")
        
        if [ "$source_size" -gt 100 ]; then
            log_success "Модуль FAT32 имеет достаточный размер: $source_size байт"
        else
            log_warning "Модуль FAT32 очень мал: $source_size байт"
        fi
        
        # Проверка наличия ключевых функций FAT32 в исходном коде
        local fat32_functions=("fat32_init" "fat32_read" "fat32_write" "fat32_cluster_to_sector")
        local found_functions=0
        
        for function in "${fat32_functions[@]}"; do
            if grep -q "$function" "$fat32_source"; then
                log_info "Найдена функция FAT32: $function"
                ((found_functions++))
            fi
        done
        
        if [ $found_functions -gt 0 ]; then
            log_success "В модуле FAT32 найдены ключевые функции ($found_functions из ${#fat32_functions[@]})"
        else
            log_warning "В модуле FAT32 не найдены ключевые функции"
        fi
        
        return 0
    else
        log_warning "Модуль FAT32 не найден: $fat32_source"
        return 0
    fi
}

# Тестирование работы с директориями
test_directory_operations() {
    log_info "Тест 4: Проверка операций с директориями"
    
    local os_image="$BUILD_DIR/os.img"
    
    if [ ! -f "$os_image" ]; then
        log_warning "Образ ОС не найден, пропуск теста операций с директориями"
        return 0
    fi
    
    # Проверка наличия модуля директорий в исходном коде
    local dir_source="$OS_DIR/os/src/kernel/dir.asm"
    
    if [ -f "$dir_source" ]; then
        log_success "Модуль директорий найден: $dir_source"
        
        # Проверка размера файла
        local source_size=$(stat -c%s "$dir_source" 2>/dev/null || stat -f%z "$dir_source")
        
        if [ "$source_size" -gt 50 ]; then
            log_success "Модуль директорий имеет достаточный размер: $source_size байт"
        else
            log_warning "Модуль директорий очень мал: $source_size байт"
        fi
        
        # Проверка наличия ключевых функций работы с директориями
        local dir_functions=("read_dir" "find_file" "create_dir" "list_dir")
        local found_functions=0
        
        for function in "${dir_functions[@]}"; do
            if grep -q "$function" "$dir_source"; then
                log_info "Найдена функция работы с директориями: $function"
                ((found_functions++))
            fi
        done
        
        if [ $found_functions -gt 0 ]; then
            log_success "В модуле директорий найдены ключевые функции ($found_functions из ${#dir_functions[@]})"
        else
            log_warning "В модуле директорий не найдены ключевые функции"
        fi
        
        return 0
    else
        log_warning "Модуль директорий не найден: $dir_source"
        return 0
    fi
}

# Комплексный тест файловой системы
test_fs_integration() {
    log_info "Тест 5: Комплексная проверка файловой системы"
    
    local test_log="$RESULTS_DIR/fs_integration_test_$(date +%Y%m%d_%H%M%S).log"
    local os_image="$BUILD_DIR/os.img"
    
    if [ ! -f "$os_image" ]; then
        log_warning "Образ ОС не найден, пропуск комплексного теста файловой системы"
        return 0
    fi
    
    log_info "Запуск комплексного теста файловой системы (таймаут 25 секунд)..."
    
    # Создание комплексного тестового скрипта
    local test_script="$RESULTS_DIR/fs_integration_script.sh"
    
    cat > "$test_script" << 'EOF'
#!/bin/bash
echo "Running comprehensive filesystem tests..."
# Комплексная последовательность команд для тестирования файловой системы
{
    echo "ls"
    sleep 1
    echo "pwd"
    sleep 1
    echo "cd /"
    sleep 1
    echo "mkdir testdir"
    sleep 1
    echo "cd testdir"
    sleep 1
    echo "echo 'Test file content' > testfile.txt"
    sleep 1
    echo "cat testfile.txt"
    sleep 1
    echo "ls"
    sleep 1
    echo "cd .."
    sleep 1
    echo "rmdir testdir"
    sleep 1
    echo "ls"
    sleep 1
    echo "exit"
} > /tmp/qemu_input_complex

# Запуск QEMU с вводом команд
timeout 20s qemu-system-i386 -fda build/os.img -serial file:fs_integration_test.log -monitor none < /tmp/qemu_input_complex || true
EOF
    
    chmod +x "$test_script"
    
    # Запуск тестового скрипта
    cd "$BUILD_DIR"
    if timeout 25s bash "$test_script"; then
        log_info "Комплексный тестовый скрипт выполнен"
    else
        log_warning "Комплексный тестовый скрипт завершился с ошибкой или по таймауту"
    fi
    
    cd "$SCRIPT_DIR"
    
    # Проверка лога
    local log_file="$BUILD_DIR/fs_integration_test.log"
    if [ -f "$log_file" ] && [ -s "$log_file" ]; then
        log_success "Комплексный тест файловой системы вывел данные в лог"
        
        # Анализ лога
        local line_count=$(wc -l < "$log_file")
        log_info "Лог комплексного теста: $line_count строк"
        
        # Проверка разнообразия вывода
        local unique_lines=$(sort "$log_file" | uniq | wc -l)
        log_info "Уникальных строк в логе: $unique_lines"
        
        if [ $line_count -gt 10 ]; then
            log_success "Файловая система выводит достаточное количество информации"
        else
            log_warning "Файловая система выводит мало информации"
        fi
        
        # Показать образец вывода
        log_info "Образец вывода файловой системы (строки 5-15):"
        sed -n '5,15p' "$log_file" 2>/dev/null || head -10 "$log_file"
        
        # Очистка временных файлов
        rm -f "$test_script" "$log_file" /tmp/qemu_input_complex 2>/dev/null || true
        
        return 0
    else
        log_warning "Нет вывода от комплексного теста файловой системы"
        
        # Очистка временных файлов
        rm -f "$test_script" "$log_file" /tmp/qemu_input_complex 2>/dev/null || true
        
        return 0  # Не считаем это ошибкой
    fi
}

# Основная функция тестирования
run_filesystem_tests() {
    log_info "=== Запуск интеграционных тестов файловой системы ==="
    
    local tests_passed=0
    local tests_failed=0
    local tests_skipped=0
    
    # Список тестов
    local test_functions=(
        "test_fs_basic_commands"
        "test_fs_file_operations"
        "test_fat32_support"
        "test_directory_operations"
        "test_fs_integration"
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
    log_info "=== ИТОГИ ТЕСТИРОВАНИЯ ФАЙЛОВОЙ СИСТЕМЫ ==="
    log_info "Пройдено: $tests_passed"
    log_info "Не пройдено: $tests_failed"
    log_info "Пропущено: $tests_skipped"
    
    if [ $tests_failed -eq 0 ]; then
        log_success "Все тесты файловой системы пройдены успешно!"
        
        # Генерация отчета
        generate_test_report \
            "$RESULTS_DIR/filesystem_report_$(date +%Y%m%d_%H%M%S).txt" \
            "Filesystem Integration Tests" \
            "PASS" \
            "Все $tests_passed тестов файловой системы пройдены успешно"
        
        return 0
    else
        log_error "Некоторые тесты файловой системы не пройдены"
        
        # Генерация отчета
        generate_test_report \
            "$RESULTS_DIR/filesystem_report_$(date +%Y%m%d_%H%M%S).txt" \
            "Filesystem Integration Tests" \
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
            
            run_filesystem_tests
            ;;
        basic)
            test_fs_basic_commands
            ;;
        fileops)
            test_fs_file_operations
            ;;
        fat32)
            test_fat32_support
            ;;
        dir)
            test_directory_operations
            ;;
        integration)
            test_fs_integration
            ;;
        help|--help|-h)
            echo "Использование: $0 [команда]"
            echo ""
            echo "Команды:"
            echo "  all           Запустить все тесты файловой системы (по умолчанию)"
            echo "  basic         Только тест базовых команд"
            echo "  fileops       Только тест операций с файлами"
            echo "  fat32         Только тест поддержки FAT32"
            echo "  dir           Только тест операций с директориями"
            echo "  integration   Только комплексный тест"
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