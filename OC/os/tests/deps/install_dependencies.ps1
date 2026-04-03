# Скрипт установки зависимостей для тестового окружения ОС
# Этот скрипт помогает установить NASM, QEMU и настроить Bash

Write-Host "=== Установка зависимостей для тестового окружения ОС ===" -ForegroundColor Cyan
Write-Host "Дата: $(Get-Date)"
Write-Host ""

# Проверка текущих прав
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "ВНИМАНИЕ: Скрипт запущен без прав администратора" -ForegroundColor Yellow
    Write-Host "   Некоторые зависимости могут требовать прав администратора для установки" -ForegroundColor Yellow
    Write-Host "   Рекомендуется запустить PowerShell от имени администратора" -ForegroundColor Yellow
    Write-Host ""
}

# 1. Проверка и установка NASM
Write-Host "1. Проверка NASM..." -ForegroundColor Yellow
$nasmFound = $false
try {
    $nasmVersion = & nasm --version 2>&1 | Select-Object -First 1
    if ($nasmVersion -like "*NASM*") {
        Write-Host "   ✓ NASM уже установлен: $nasmVersion" -ForegroundColor Green
        $nasmFound = $true
    }
} catch {
    # NASM не найден
}

if (-not $nasmFound) {
    Write-Host "   ✗ NASM не найден" -ForegroundColor Red
    Write-Host ""
    Write-Host "   Варианты установки NASM:" -ForegroundColor Cyan
    Write-Host "   A. Скачать с официального сайта:" -ForegroundColor White
    Write-Host "      1. Перейдите на https://www.nasm.us/" -ForegroundColor White
    Write-Host "      2. Скачайте последнюю версию для Windows" -ForegroundColor White
    Write-Host "      3. Запустите установщик и добавьте NASM в PATH" -ForegroundColor White
    Write-Host ""
    Write-Host "   B. Использовать Chocolatey (требует прав администратора):" -ForegroundColor White
    Write-Host "      choco install nasm -y" -ForegroundColor White
    Write-Host ""
    Write-Host "   C. Использовать winget (рекомендуется):" -ForegroundColor White
    Write-Host "      winget install NASM.NASM" -ForegroundColor White
    Write-Host ""
}

# 2. Проверка и установка QEMU
Write-Host ""
Write-Host "2. Проверка QEMU..." -ForegroundColor Yellow
$qemuFound = $false
try {
    $qemuVersion = & qemu-system-i386 --version 2>&1 | Select-Object -First 1
    if ($qemuVersion -like "*QEMU*") {
        Write-Host "   ✓ QEMU уже установлен: $qemuVersion" -ForegroundColor Green
        $qemuFound = $true
    }
} catch {
    # Попробовать найти просто qemu
    try {
        $qemuVersion = & qemu --version 2>&1 | Select-Object -First 1
        if ($qemuVersion -like "*QEMU*") {
            Write-Host "   ✓ QEMU уже установлен (альтернативная команда): $qemuVersion" -ForegroundColor Green
            $qemuFound = $true
        }
    } catch {
        # QEMU не найден
    }
}

if (-not $qemuFound) {
    Write-Host "   ✗ QEMU не найден" -ForegroundColor Red
    Write-Host ""
    Write-Host "   Варианты установки QEMU:" -ForegroundColor Cyan
    Write-Host "   A. Скачать с официального сайта:" -ForegroundColor White
    Write-Host "      1. Перейдите на https://www.qemu.org/download/" -ForegroundColor White
    Write-Host "      2. Скачайте установщик для Windows" -ForegroundColor White
    Write-Host "      3. Запустите установщик и добавьте QEMU в PATH" -ForegroundColor White
    Write-Host ""
    Write-Host "   B. Использовать Chocolatey (требует прав администратора):" -ForegroundColor White
    Write-Host "      choco install qemu -y" -ForegroundColor White
    Write-Host ""
    Write-Host "   C. Использовать winget:" -ForegroundColor White
    Write-Host "      winget install SoftwareFreedomConservancy.QEMU" -ForegroundColor White
    Write-Host ""
}

# 3. Проверка и настройка Bash
Write-Host ""
Write-Host "3. Проверка Bash..." -ForegroundColor Yellow
$bashFound = $false
$bashPath = ""

# Проверка Git Bash
$gitBashPaths = @(
    "C:\Program Files\Git\bin\bash.exe",
    "C:\Program Files (x86)\Git\bin\bash.exe",
    "$env:USERPROFILE\AppData\Local\Programs\Git\bin\bash.exe"
)

foreach ($path in $gitBashPaths) {
    if (Test-Path $path) {
        $bashPath = $path
        $bashFound = $true
        break
    }
}

# Проверка WSL
if (-not $bashFound) {
    try {
        $wslVersion = & wsl --version 2>&1 | Select-Object -First 1
        if ($wslVersion -like "*WSL*") {
            Write-Host "   ✓ WSL обнаружен: $wslVersion" -ForegroundColor Green
            $bashFound = $true
        }
    } catch {
        # WSL не найден
    }
}

if ($bashFound) {
    if ($bashPath -ne "") {
        Write-Host "   ✓ Git Bash найден: $bashPath" -ForegroundColor Green
        Write-Host ""
        Write-Host "   Для использования Git Bash в тестах:" -ForegroundColor Cyan
        Write-Host "   1. Добавьте каталог в переменную PATH:" -ForegroundColor White
        Write-Host "      [System.Environment]::SetEnvironmentVariable('PATH', `"$((Get-Item $bashPath).DirectoryName);$env:PATH`", 'User')" -ForegroundColor White
        Write-Host "   2. Перезапустите терминал или выполните:" -ForegroundColor White
        Write-Host "      `$env:PATH = `"$((Get-Item $bashPath).DirectoryName);$env:PATH`"" -ForegroundColor White
    } else {
        Write-Host "   ✓ Bash доступен через WSL" -ForegroundColor Green
    }
} else {
    Write-Host "   ✗ Bash не найден" -ForegroundColor Red
    Write-Host ""
    Write-Host "   Варианты установки Bash:" -ForegroundColor Cyan
    Write-Host "   A. Установить Git Bash (рекомендуется):" -ForegroundColor White
    Write-Host "      1. Скачайте с https://git-scm.com/downloads" -ForegroundColor White
    Write-Host "      2. Запустите установщик" -ForegroundColor White
    Write-Host "      3. В настройках установки выберите 'Add to PATH'" -ForegroundColor White
    Write-Host ""
    Write-Host "   B. Установить WSL2:" -ForegroundColor White
    Write-Host "      1. Выполните в PowerShell от имени администратора:" -ForegroundColor White
    Write-Host "         wsl --install" -ForegroundColor White
    Write-Host "      2. Перезагрузите компьютер" -ForegroundColor White
    Write-Host ""
}

# 4. Проверка Chocolatey
Write-Host ""
Write-Host "4. Проверка Chocolatey..." -ForegroundColor Yellow
$chocoFound = $false
try {
    $chocoVersion = & choco --version 2>&1
    if ($chocoVersion -match "\d+\.\d+") {
        Write-Host "   ✓ Chocolatey уже установлен: v$chocoVersion" -ForegroundColor Green
        $chocoFound = $true
    }
} catch {
    # Chocolatey не найден
}

if (-not $chocoFound) {
    Write-Host "   ℹ Chocolatey не установлен" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "   Chocolatey - менеджер пакетов для Windows" -ForegroundColor Cyan
    Write-Host "   Установка (требует PowerShell от имени администратора):" -ForegroundColor White
    Write-Host "   Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))" -ForegroundColor White
    Write-Host ""
}

# 5. Проверка winget
Write-Host ""
Write-Host "5. Проверка winget..." -ForegroundColor Yellow
$wingetFound = $false
try {
    $wingetVersion = & winget --version 2>&1
    if ($wingetVersion -match "\d+\.\d+") {
        Write-Host "   ✓ winget уже установлен: $wingetVersion" -ForegroundColor Green
        $wingetFound = $true
    }
} catch {
    # winget не найден
}

if (-not $wingetFound) {
    Write-Host "   ℹ winget не установлен" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "   winget - встроенный менеджер пакетов Windows" -ForegroundColor Cyan
    Write-Host "   Обычно предустановлен в Windows 10/11. Если отсутствует:" -ForegroundColor White
    Write-Host "   Установите из Microsoft Store: https://apps.microsoft.com/store/detail/app-installer/9NBLGGH4NNS1" -ForegroundColor White
    Write-Host ""
}

# Итоговые рекомендации
Write-Host ""
Write-Host "=== ИТОГОВЫЕ РЕКОМЕНДАЦИИ ===" -ForegroundColor Cyan

$missingCount = 0
if (-not $nasmFound) { $missingCount++ }
if (-not $qemuFound) { $missingCount++ }
if (-not $bashFound) { $missingCount++ }

if ($missingCount -eq 0) {
    Write-Host "✅ Все зависимости установлены!" -ForegroundColor Green
    Write-Host "Тестовое окружение готово к использованию." -ForegroundColor Green
} else {
    Write-Host "⚠️  Отсутствуют $missingCount зависимостей" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Рекомендуемый порядок установки:" -ForegroundColor Cyan
    Write-Host "1. Установите Git Bash для получения Bash" -ForegroundColor White
    Write-Host "2. Установите NASM с помощью winget или скачайте установщик" -ForegroundColor White
    Write-Host "3. Установите QEMU с помощью winget или скачайте установщик" -ForegroundColor White
    Write-Host ""
    Write-Host "После установки выполните проверку окружения:" -ForegroundColor Cyan
    Write-Host "powershell -ExecutionPolicy Bypass -File os/tests/scripts/check_environment.ps1" -ForegroundColor White
}

Write-Host ""
Write-Host "=== Дополнительная информация ===" -ForegroundColor Cyan
Write-Host "  - Документация по тестированию: os/tests/README.md" -ForegroundColor White
Write-Host "  - Основной тестовый скрипт: os/tests/scripts/run_test.sh" -ForegroundColor White
Write-Host "  - Конфигурация тестов: os/tests/config/test_config.yaml" -ForegroundColor White

Write-Host ""
Write-Host "=== Скрипт завершен ===" -ForegroundColor Cyan