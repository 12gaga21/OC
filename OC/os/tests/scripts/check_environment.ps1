# Скрипт проверки тестового окружения для Windows
# Проверяет наличие зависимостей и структуру файлов

Write-Host "=== Проверка тестового окружения ОС ===" -ForegroundColor Cyan
Write-Host "Дата проверки: $(Get-Date)"
Write-Host ""

# Проверка структуры каталогов
Write-Host "1. Проверка структуры каталогов..." -ForegroundColor Yellow
$requiredDirs = @(
    "os/tests",
    "os/tests/unit",
    "os/tests/integration", 
    "os/tests/performance",
    "os/tests/scripts",
    "os/tests/utils",
    "os/tests/config",
    "os/tests/results"
)

$allDirsExist = $true
foreach ($dir in $requiredDirs) {
    if (Test-Path $dir -PathType Container) {
        Write-Host "  ✓ $dir" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $dir (отсутствует)" -ForegroundColor Red
        $allDirsExist = $false
    }
}

if ($allDirsExist) {
    Write-Host "  Все каталоги существуют" -ForegroundColor Green
} else {
    Write-Host "  Некоторые каталоги отсутствуют" -ForegroundColor Yellow
}

# Проверка основных скриптов
Write-Host ""
Write-Host "2. Проверка основных скриптов..." -ForegroundColor Yellow
$requiredScripts = @(
    "os/tests/scripts/run_test.sh",
    "os/tests/scripts/generate_summary_report.sh",
    "os/tests/utils/qemu_runner.sh",
    "os/tests/utils/test_utils.sh",
    "os/tests/unit/bootloader_test.sh",
    "os/tests/unit/drivers_test.sh",
    "os/tests/integration/filesystem_test.sh",
    "os/tests/integration/network_test.sh",
    "os/tests/config/test_config.yaml",
    "os/tests/README.md"
)

$allScriptsExist = $true
foreach ($script in $requiredScripts) {
    if (Test-Path $script -PathType Leaf) {
        Write-Host "  ✓ $(Split-Path $script -Leaf)" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $(Split-Path $script -Leaf) (отсутствует)" -ForegroundColor Red
        $allScriptsExist = $false
    }
}

if ($allScriptsExist) {
    Write-Host "  Все основные скрипты существуют" -ForegroundColor Green
} else {
    Write-Host "  Некоторые скрипты отсутствуют" -ForegroundColor Yellow
}

# Проверка зависимостей
Write-Host ""
Write-Host "3. Проверка зависимостей..." -ForegroundColor Yellow

# Проверка NASM
$nasmFound = $false
$nasmPath = ""

# Проверка локальной установки NASM
$localNasm = "os/tests/tools/nasm/nasm.exe"
if (Test-Path $localNasm) {
    $nasmPath = $localNasm
    $nasmFound = $true
    $nasmVersion = & $localNasm --version 2>&1 | Select-Object -First 1
    Write-Host "  ✓ NASM (локальный): $nasmVersion" -ForegroundColor Green
} else {
    # Проверка глобальной установки NASM
    try {
        $nasmVersion = & nasm --version 2>&1 | Select-Object -First 1
        if ($nasmVersion -like "*NASM*") {
            Write-Host "  ✓ NASM (глобальный): $nasmVersion" -ForegroundColor Green
            $nasmFound = $true
        }
    } catch {
        Write-Host "  ✗ NASM не найден" -ForegroundColor Red
    }
}

# Проверка QEMU
$qemuFound = $false
try {
    $qemuVersion = & qemu-system-i386 --version 2>&1 | Select-Object -First 1
    if ($qemuVersion -like "*QEMU*") {
        Write-Host "  ✓ QEMU: $qemuVersion" -ForegroundColor Green
        $qemuFound = $true
    }
} catch {
    # Попробовать найти просто qemu
    try {
        $qemuVersion = & qemu --version 2>&1 | Select-Object -First 1
        if ($qemuVersion -like "*QEMU*") {
            Write-Host "  ✓ QEMU (альтернативная команда): $qemuVersion" -ForegroundColor Green
            $qemuFound = $true
        }
    } catch {
        Write-Host "  ✗ QEMU не найден" -ForegroundColor Red
    }
}

# Проверка Bash (WSL или Git Bash)
$bashFound = $false
try {
    $bashVersion = & bash --version 2>&1 | Select-Object -First 1
    if ($bashVersion -like "*bash*") {
        Write-Host "  ✓ Bash: $($bashVersion.Split([Environment]::NewLine)[0])" -ForegroundColor Green
        $bashFound = $true
    }
} catch {
    Write-Host "  ✗ Bash не найден (требуется WSL или Git Bash)" -ForegroundColor Red
}

# Проверка каталога сборки
Write-Host ""
Write-Host "4. Проверка каталога сборки..." -ForegroundColor Yellow
$buildDir = "os/os/build"
if (Test-Path $buildDir -PathType Container) {
    Write-Host "  ✓ Каталог сборки существует: $buildDir" -ForegroundColor Green
    
    # Проверка скриптов сборки
    $buildScripts = @("build.ps1", "build.sh")
    foreach ($script in $buildScripts) {
        $scriptPath = Join-Path $buildDir $script
        if (Test-Path $scriptPath -PathType Leaf) {
            Write-Host "    ✓ $(Split-Path $scriptPath -Leaf)" -ForegroundColor Green
        } else {
            Write-Host "    ✗ $(Split-Path $scriptPath -Leaf) (отсутствует)" -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "  ✗ Каталог сборки отсутствует: $buildDir" -ForegroundColor Red
}

# Итоговая оценка
Write-Host ""
Write-Host "=== ИТОГИ ПРОВЕРКИ ===" -ForegroundColor Cyan

$missingDeps = @()
if (-not $nasmFound) { $missingDeps += "NASM" }
if (-not $qemuFound) { $missingDeps += "QEMU" }
if (-not $bashFound) { $missingDeps += "Bash (WSL/Git Bash)" }

if ($missingDeps.Count -eq 0) {
    Write-Host "✅ Все зависимости установлены!" -ForegroundColor Green
    Write-Host "Тестовое окружение готово к использованию." -ForegroundColor Green
    Write-Host "Для запуска тестов выполните:" -ForegroundColor Yellow
    Write-Host "  cd os/tests/scripts" -ForegroundColor White
    Write-Host "  ./run_test.sh bootloader    # Тестирование загрузчика" -ForegroundColor White
    Write-Host "  ./run_test.sh all           # Все тесты" -ForegroundColor White
} else {
    Write-Host "⚠️  Отсутствуют зависимости: $($missingDeps -join ', ')" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Инструкции по установке:" -ForegroundColor Cyan
    
    if ($missingDeps -contains "NASM") {
        Write-Host ""
        Write-Host "Установка NASM:" -ForegroundColor Yellow
        Write-Host "  1. Скачайте с https://www.nasm.us/" -ForegroundColor White
        Write-Host "  2. Установите и добавьте в PATH" -ForegroundColor White
        Write-Host "  3. Или используйте Chocolatey: choco install nasm" -ForegroundColor White
    }
    
    if ($missingDeps -contains "QEMU") {
        Write-Host ""
        Write-Host "Установка QEMU:" -ForegroundColor Yellow
        Write-Host "  1. Скачайте с https://www.qemu.org/download/" -ForegroundColor White
        Write-Host "  2. Установите и добавьте в PATH" -ForegroundColor White
        Write-Host "  3. Или используйте Chocolatey: choco install qemu" -ForegroundColor White
    }
    
    if ($missingDeps -contains "Bash (WSL/Git Bash)") {
        Write-Host ""
        Write-Host "Установка Bash:" -ForegroundColor Yellow
        Write-Host "  Вариант 1: Установите WSL2:" -ForegroundColor White
        Write-Host "    wsl --install" -ForegroundColor White
        Write-Host "  Вариант 2: Установите Git Bash:" -ForegroundColor White
        Write-Host "    Скачайте с https://git-scm.com/downloads" -ForegroundColor White
    }
    
    Write-Host ""
    Write-Host "После установки зависимостей перезапустите проверку." -ForegroundColor Cyan
}

Write-Host ""
Write-Host "Дополнительная информация:" -ForegroundColor Cyan
Write-Host "  - Документация: os/tests/README.md" -ForegroundColor White
Write-Host "  - Конфигурация: os/tests/config/test_config.yaml" -ForegroundColor White
Write-Host "  - Результаты тестов: os/tests/results/" -ForegroundColor White

Write-Host ""
Write-Host "=== Проверка завершена ===" -ForegroundColor Cyan