#!/bin/bash

# Генератор сводных отчетов о тестировании операционной системы
# Версия: 1.0

set -e

# Загрузка утилит тестирования
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(dirname "$SCRIPT_DIR")"
UTILS_DIR="$TESTS_DIR/utils"

source "$UTILS_DIR/test_utils.sh"

# Инициализация утилит
init_test_utils

# Конфигурация отчетов
REPORTS_DIR="$RESULTS_DIR/reports"
SUMMARY_REPORT="$REPORTS_DIR/summary_report_$(date +%Y%m%d_%H%M%S)"
TEXT_REPORT="${SUMMARY_REPORT}.txt"
JSON_REPORT="${SUMMARY_REPORT}.json"
HTML_REPORT="${SUMMARY_REPORT}.html"

# Создание каталога для отчетов
mkdir -p "$REPORTS_DIR"

# Функции для генерации отчетов
generate_text_report() {
    log_info "Генерация текстового отчета: $TEXT_REPORT"
    
    local report_file="$TEXT_REPORT"
    
    # Заголовок отчета
    cat > "$report_file" << EOF
=== СВОДНЫЙ ОТЧЕТ О ТЕСТИРОВАНИИ ОПЕРАЦИОННОЙ СИСТЕМЫ ===

Дата генерации: $(date '+%Y-%m-%d %H:%M:%S')
Каталог тестов: $TESTS_DIR
Каталог сборки: $BUILD_DIR

EOF
    
    # Поиск всех отчетов тестов
    local test_reports=($(find "$RESULTS_DIR" -name "*_report_*.txt" -type f | sort))
    
    if [ ${#test_reports[@]} -eq 0 ]; then
        echo "Нет доступных отчетов тестирования." >> "$report_file"
        echo "Запустите тесты для генерации отчетов." >> "$report_file"
        log_warning "Не найдено отчетов тестирования"
    else
        echo "Найдено отчетов: ${#test_reports[@]}" >> "$report_file"
        echo "" >> "$report_file"
        
        local total_tests=0
        local passed_tests=0
        local failed_tests=0
        local skipped_tests=0
        
        # Обработка каждого отчета
        for report in "${test_reports[@]}"; do
            local report_name=$(basename "$report")
            local test_type=$(echo "$report_name" | sed 's/_report_.*//')
            
            echo "--- Отчет: $test_type ---" >> "$report_file"
            
            # Извлечение информации из отчета
            if [ -f "$report" ]; then
                # Чтение основных данных из отчета
                local report_date=$(grep "Дата:" "$report" | head -1 | cut -d: -f2- | sed 's/^[[:space:]]*//')
                local test_result=$(grep "Результат:" "$report" | head -1 | cut -d: -f2- | sed 's/^[[:space:]]*//')
                local test_message=$(grep "Сообщение:" "$report" | head -1 | cut -d: -f2- | sed 's/^[[:space:]]*//')
                
                echo "Дата теста: ${report_date:-Неизвестно}" >> "$report_file"
                echo "Результат: ${test_result:-Неизвестно}" >> "$report_file"
                echo "Сообщение: ${test_message:-Неизвестно}" >> "$report_file"
                
                # Подсчет статистики
                if echo "$test_result" | grep -qi "PASS"; then
                    ((passed_tests++))
                elif echo "$test_result" | grep -qi "FAIL"; then
                    ((failed_tests++))
                fi
                
                ((total_tests++))
                
                # Добавление краткого содержания
                echo "Содержание:" >> "$report_file"
                head -20 "$report" | tail -15 >> "$report_file"
                echo "" >> "$report_file"
            else
                echo "Ошибка чтения отчета" >> "$report_file"
            fi
        done
        
        # Сводная статистика
        echo "=== СВОДНАЯ СТАТИСТИКА ===" >> "$report_file"
        echo "Всего отчетов: $total_tests" >> "$report_file"
        echo "Пройдено успешно: $passed_tests" >> "$report_file"
        echo "Не пройдено: $failed_tests" >> "$report_file"
        echo "Пропущено: $skipped_tests" >> "$report_file"
        
        if [ $total_tests -gt 0 ]; then
            local success_rate=$((passed_tests * 100 / total_tests))
            echo "Процент успешных тестов: $success_rate%" >> "$report_file"
        fi
        
        # Общий результат
        echo "" >> "$report_file"
        if [ $failed_tests -eq 0 ] && [ $total_tests -gt 0 ]; then
            echo "ОБЩИЙ РЕЗУЛЬТАТ: ВСЕ ТЕСТЫ ПРОЙДЕНЫ УСПЕШНО" >> "$report_file"
        elif [ $total_tests -eq 0 ]; then
            echo "ОБЩИЙ РЕЗУЛЬТАТ: НЕТ ДАННЫХ ДЛЯ АНАЛИЗА" >> "$report_file"
        else
            echo "ОБЩИЙ РЕЗУЛЬТАТ: НЕКОТОРЫЕ ТЕСТЫ НЕ ПРОЙДЕНЫ" >> "$report_file"
        fi
    fi
    
    # Информация о системе
    echo "" >> "$report_file"
    echo "=== СИСТЕМНАЯ ИНФОРМАЦИЯ ===" >> "$report_file"
    echo "Дата: $(date)" >> "$report_file"
    echo "Система: $(uname -a)" >> "$report_file"
    
    if command -v nasm &> /dev/null; then
        echo "NASM: $(nasm --version | head -n1)" >> "$report_file"
    fi
    
    if command -v qemu-system-i386 &> /dev/null; then
        echo "QEMU: $(qemu-system-i386 --version | head -n1)" >> "$report_file"
    fi
    
    log_success "Текстовый отчет создан: $report_file"
}

generate_json_report() {
    log_info "Генерация JSON отчета: $JSON_REPORT"
    
    local report_file="$JSON_REPORT"
    
    # Поиск всех отчетов тестов
    local test_reports=($(find "$RESULTS_DIR" -name "*_report_*.txt" -type f | sort))
    
    # Начало JSON документа
    cat > "$report_file" << EOF
{
  "summary_report": {
    "generated_at": "$(date -Iseconds)",
    "tests_directory": "$TESTS_DIR",
    "build_directory": "$BUILD_DIR",
    "total_reports": ${#test_reports[@]}
  },
  "test_reports": [
EOF
    
    # Добавление данных каждого отчета
    local first=true
    for report in "${test_reports[@]}"; do
        if [ "$first" = true ]; then
            first=false
        else
            echo "    ," >> "$report_file"
        fi
        
        local report_name=$(basename "$report")
        local test_type=$(echo "$report_name" | sed 's/_report_.*//')
        local report_date=$(grep "Дата:" "$report" | head -1 | cut -d: -f2- | sed 's/^[[:space:]]*//' || echo "")
        local test_result=$(grep "Результат:" "$report" | head -1 | cut -d: -f2- | sed 's/^[[:space:]]*//' || echo "")
        local test_message=$(grep "Сообщение:" "$report" | head -1 | cut -d: -f2- | sed 's/^[[:space:]]*//' || echo "")
        
        cat >> "$report_file" << EOF
    {
      "name": "$test_type",
      "report_file": "$report_name",
      "date": "$report_date",
      "result": "$test_result",
      "message": "$test_message"
    }
EOF
    done
    
    # Завершение JSON документа
    cat >> "$report_file" << EOF
  ],
  "system_info": {
    "os": "$(uname -s)",
    "architecture": "$(uname -m)",
    "nasm_available": "$(command -v nasm > /dev/null && echo "true" || echo "false")",
    "qemu_available": "$(command -v qemu-system-i386 > /dev/null && echo "true" || echo "false")"
  }
}
EOF
    
    log_success "JSON отчет создан: $report_file"
}

generate_html_report() {
    log_info "Генерация HTML отчета: $HTML_REPORT"
    
    local report_file="$HTML_REPORT"
    
    # Поиск всех отчетов тестов
    local test_reports=($(find "$RESULTS_DIR" -name "*_report_*.txt" -type f | sort))
    local total_reports=${#test_reports[@]}
    
    local passed_count=0
    local failed_count=0
    
    # Подсчет результатов
    for report in "${test_reports[@]}"; do
        local test_result=$(grep "Результат:" "$report" | head -1 | cut -d: -f2- | sed 's/^[[:space:]]*//' || echo "")
        if echo "$test_result" | grep -qi "PASS"; then
            ((passed_count++))
        elif echo "$test_result" | grep -qi "FAIL"; then
            ((failed_count++))
        fi
    done
    
    # Генерация HTML
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Отчет о тестировании ОС</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            line-height: 1.6;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
            color: #333;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background-color: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 0 20px rgba(0,0,0,0.1);
        }
        
        header {
            text-align: center;
            margin-bottom: 40px;
            border-bottom: 2px solid #4CAF50;
            padding-bottom: 20px;
        }
        
        h1 {
            color: #2c3e50;
            margin-bottom: 10px;
        }
        
        .subtitle {
            color: #7f8c8d;
            font-size: 1.1em;
        }
        
        .summary-cards {
            display: flex;
            justify-content: space-around;
            flex-wrap: wrap;
            margin-bottom: 40px;
        }
        
        .card {
            background-color: #f8f9fa;
            border-radius: 8px;
            padding: 20px;
            text-align: center;
            flex: 1;
            margin: 10px;
            min-width: 200px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }
        
        .card.total { border-top: 4px solid #3498db; }
        .card.passed { border-top: 4px solid #2ecc71; }
        .card.failed { border-top: 4px solid #e74c3c; }
        
        .card h3 {
            margin-top: 0;
            color: #2c3e50;
        }
        
        .card .number {
            font-size: 2.5em;
            font-weight: bold;
            margin: 10px 0;
        }
        
        .card.total .number { color: #3498db; }
        .card.passed .number { color: #2ecc71; }
        .card.failed .number { color: #e74c3c; }
        
        .reports-table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 20px;
        }
        
        .reports-table th,
        .reports-table td {
            padding: 12px 15px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }
        
        .reports-table th {
            background-color: #4CAF50;
            color: white;
            font-weight: bold;
        }
        
        .reports-table tr:hover {
            background-color: #f5f5f5;
        }
        
        .status-pass {
            background-color: #d4edda;
            color: #155724;
            padding: 5px 10px;
            border-radius: 4px;
            font-weight: bold;
        }
        
        .status-fail {
            background-color: #f8d7da;
            color: #721c24;
            padding: 5px 10px;
            border-radius: 4px;
            font-weight: bold;
        }
        
        .status-unknown {
            background-color: #fff3cd;
            color: #856404;
            padding: 5px 10px;
            border-radius: 4px;
            font-weight: bold;
        }
        
        footer {
            margin-top: 40px;
            text-align: center;
            color: #7f8c8d;
            font-size: 0.9em;
            border-top: 1px solid #eee;
            padding-top: 20px;
        }
        
        .system-info {
            background-color: #f8f9fa;
            padding: 20px;
            border-radius: 8px;
            margin-top: 30px;
        }
        
        @media (max-width: 768px) {
            .summary-cards {
                flex-direction: column;
            }
            
            .card {
                margin: 10px 0;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>📊 Отчет о тестировании операционной системы</h1>
            <p class="subtitle">Дата генерации: $(date '+%Y-%m-%d %H:%M:%S')</p>
        </header>
        
        <section class="summary-cards">
            <div class="card total">
                <h3>Всего отчетов</h3>
                <div class="number">$total_reports</div>
                <p>Найдено отчетов тестирования</p>
            </div>
            
            <div class="card passed">
                <h3>Пройдено успешно</h3>
                <div class="number">$passed_count</div>
                <p>Тестов с результатом PASS</p>
            </div>
            
            <div class="card failed">
                <h3>Не пройдено</h3>
                <div class="number">$failed_count</div>
                <p>Тестов с результатом FAIL</p>
            </div>
        </section>
        
        <section>
            <h2>📋 Детализация отчетов</h2>
EOF
    
    if [ $total_reports -eq 0 ]; then
        echo "<p>Нет доступных отчетов тестирования. Запустите тесты для генерации отчетов.</p>" >> "$report_file"
    else
        cat >> "$report_file" << EOF
            <table class="reports-table">
                <thead>
                    <tr>
                        <th>Тип теста</th>
                        <th>Файл отчета</th>
                        <th>Дата</th>
                        <th>Результат</th>
                        <th>Сообщение</th>
                    </tr>
                </thead>
                <tbody>
EOF
        
        for report in "${test_reports[@]}"; do
            local report_name=$(basename "$report")
            local test_type=$(echo "$report_name" | sed 's/_report_.*//')
            local report_date=$(grep "Дата:" "$report" | head -1 | cut -d: -f2- | sed 's/^[[:space:]]*//' || echo "Неизвестно")
            local test_result=$(grep "Результат:" "$report" | head -1 | cut -d: -f2- | sed 's/^[[:space:]]*//' || echo "Неизвестно")
            local test_message=$(grep "Сообщение:" "$report" | head -1 | cut -d: -f2- | sed 's/^[[:space:]]*//' || echo "Нет сообщения")
            
            # Определение класса статуса
            local status_class="status-unknown"
            if echo "$test_result" | grep -qi "PASS"; then
                status_class="status-pass"
            elif echo "$test_result" | grep -qi "FAIL"; then
                status_class="status-fail"
            fi
            
            cat >> "$report_file" << EOF
                    <tr>
                        <td><strong>$test_type</strong></td>
                        <td><code>$report_name</code></td>
                        <td>$report_date</td>
                        <td><span class="$status_class">$test_result</span></td>
                        <td>$test_message</td>
                    </tr>
EOF
        done
        
        cat >> "$report_file" << EOF
                </tbody>
            </table>
EOF
    fi
    
    cat >> "$report_file" << EOF
        </section>
        
        <section class="system-info">
            <h2>🖥️ Системная информация</h2>
            <p><strong>Операционная система:</strong> $(uname -s) $(uname -r)</p>
            <p><strong>Архитектура:</strong> $(uname -m)</p>
            <p><strong>Дата:</strong> $(date)</p>
            <p><strong>Каталог тестов:</strong> $TESTS_DIR</p>
            <p><strong>Каталог сборки:</strong> $BUILD_DIR</p>
EOF
    
    if command -v nasm &> /dev/null; then
        echo "            <p><strong>NASM:</strong> $(nasm --version | head -n1)</p>" >> "$report_file"
    else
        echo "            <p><strong>NASM:</strong> Не установлен</p>" >> "$report_file"
    fi
    
    if command -v qemu-system-i386 &> /dev/null; then
        echo "            <p><strong>QEMU:</strong> $(qemu-system-i386 --version | head -n1)</p>" >> "$report_file"
    else
        echo "            <p><strong>QEMU:</strong> Не установлен</p>" >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF
        </section>
        
        <footer>
            <p>Отчет сгенерирован автоматически системой тестирования ОС</p>
            <p>Версия генератора отчетов: 1.0</p>
        </footer>
    </div>
</body>
</html>
EOF
    
    log_success "HTML отчет создан: $report_file"
}

# Основная функция генерации отчетов
generate_all_reports() {
    log_info "=== ГЕНЕРАЦИЯ СВОДНЫХ ОТЧЕТОВ ==="
    
    # Создание каталога для отчетов
    mkdir -p "$REPORTS_DIR"
    
    # Генерация отчетов в разных форматах
    generate_text_report
    generate_json_report
    generate_html_report
    
    log_info "=== ОТЧЕТЫ УСПЕШНО СОЗДАНЫ ==="
    log_info "Текстовый отчет: $TEXT_REPORT"
    log_info "JSON отчет: $JSON_REPORT"
    log_info "HTML отчет: $HTML_REPORT"
    
    # Создание симлинка на последний отчет для удобства
    local latest_link="$REPORTS_DIR/latest_summary.html"
    rm -f "$latest_link" 2>/dev/null || true
    ln -s "$HTML_REPORT" "$latest_link" 2>/dev/null || cp "$HTML_REPORT" "$latest_link"
    
    log_success "Создан симлинк на последний отчет: $latest_link"
}

# Показать справку
show_help() {
    echo "Использование: $0 [формат]"
    echo ""
    echo "Форматы отчетов:"
    echo "  all        Создать все форматы отчетов (по умолчанию)"
    echo "  text       Только текстовый отчет"
    echo "  json       Только JSON отчет"
    echo "  html       Только HTML отчет"
    echo "  help       Показать эту справку"
    echo ""
    echo "Примеры:"
    echo "  $0 all     # Создать все форматы отчетов"
    echo "  $0 html    # Создать только HTML отчет"
    echo ""
}

# Обработка аргументов командной строки
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    # Скрипт запущен напрямую
    
    case "${1:-all}" in
        all)
            generate_all_reports
            ;;
        text)
            init_test_utils
            mkdir -p "$REPORTS_DIR"
            generate_text_report
            ;;
        json)
            init_test_utils
            mkdir -p "$REPORTS_DIR"
            generate_json_report
            ;;
        html)
            init_test_utils
            mkdir -p "$REPORTS_DIR"
            generate_html_report
            ;;
        help|--help|-h)
            show_help
            exit 0
            ;;
        *)
            log_error "Неизвестный формат: $1"
            show_help
            exit 1
            ;;
    esac
fi