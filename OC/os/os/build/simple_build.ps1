# Упрощенный скрипт сборки для тестирования
$ErrorActionPreference = "Stop"

# Пути
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$srcDir = Join-Path (Join-Path $scriptDir "..") "src"
$buildDir = Join-Path (Join-Path $scriptDir "..") "build"
$nasmPath = Join-Path (Join-Path (Join-Path (Join-Path $scriptDir "..") "..") "tests") "tools\nasm\nasm.exe"

# Создание каталога для сборки
if (-not (Test-Path $buildDir)) {
    New-Item -ItemType Directory -Path $buildDir -Force | Out-Null
    Write-Host "Создан каталог сборки: $buildDir"
}

Write-Host "Компиляция загрузчика..."
$bootAsm = Join-Path (Join-Path $srcDir "boot") "boot.asm"
$bootBin = Join-Path $buildDir "boot.bin"

& $nasmPath -f bin $bootAsm -o $bootBin
if ($LASTEXITCODE -ne 0) {
    Write-Host "Ошибка компиляции загрузчика!" -ForegroundColor Red
    exit 1
}
Write-Host "Загрузчик успешно скомпилирован: $bootBin"

Write-Host "Компиляция простого ядра..."
$kernelAsm = Join-Path (Join-Path $srcDir "kernel") "simple_kernel.asm"
$kernelBin = Join-Path $buildDir "simple_kernel.bin"

& $nasmPath -f bin $kernelAsm -o $kernelBin
if ($LASTEXITCODE -ne 0) {
    Write-Host "Ошибка компиляции ядра!" -ForegroundColor Red
    exit 1
}
Write-Host "Ядро успешно скомпилировано: $kernelBin"

Write-Host "Создание загрузочного образа..."
$osImg = Join-Path $buildDir "os_simple.img"

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
    Write-Host "Добавлено $paddingSize байт заполнения"
}

if (Test-Path $osImg) {
    $finalSize = (Get-Item $osImg).Length
    Write-Host "Загрузочный образ успешно создан: $osImg" -ForegroundColor Green
    Write-Host "Размер образа: $finalSize байт"
    Write-Host "Для запуска в QEMU выполните: qemu-system-i386 -fda `"$osImg`""
} else {
    Write-Host "Ошибка создания загрузочного образа!" -ForegroundColor Red
    exit 1
}