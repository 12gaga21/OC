# Скрипт установки портативных версий зависимостей для тестового окружения ОС
# Устанавливает NASM и QEMU в локальную папку проекта без прав администратора

Write-Host "=== Установка портативных зависимостей для тестового окружения ОС ===" -ForegroundColor Cyan
Write-Host "Дата: $(Get-Date)"
Write-Host ""

# Пути установки
$toolsDir = "$PSScriptRoot\tools"
$nasmDir = "$toolsDir\nasm"
$qemuDir = "$toolsDir\qemu"

# Создаем каталоги
New-Item -ItemType Directory -Force -Path $toolsDir, $nasmDir, $qemuDir | Out-Null

# Функция для добавления пути в PATH текущей сессии
function Add-ToSessionPath {
    param([string]$PathToAdd)
    if ($env:PATH -split ';' -notcontains $PathToAdd) {
        $env:PATH = "$PathToAdd;$env:PATH"
        Write-Host "   Добавлен $PathToAdd в PATH текущей сессии" -ForegroundColor Green
        return $true
    } else {
        Write-Host "   Путь $PathToAdd уже присутствует в PATH" -ForegroundColor Yellow
        return $false
    }
}

# 1. Установка NASM
Write-Host "1. Установка NASM (портативная версия)..." -ForegroundColor Yellow

$nasmUrl = "https://www.nasm.us/pub/nasm/releasebuilds/3.01/win64/nasm-3.01-win64.zip"
$nasmZip = "$toolsDir\nasm.zip"
$nasmExePath = "$nasmDir\nasm.exe"

if (Test-Path $nasmExePath) {
    Write-Host "   ✓ NASM уже установлен в $nasmDir" -ForegroundColor Green
} else {
    Write-Host "   Скачивание NASM с $nasmUrl ..." -ForegroundColor Yellow
    try {
        Invoke-WebRequest -Uri $nasmUrl -OutFile $nasmZip -ErrorAction Stop
        Write-Host "   ✓ NASM скачан" -ForegroundColor Green
        
        # Распаковка
        Write-Host "   Распаковка NASM..." -ForegroundColor Yellow
        Expand-Archive -Path $nasmZip -DestinationPath $nasmDir -Force
        # В архиве есть подпапка nasm-3.01, перемещаем файлы
        $subDir = Get-ChildItem -Path $nasmDir -Directory -Filter "nasm-*" | Select-Object -First 1
        if ($subDir) {
            Move-Item -Path "$subDir\*" -Destination $nasmDir -Force
            Remove-Item -Path $subDir -Force -Recurse
        }
        
        Write-Host "   ✓ NASM распакован в $nasmDir" -ForegroundColor Green
    } catch {
        Write-Host "   ✗ Ошибка скачивания NASM: $_" -ForegroundColor Red
        Write-Host "   Альтернативный вариант: установите NASM вручную с https://www.nasm.us/" -ForegroundColor Yellow
    }
}

if (Test-Path $nasmExePath) {
    Add-ToSessionPath -PathToAdd $nasmDir
    Write-Host "   Проверка NASM..." -ForegroundColor Yellow
    & $nasmExePath --version 2>&1 | Select-Object -First 1
}

# 2. Установка QEMU
Write-Host ""
Write-Host "2. Установка QEMU (портативная версия)..." -ForegroundColor Yellow

# Используем QEMU 8.2.0 для Windows 64-bit (портативная версия)
$qemuUrl = "https://qemu.weilnetz.de/w64/qemu-w64-setup-20231215.exe"
$qemuInstaller = "$toolsDir\qemu-setup.exe"
$qemuExePath = "$qemuDir\qemu-system-i386.exe"

if (Test-Path $qemuExePath) {
    Write-Host "   ✓ QEMU уже установлен в $qemuDir" -ForegroundColor Green
} else {
    Write-Host "   Скачивание QEMU установщика..." -ForegroundColor Yellow
    try {
        Invoke-WebRequest -Uri $qemuUrl -OutFile $qemuInstaller -ErrorAction Stop
        Write-Host "   ✓ QEMU установщик скачан" -ForegroundColor Green
        
        Write-Host "   Запуск установщика QEMU в портативном режиме..." -ForegroundColor Yellow
        Write-Host "   Пожалуйста, в открывшемся окне установщика выберите путь: $qemuDir" -ForegroundColor Cyan
        Write-Host "   И снимите галочку 'Add to PATH' (мы добавим путь сами)" -ForegroundColor Cyan
        Write-Host ""
        
        # Запускаем установщик и ждем завершения
        $process = Start-Process -FilePath $qemuInstaller -ArgumentList "/S /D=$qemuDir" -Wait -PassThru
        if ($process.ExitCode -eq 0) {
            Write-Host "   ✓ QEMU установлен в $qemuDir" -ForegroundColor Green
        } else {
            Write-Host "   ✗ Установщик QEMU завершился с ошибкой" -ForegroundColor Red
        }
    } catch {
        Write-Host "   ✗ Ошибка скачивания QEMU: $_" -ForegroundColor Red
        Write-Host "   Альтернативный вариант: установите QEMU вручную с https://www.qemu.org/download/" -ForegroundColor Yellow
    }
}

# Поиск qemu-system-i386.exe в установленной папке
if (Test-Path $qemuDir) {
    $foundQemu = Get-ChildItem -Path $qemuDir -Recurse -Filter "qemu-system-i386.exe" | Select-Object -First 1
    if ($foundQemu) {
        $qemuDir = $foundQemu.DirectoryName
        Add-ToSessionPath -PathToAdd $qemuDir
        Write-Host "   Проверка QEMU..." -ForegroundColor Yellow
        & $foundQemu.FullName --version 2>&1 | Select-Object -First 1
    }
}

# 3. Проверка Bash
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

if ($bashFound) {
    Write-Host "   ✓ Git Bash найден: $bashPath" -ForegroundColor Green
    $bashDir = Split-Path $bashPath -Parent
    Add-ToSessionPath -PathToAdd $bashDir
} else {
    Write-Host "   ✗ Bash не найден" -ForegroundColor Red
    Write-Host "   Установите Git Bash с https://git-scm.com/downloads" -ForegroundColor Yellow
}

# Итоговая проверка
Write-Host ""
Write-Host "=== ИТОГОВАЯ ПРОВЕРКА ===" -ForegroundColor Cyan

$nasmOk = Test-Path $nasmExePath
$qemuOk = Test-Path $qemuExePath
$bashOk = $bashFound

Write-Host "NASM: $(if ($nasmOk) { '✓ Установлен' } else { '✗ Отсутствует' })" -ForegroundColor $(if ($nasmOk) { 'Green' } else { 'Red' })
Write-Host "QEMU: $(if ($qemuOk) { '✓ Установлен' } else { '✗ Отсутствует' })" -ForegroundColor $(if ($qemuOk) { 'Green' } else { 'Red' })
Write-Host "Bash: $(if ($bashOk) { '✓ Найден' } else { '✗ Отсутствует' })" -ForegroundColor $(if ($bashOk) { 'Green' } else { 'Red' })

if ($nasmOk -and $qemuOk -and $bashOk) {
    Write-Host ""
    Write-Host "✅ Все зависимости успешно установлены в локальную папку!" -ForegroundColor Green
    Write-Host "Пути добавлены в PATH текущей сессии." -ForegroundColor Green
    Write-Host ""
    Write-Host "Для постоянного добавления в PATH добавьте следующие пути в переменную PATH пользователя:" -ForegroundColor Cyan
    Write-Host "  - $nasmDir" -ForegroundColor White
    Write-Host "  - $qemuDir" -ForegroundColor White
    Write-Host "  - $bashDir" -ForegroundColor White
} else {
    Write-Host ""
    Write-Host "⚠️  Не все зависимости установлены." -ForegroundColor Yellow
    Write-Host "Рекомендуется установить отсутствующие компоненты вручную." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Дополнительная информация ===" -ForegroundColor Cyan
Write-Host "  - Документация по тестированию: os/tests/README.md" -ForegroundColor White
Write-Host "  - Основной тестовый скрипт: os/tests/scripts/run_test.sh" -ForegroundColor White

Write-Host ""
Write-Host "=== Скрипт завершен ===" -ForegroundColor Cyan