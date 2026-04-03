# Сборка и запуск операционной системы

## Требования к окружению

Для сборки и запуска операционной системы необходимы следующие инструменты:

- NASM (Netwide Assembler) 3.01 или выше
- QEMU 10.0 или выше (рекомендуется 10.2.0)
- Bash или совместимая оболочка (для Linux/macOS)
- PowerShell 5.1+ (для Windows)
- Python 3.6+ (для скриптов преобразования кодировок)

### Установка на Ubuntu/Debian

```bash
sudo apt update
sudo apt install nasm qemu-system-x86 python3
```

### Установка на CentOS/RHEL/Fedora

```bash
sudo dnf install nasm qemu-system-x86 python3
```

### Установка на macOS

```bash
brew install nasm qemu python3
```

### Установка на Windows (нативный способ)

Для Windows доступны несколько вариантов установки:

1. **Портативный NASM** (рекомендуется):
   - Скачайте NASM 3.01 с официального сайта
   - Распакуйте в `os/tests/tools/nasm/`
   - Добавьте путь в переменную окружения PATH

2. **QEMU для Windows**:
   - Установите QEMU через установщик с официального сайта
   - По умолчанию устанавливается в `C:\Program Files\qemu\`

3. **Git Bash** (для Bash-скриптов):
   - Установите Git for Windows
   - Bash будет доступен по пути `C:\Program Files\Git\bin\bash.exe`

Для автоматической установки зависимостей используйте скрипт:

```powershell
# Запустите из каталога os/tests/scripts/
.\install_dependencies.ps1
```

## Сборка операционной системы

### Сборка на Linux/macOS (через Bash)

1. Перейдите в каталог `build`:

```bash
cd os/os/build
```

2. Запустите скрипт сборки:

```bash
./build.sh
```

3. После успешной сборки будут созданы файлы:
   - `boot.bin` - скомпилированный загрузчик
   - `kernel.bin` - скомпилированное ядро
   - `os.img` - загрузочный образ операционной системы

### Сборка на Windows (через PowerShell)

Для Windows доступны несколько скриптов сборки:

1. **Полная сборка с запуском** (рекомендуется):

```powershell
# Из каталога os/os/build/
.\build_and_run.ps1
```

Этот скрипт автоматически:
- Проверяет наличие NASM и QEMU
- Компилирует загрузчик и ядро
- Создаёт образ диска с поддержкой русского языка
- Запускает QEMU в отдельном окне

2. **Только сборка**:

```powershell
.\build.ps1
```

3. **Упрощённая сборка** (для тестирования):

```powershell
.\simple_build.ps1
```

### Поддержка русского языка

Для корректного отображения русского текста в QEMU строки кодируются в CP866:

1. Исходные строки в ассемблере представлены как последовательности байт CP866
2. Загрузчик (`boot.asm`) и ядро (`simple_kernel.asm`) используют русские строки
3. При сборке создаётся образ `os_cp866.img` с правильной кодировкой

Пример преобразования строки в CP866:

```python
text = 'Добро пожаловать в ОС на ассемблере!'
encoded = text.encode('cp866')
# Результат: 0x84,0xae,0xa1,0xe0,0xae,0x20,0xaf,0xae,0xa6,0xa0,0xab,0xae,0xa2,0xa0,0xe2,0xec,0x20,0xa2,0x20,0x8e,0x91,0x20,0xad,0xa0,0x20,0xa0,0xe1,0xe1,0xa5,0xac,0xa1,0xab,0xa5,0xe0,0xa5,0x21
```

## Запуск в эмуляторе

### Запуск в QEMU (базовый)

```bash
qemu-system-i386 -fda os/os/build/os.img
```

### Запуск с поддержкой русского языка

```bash
qemu-system-i386 -fda os/os/build/os_cp866.img
```

### Запуск в отдельном окне (Windows)

```powershell
# Скрипт build_and_run.ps1 автоматически запускает QEMU в отдельном окне
.\build_and_run.ps1
```

Или вручную:

```powershell
$qemuPath = "C:\Program Files\qemu\qemu-system-i386.exe"
$imagePath = "os_cp866.img"
Start-Process -FilePath $qemuPath -ArgumentList "-fda", $imagePath -WindowStyle Normal
```

### Запуск с отладкой

```bash
# Запуск QEMU в режиме отладки
qemu-system-i386 -fda os/os/build/os.img -s -S
```

Затем в другом терминале подключитесь через GDB:

```bash
gdb
(gdb) target remote localhost:1234
(gdb) symbol-file os/os/build/kernel.sym
```

### Расширенные опции запуска

Для более гибкого запуска используйте утилиту `qemu_runner.sh` из тестового окружения:

```bash
# Из каталога os/tests/utils/
./qemu_runner.sh --image ../../os/os/build/os_cp866.img --timeout 30 --log qemu.log
```

Доступные опции:
- `--image` - путь к образу
- `--timeout` - таймаут в секундах
- `--log` - файл для логов QEMU
- `--debug` - запуск в режиме отладки

## Интеграция с тестовым окружением

Операционная система интегрирована с комплексным тестовым окружением:

### Запуск всех тестов

```bash
# Из каталога os/tests/scripts/
./run_test.sh --all
```

Скрипт автоматически:
1. Проверяет окружение
2. Собирает ОС (если нужно)
3. Запускает юнит-тесты, интеграционные тесты и тесты производительности
4. Генерирует отчёты в формате HTML, JSON и текстовом

### Запуск конкретных тестов

```bash
# Только тесты загрузчика
./run_test.sh --unit bootloader

# Только тесты драйверов
./run_test.sh --unit drivers

# Интеграционные тесты
./run_test.sh --integration filesystem
./run_test.sh --integration network

# Тесты производительности
./run_test.sh --performance
```

### Генерация отчётов

После запуска тестов отчёты сохраняются в `os/tests/results/`:

- `summary_report.txt` - текстовый отчёт
- `test_results.json` - результаты в формате JSON
- `test_report.html` - визуальный HTML-отчёт

## Структура проекта

```
os/os/
├── src/
│   ├── boot/
│   │   └── boot.asm              # Загрузчик (16-битный реальный режим)
│   └── kernel/
│       ├── kernel.asm            # Основное ядро (32-битный защищённый режим)
│       ├── simple_kernel.asm     # Упрощённое ядро для тестирования
│       ├── keyboard.asm          # Драйвер клавиатуры с буфером
│       └── ...                   # Другие модули ядра
├── build/
│   ├── build.sh                  # Скрипт сборки для Linux/macOS
│   ├── build.ps1                 # Скрипт сборки для Windows
│   ├── build_and_run.ps1         # Скрипт сборки и запуска для Windows
│   ├── simple_build.ps1          # Упрощённый скрипт сборки
│   ├── boot.bin                  # Скомпилированный загрузчик
│   ├── kernel.bin                # Скомпилированное ядро
│   ├── os.img                    # Загрузочный образ (английский)
│   └── os_cp866.img              # Загрузочный образ с русским языком
├── docs/
│   ├── build_and_run.md          # Эта документация
│   └── kernel_architecture.md    # Архитектура ядра
└── tests/                        # Тестовое окружение
    ├── scripts/
    │   ├── run_test.sh           # Основной скрипт запуска тестов
    │   └── generate_summary_report.sh  # Генератор отчётов
    ├── utils/
    │   ├── qemu_runner.sh        # Утилита запуска QEMU
    │   └── test_utils.sh         # Общие функции тестирования
    ├── unit/                     # Юнит-тесты
    ├── integration/              # Интеграционные тесты
    ├── performance/              # Тесты производительности
    └── results/                  # Результаты тестов
```

## Устранение неполадок

### Ошибка "command not found: nasm"

**Решение для Windows:**
1. Убедитесь, что портативный NASM распакован в `os/tests/tools/nasm/`
2. Добавьте путь в переменную окружения PATH:
   ```powershell
   $env:Path += ";$PWD\os\tests\tools\nasm"
   ```
3. Или используйте скрипты сборки, которые автоматически находят NASM

**Решение для Linux/macOS:**
```bash
sudo apt install nasm  # Ubuntu/Debian
sudo dnf install nasm  # CentOS/RHEL/Fedora
brew install nasm      # macOS
```

### Ошибка "command not found: qemu-system-i386"

**Решение:**
1. Установите QEMU согласно инструкциям выше
2. На Windows проверьте путь установки: `C:\Program Files\qemu\`
3. Добавьте QEMU в PATH или укажите полный путь в скриптах

### Загрузчик не запускается

1. Проверьте размер загрузчика (должен быть 512 байт)
2. Убедитесь, что сигнатура загрузчика (0xaa55) присутствует в конце
3. Проверьте вывод в эмуляторе на наличие ошибок
4. Убедитесь, что образ имеет правильный размер (1.44 МБ = 1474560 байт)

### Русский текст отображается некорректно

1. Убедитесь, что используется образ `os_cp866.img`
2. Проверьте, что строки в ассемблере закодированы в CP866
3. QEMU должен использовать текстовый режим VGA (по умолчанию)

### Ошибка дублирования меток в kernel.asm

Если возникает ошибка "symbol already defined" для `exception_handler_0` и `exception_handler_1`:

1. Удалите явные определения этих обработчиков в `kernel.asm`
2. Оставьте только макрос `%rep 32` для генерации всех обработчиков
3. Или используйте упрощённое ядро `simple_kernel.asm` для тестирования

### Проблемы с правами доступа (Linux/macOS)

```bash
# Дайте права на выполнение скриптам
chmod +x os/os/build/build.sh
chmod +x os/tests/scripts/*.sh
chmod +x os/tests/utils/*.sh
```

## Дополнительные ресурсы

- [Документация тестового окружения](os/tests/README.md)
- [Архитектура ядра](os/os/docs/kernel_architecture.md)
- [План улучшений ядра](os/kernel_todo_list.md)
- [Журнал разработки](os/WORKLOG.md)

## Лицензия

Этот проект распространяется под лицензией MIT. Подробности см. в файле LICENSE.