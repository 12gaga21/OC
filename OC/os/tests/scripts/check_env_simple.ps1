# Simple environment check script
# Checks dependencies and structure

Write-Host "=== OS Test Environment Check ===" -ForegroundColor Cyan
Write-Host "Date: $(Get-Date)"
Write-Host ""

# Check directories
Write-Host "1. Checking directories..." -ForegroundColor Yellow
$dirs = @(
    "os/tests",
    "os/tests/unit",
    "os/tests/integration",
    "os/tests/performance",
    "os/tests/scripts",
    "os/tests/utils",
    "os/tests/config",
    "os/tests/results"
)

$allDirsOk = $true
foreach ($dir in $dirs) {
    if (Test-Path $dir -PathType Container) {
        Write-Host "  ✓ $dir" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $dir (missing)" -ForegroundColor Red
        $allDirsOk = $false
    }
}

# Check NASM
Write-Host ""
Write-Host "2. Checking NASM..." -ForegroundColor Yellow
$nasmOk = $false
$localNasm = "os/tests/tools/nasm/nasm.exe"
if (Test-Path $localNasm) {
    $version = & $localNasm --version 2>&1 | Select-Object -First 1
    Write-Host "  ✓ NASM (local): $version" -ForegroundColor Green
    $nasmOk = $true
} else {
    try {
        $version = & nasm --version 2>&1 | Select-Object -First 1
        if ($version -like "*NASM*") {
            Write-Host "  ✓ NASM (global): $version" -ForegroundColor Green
            $nasmOk = $true
        }
    } catch {
        Write-Host "  ✗ NASM not found" -ForegroundColor Red
    }
}

# Check QEMU
Write-Host ""
Write-Host "3. Checking QEMU..." -ForegroundColor Yellow
$qemuOk = $false
try {
    $version = & qemu-system-i386 --version 2>&1 | Select-Object -First 1
    if ($version -like "*QEMU*") {
        Write-Host "  ✓ QEMU: $version" -ForegroundColor Green
        $qemuOk = $true
    }
} catch {
    Write-Host "  ✗ QEMU not found" -ForegroundColor Red
}

# Check Bash
Write-Host ""
Write-Host "4. Checking Bash..." -ForegroundColor Yellow
$bashOk = $false
try {
    $version = & bash --version 2>&1 | Select-Object -First 1
    if ($version -like "*bash*") {
        Write-Host "  ✓ Bash found" -ForegroundColor Green
        $bashOk = $true
    }
} catch {
    Write-Host "  ✗ Bash not found" -ForegroundColor Red
}

# Summary
Write-Host ""
Write-Host "=== SUMMARY ===" -ForegroundColor Cyan

if ($nasmOk -and $qemuOk -and $bashOk) {
    Write-Host "✅ All dependencies installed!" -ForegroundColor Green
    Write-Host "Test environment is ready." -ForegroundColor Green
    Write-Host ""
    Write-Host "To run tests:" -ForegroundColor Yellow
    Write-Host "  cd os/tests/scripts" -ForegroundColor White
    Write-Host "  ./run_test.sh bootloader    # Bootloader test" -ForegroundColor White
    Write-Host "  ./run_test.sh all           # All tests" -ForegroundColor White
} else {
    Write-Host "⚠️  Missing dependencies:" -ForegroundColor Yellow
    if (-not $nasmOk) { Write-Host "  - NASM" -ForegroundColor Red }
    if (-not $qemuOk) { Write-Host "  - QEMU" -ForegroundColor Red }
    if (-not $bashOk) { Write-Host "  - Bash (WSL/Git Bash)" -ForegroundColor Red }
    Write-Host ""
    Write-Host "Install missing dependencies and run check again." -ForegroundColor Cyan
}

Write-Host ""
Write-Host "=== Check completed ===" -ForegroundColor Cyan