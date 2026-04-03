# Final environment verification script
# Checks all dependencies and confirms test environment is ready

Write-Host "=== Final Environment Verification ===" -ForegroundColor Cyan
Write-Host "Date: $(Get-Date)"
Write-Host ""

$allOk = $true

# 1. Check NASM
Write-Host "1. Checking NASM..." -ForegroundColor Yellow
$nasmOk = $false
$localNasm = "os/tests/tools/nasm/nasm.exe"
if (Test-Path $localNasm) {
    try {
        $version = & $localNasm --version 2>&1 | Select-Object -First 1
        Write-Host "   ✓ NASM (local): $version" -ForegroundColor Green
        $nasmOk = $true
    } catch {
        Write-Host "   ✗ Local NASM failed to run" -ForegroundColor Red
    }
} else {
    Write-Host "   ✗ Local NASM not found at $localNasm" -ForegroundColor Red
}

if (-not $nasmOk) {
    try {
        $version = & nasm --version 2>&1 | Select-Object -First 1
        if ($version -like "*NASM*") {
            Write-Host "   ✓ NASM (global): $version" -ForegroundColor Green
            $nasmOk = $true
        }
    } catch {
        Write-Host "   ✗ Global NASM not found" -ForegroundColor Red
    }
}

if (-not $nasmOk) {
    $allOk = $false
    Write-Host "   ⚠ NASM is required for OS assembly" -ForegroundColor Yellow
}

# 2. Check QEMU
Write-Host ""
Write-Host "2. Checking QEMU..." -ForegroundColor Yellow
$qemuOk = $false
try {
    $version = & qemu-system-i386 --version 2>&1 | Select-Object -First 1
    if ($version -like "*QEMU*") {
        Write-Host "   ✓ QEMU: $version" -ForegroundColor Green
        $qemuOk = $true
    }
} catch {
    Write-Host "   ✗ QEMU not found" -ForegroundColor Red
}

if (-not $qemuOk) {
    $allOk = $false
    Write-Host "   ⚠ QEMU is required for running OS tests" -ForegroundColor Yellow
}

# 3. Check Bash
Write-Host ""
Write-Host "3. Checking Bash..." -ForegroundColor Yellow
$bashOk = $false
$gitBashPaths = @(
    "C:\Program Files\Git\bin\bash.exe",
    "C:\Program Files (x86)\Git\bin\bash.exe",
    "$env:USERPROFILE\AppData\Local\Programs\Git\bin\bash.exe"
)

foreach ($path in $gitBashPaths) {
    if (Test-Path $path) {
        Write-Host "   ✓ Git Bash found: $path" -ForegroundColor Green
        $bashOk = $true
        break
    }
}

if (-not $bashOk) {
    try {
        $version = & bash --version 2>&1 | Select-Object -First 1
        if ($version -like "*bash*") {
            Write-Host "   ✓ Bash: Found" -ForegroundColor Green
            $bashOk = $true
        }
    } catch {
        Write-Host "   ✗ Bash not found" -ForegroundColor Red
    }
}

if (-not $bashOk) {
    $allOk = $false
    Write-Host "   ⚠ Bash is required for running test scripts" -ForegroundColor Yellow
}

# 4. Check directory structure
Write-Host ""
Write-Host "4. Checking directory structure..." -ForegroundColor Yellow
$dirsOk = $true
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

foreach ($dir in $requiredDirs) {
    if (Test-Path $dir -PathType Container) {
        Write-Host "   ✓ $dir" -ForegroundColor Green
    } else {
        Write-Host "   ✗ $dir (missing)" -ForegroundColor Red
        $dirsOk = $false
    }
}

if (-not $dirsOk) {
    $allOk = $false
    Write-Host "   ⚠ Some directories are missing" -ForegroundColor Yellow
}

# 5. Check main test scripts
Write-Host ""
Write-Host "5. Checking main test scripts..." -ForegroundColor Yellow
$scriptsOk = $true
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

foreach ($script in $requiredScripts) {
    if (Test-Path $script -PathType Leaf) {
        Write-Host "   ✓ $(Split-Path $script -Leaf)" -ForegroundColor Green
    } else {
        Write-Host "   ✗ $(Split-Path $script -Leaf) (missing)" -ForegroundColor Red
        $scriptsOk = $false
    }
}

if (-not $scriptsOk) {
    $allOk = $false
    Write-Host "   ⚠ Some scripts are missing" -ForegroundColor Yellow
}

# Final summary
Write-Host ""
Write-Host "=== VERIFICATION RESULT ===" -ForegroundColor Cyan

if ($allOk) {
    Write-Host "✅ ENVIRONMENT READY" -ForegroundColor Green
    Write-Host "All dependencies are installed and test environment is fully configured." -ForegroundColor Green
    Write-Host ""
    Write-Host "To run tests:" -ForegroundColor Yellow
    Write-Host "  1. Open Git Bash" -ForegroundColor White
    Write-Host "  2. Navigate to: cd /e/OC/os/tests/scripts" -ForegroundColor White
    Write-Host "  3. Run tests: ./run_test.sh bootloader" -ForegroundColor White
    Write-Host "  4. Or run all tests: ./run_test.sh all" -ForegroundColor White
    Write-Host ""
    Write-Host "Note: For NASM to be found by test scripts, you may need to:" -ForegroundColor Cyan
    Write-Host "  - Add local NASM to PATH: $((Resolve-Path 'os/tests/tools/nasm').Path)" -ForegroundColor White
    Write-Host "  - Or modify run_test.sh to use local NASM path" -ForegroundColor White
} else {
    Write-Host "⚠️  ENVIRONMENT INCOMPLETE" -ForegroundColor Yellow
    Write-Host "Some components are missing. Please install missing dependencies." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Verification completed ===" -ForegroundColor Cyan