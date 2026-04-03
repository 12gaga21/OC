#!/bin/bash

# Утилита для запуска QEMU с автоматическим сбором логов и обработкой выхода
# Версия: 1.0

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции логирования
log_info() {
    echo -e "${BLUE}[QEMU RUNNER]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[QEMU RUNNER]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[QEMU RUNNER]${NC} $1"
}

log_error() {
    echo -e "${RED}[QEMU RUNNER]${NC} $1"
}

# Показать справку
show_help() {
    echo "Использование: $0 [опции]"
    echo ""
    echo "Опции:"
    echo "  -i, --image FILE        Путь к образу ОС (обязательно)"
    echo "  -o, --output FILE       Файл для сохранения лога (по умолчанию: qemu_output.log)"
    echo "  -t, --timeout SECONDS   Таймаут выполнения в секундах (по умолчанию: 30)"
    echo "  -m, --memory SIZE       Объем памяти для QEMU (по умолчанию: 128M)"
    echo "  -s, --serial            Включить последовательный порт"
    echo "  -n, --network           Включить сетевую эмуляцию"
    echo "  -d, --debug             Включить режим отладки (остановка при запуске)"
    echo "  -c, --command CMD       Команда QEMU (по умолчанию: qemu-system-i386)"
    echo "  -h, --help              Показать эту справку"
    echo ""
    echo "Примеры:"
    echo "  $0 -i os.img -o test.log -t 10"
    echo "  $0 --image build/os.img --timeout 20 --serial --network"
    echo ""
}

# Парсинг аргументов
parse_arguments() {
    IMAGE=""
    OUTPUT_FILE="qemu_output.log"
    TIMEOUT=30
    MEMORY="128M"
    SERIAL=false
    NETWORK=false
    DEBUG=false
    QEMU_CMD="qemu-system-i386"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -i|--image)
                IMAGE="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            -t|--timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            -m|--memory)
                MEMORY="$2"
                shift 2
                ;;
            -s|--serial)
                SERIAL=true
                shift
                ;;
            -n|--network)
                NETWORK=true
                shift
                ;;
            -d|--debug)
                DEBUG=true
                shift
                ;;
            -c|--command)
                QEMU_CMD="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Неизвестный аргумент: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Проверка обязательных аргументов
    if [ -z "$IMAGE" ]; then
        log_error "Не указан образ ОС (опция -i или --image)"
        show_help
        exit 1
    fi
    
    if [ ! -f "$IMAGE" ]; then
        log_error "Файл образа не найден: $IMAGE"
        exit 1
    fi
}

# Проверка доступности QEMU
check_qemu() {
    if ! command -v "$QEMU_CMD" &> /dev/null; then
        log_error "QEMU не найден: $QEMU_CMD"
        log_info "Попытка найти альтернативную команду..."
        
        # Попробовать найти qemu без суффикса
        if command -v "qemu" &> /dev/null; then
            QEMU_CMD="qemu"
            log_warning "Используется команда: $QEMU_CMD"
        else
            log_error "QEMU не установлен. Установите QEMU для запуска тестов."
            exit 1
        fi
    fi
    
    log_success "Используется QEMU: $QEMU_CMD"
}

# Построение команды QEMU
build_qemu_command() {
    local cmd="$QEMU_CMD"
    
    # Базовые параметры
    cmd="$cmd -fda \"$IMAGE\""
    cmd="$cmd -m $MEMORY"
    
    # Последовательный порт
    if [ "$SERIAL" = true ]; then
        cmd="$cmd -serial file:\"$OUTPUT_FILE\""
    fi
    
    # Сеть
    if [ "$NETWORK" = true ]; then
        cmd="$cmd -net nic,model=rtl8139 -net user"
    fi
    
    # Режим отладки
    if [ "$DEBUG" = true ]; then
        cmd="$cmd -s -S"
        log_info "Режим отладки включен. Подключитесь к gdb: target remote localhost:1234"
    fi
    
    # Дополнительные параметры для лучшей совместимости
    cmd="$cmd -no-reboot -no-shutdown"
    
    echo "$cmd"
}

# Запуск QEMU с таймаутом
run_qemu_with_timeout() {
    local qemu_cmd="$1"
    local timeout="$2"
    local output_file="$3"
    
    log_info "Запуск QEMU с таймаутом ${timeout} секунд..."
    log_info "Команда: $qemu_cmd"
    log_info "Лог будет сохранен в: $output_file"
    
    # Запуск QEMU в фоновом режиме
    if [ "$SERIAL" = true ]; then
        # Если есть перенаправление последовательного порта, QEMU будет писать в файл
        eval "timeout $timeout $qemu_cmd" &
    else
        # Иначе перенаправляем stdout и stderr в файл
        eval "timeout $timeout $qemu_cmd > \"$output_file\" 2>&1" &
    fi
    
    local qemu_pid=$!
    
    # Ожидание завершения QEMU
    wait $qemu_pid 2>/dev/null
    local exit_code=$?
    
    # Обработка кода выхода
    if [ $exit_code -eq 124 ]; then
        log_warning "QEMU завершен по таймауту ($timeout секунд)"
        # Убиваем процесс QEMU, если он еще работает
        kill $qemu_pid 2>/dev/null || true
        return 0
    elif [ $exit_code -eq 0 ]; then
        log_success "QEMU завершился успешно"
        return 0
    else
        log_error "QEMU завершился с ошибкой (код: $exit_code)"
        return 1
    fi
}

# Анализ лога QEMU
analyze_log() {
    local log_file="$1"
    
    if [ ! -f "$log_file" ]; then
        log_warning "Лог-файл не найден: $log_file"
        return 1
    fi
    
    if [ ! -s "$log_file" ]; then
        log_warning "Лог-файл пуст: $log_file"
        return 1
    fi
    
    log_info "Анализ лога QEMU ($log_file)..."
    
    # Проверка размера лога
    local log_size=$(stat -c%s "$log_file" 2>/dev/null || stat -f%z "$log_file")
    log_info "Размер лога: $log_size байт"
    
    # Поиск ключевых слов в логе
    local keywords=("error" "Error" "ERROR" "fail" "Fail" "FAIL" "panic" "Panic" "PANIC")
    local found_errors=false
    
    for keyword in "${keywords[@]}"; do
        if grep -q "$keyword" "$log_file"; then
            log_warning "Найдено ключевое слово в логе: $keyword"
            found_errors=true
        fi
    done
    
    # Поиск успешных сообщений
    local success_keywords=("Welcome" "OS loaded" "ready" "Ready" "success" "Success")
    local found_success=false
    
    for keyword in "${success_keywords[@]}"; do
        if grep -q "$keyword" "$log_file"; then
            log_success "Найдено позитивное сообщение: $keyword"
            found_success=true
        fi
    done
    
    # Вывод первых и последних строк лога
    log_info "Первые 5 строк лога:"
    head -5 "$log_file" 2>/dev/null || log_warning "Не удалось прочитать начало лога"
    
    log_info "Последние 5 строк лога:"
    tail -5 "$log_file" 2>/dev/null || log_warning "Не удалось прочитать конец лога"
    
    if [ "$found_errors" = true ] && [ "$found_success" = false ]; then
        log_warning "В логе обнаружены ошибки и нет успешных сообщений"
        return 1
    elif [ "$found_success" = true ]; then
        log_success "Лог содержит успешные сообщения"
        return 0
    else
        log_info "Лог не содержит явных ошибок или успешных сообщений"
        return 0
    fi
}

# Основная функция
main() {
    parse_arguments "$@"
    check_qemu
    
    local qemu_cmd=$(build_qemu_command)
    
    # Создание каталога для логов, если нужно
    local log_dir=$(dirname "$OUTPUT_FILE")
    if [ ! -d "$log_dir" ] && [ "$log_dir" != "." ]; then
        mkdir -p "$log_dir"
    fi
    
    # Запуск QEMU
    if run_qemu_with_timeout "$qemu_cmd" "$TIMEOUT" "$OUTPUT_FILE"; then
        log_success "QEMU успешно запущен и завершен"
    else
        log_error "Проблема с запуском QEMU"
        return 1
    fi
    
    # Анализ лога, если есть файл вывода
    if [ -f "$OUTPUT_FILE" ]; then
        analyze_log "$OUTPUT_FILE"
    fi
    
    log_success "Запуск QEMU завершен"
    return 0
}

# Запуск основной функции
main "$@"