# Скрипт сборки и запуска ОС для Windows
# Автоматически собирает и запускает ОС в QEMU

$ErrorActionPreference = "Stop"

# Пути к инструментам
$nasmPath = Join-Path (Join-Path (Join-Path (Join-Path $PSScriptRoot "..") "..") "tests") "tools\nasm\nasm.exe"
$qemuPath = "C:\Program Files\qemu\qemu-system-i386.exe"
$scriptDir = $PSScriptRoot
$srcDir = Join-Path (Join-Path $scriptDir "..") "src"
$buildDir = Join-Path (Join-Path $scriptDir "..") "build"

# Проверка наличия инструментов
if (-not (Test-Path $nasmPath)) {
    Write-Host "Ошибка: NASM не найден по пути $nasmPath" -ForegroundColor Red
    Write-Host "Убедитесь, что зависимости установлены (запустите os/tests/scripts/check_environment.ps1)" -ForegroundColor Yellow
    exit 1
}

if (-not (Test-Path $qemuPath)) {
    Write-Host "Ошибка: QEMU не найден по пути $qemuPath" -ForegroundColor Red
    Write-Host "Установите QEMU или укажите правильный путь" -ForegroundColor Yellow
    exit 1
}

Write-Host "=== Сборка операционной системы ===" -ForegroundColor Cyan

# Создание каталога для сборки
if (-not (Test-Path $buildDir)) {
    New-Item -ItemType Directory -Path $buildDir -Force | Out-Null
    Write-Host "Создан каталог сборки: $buildDir"
}

# 1. Компиляция загрузчика
Write-Host "1. Компиляция загрузчика..." -ForegroundColor Green
$bootAsm = Join-Path (Join-Path $srcDir "boot") "boot.asm"
$bootBin = Join-Path $buildDir "boot.bin"

& $nasmPath -f bin $bootAsm -o $bootBin
if ($LASTEXITCODE -ne 0) {
    Write-Host "Ошибка компиляции загрузчика!" -ForegroundColor Red
    exit 1
}
Write-Host "   Загрузчик успешно скомпилирован: $bootBin"

# 2. Компиляция ядра (используем простое ядро для тестирования)
Write-Host "2. Компиляция ядра..." -ForegroundColor Green
$kernelAsm = Join-Path (Join-Path $srcDir "kernel") "simple_kernel.asm"
$kernelBin = Join-Path $buildDir "simple_kernel.bin"

if (-not (Test-Path $kernelAsm)) {
    Write-Host "   Простое ядро не найдено, используем основное ядро..." -ForegroundColor Yellow
    $kernelAsm = Join-Path (Join-Path $srcDir "kernel") "kernel.asm"
    $kernelBin = Join-Path $buildDir "kernel.bin"
}

& $nasmPath -f bin $kernelAsm -o $kernelBin
if ($LASTEXITCODE -ne 0) {
    Write-Host "Ошибка компиляции ядра!" -ForegroundColor Red
    Write-Host "   Попробуйте исправить ошибки в $kernelAsm" -ForegroundColor Yellow
    exit 1
}
Write-Host "   Ядро успешно скомпилировано: $kernelBin"

# 3. Создание загрузочного образа
Write-Host "3. Создание загрузочного образа..." -ForegroundColor Green
$osImg = Join-Path $buildDir "os.img"

# Копируем загрузчик
Copy-Item $bootBin -Destination $osImg -Force

# Добавляем ядро
$kernelBytes = [System.IO.File]::ReadAllBytes($kernelBin)
$osBytes = [System.IO.File]::ReadAllBytes($osImg)
$combinedBytes = $osBytes + $kernelBytes
[System.IO.File]::WriteAllBytes($osImg, $combinedBytes)

# Заполнение до 1.44MB
$targetSize = 1440 * 1024
$currentSize = (Get-Item $osImg).Length
$paddingSize = $targetSize - $currentSize

if ($paddingSize -gt 0) {
    $padding = New-Object byte[] $paddingSize
    $finalBytes = [System.IO.File]::ReadAllBytes($osImg) + $padding
    [System.IO.File]::WriteAllBytes($osImg, $finalBytes)
    Write-Host "   Добавлено $paddingSize байт заполнения"
}

if (Test-Path $osImg) {
    $finalSize = (Get-Item $osImg).Length
    Write-Host "   Загрузочный образ успешно создан: $osImg" -ForegroundColor Green
    Write-Host "   Размер образа: $finalSize байт"
} else {
    Write-Host "Ошибка создания загрузочного образа!" -ForegroundColor Red
    exit 1
}

Write-Host "`n=== Запуск ОС в QEMU ===" -ForegroundColor Cyan
Write-Host "Запуск QEMU с образом $osImg" -ForegroundColor Yellow
Write-Host "Для выхода из QEMU нажмите Ctrl+C или закройте окно" -ForegroundColor Yellow
Write-Host "`nОжидаемый вывод:" -ForegroundColor White
Write-Host "1. Сообщение загрузчика: 'Добро пожаловать в ОС на ассемблере!'" -ForegroundColor Gray
Write-Host "2. Сообщение ядра: 'Ядро операционной системы загружено!'" -ForegroundColor Gray
Write-Host "3. Информация об архитектуре и статусе" -ForegroundColor Gray
Write-Host "`nЗапуск QEMU..." -ForegroundColor Green

# Запуск QEMU с графическим интерфейсом
$qemuArgs = @(
    "-fda", "`"$osImg`"",
    "-m", "128",
    "-monitor", "stdio",
    "-no-reboot"
)

try {
    # Запускаем QEMU в отдельном процессе
    $process = Start-Process -FilePath $qemuPath -ArgumentList $qemuArgs -PassThru -NoNewWindow
    Write-Host "QEMU запущен (PID: $($process.Id))" -ForegroundColor Green
    Write-Host "Для остановки нажмите Ctrl+C в этом окне" -ForegroundColor Yellow
    
    # Ждем завершения или прерывания пользователем
    Wait-Process -Id $process.Id -ErrorAction SilentlyContinue
} catch {
    Write-Host "QEMU завершился с ошибкой: $_" -ForegroundColor Red
} finally {
    # Убедимся, что процесс завершен
    if ($process -and (-not $process.HasExited)) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        Write-Host "QEMU остановлен" -ForegroundColor Yellow
    }
}

Write-Host "`n=== Завершено ===" -ForegroundColor Cyan