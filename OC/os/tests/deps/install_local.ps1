# Local dependency installer for OS test environment
# Installs NASM and QEMU to project folder without admin rights

Write-Host "=== Local Dependency Installer for OS Test Environment ===" -ForegroundColor Cyan
Write-Host "Date: $(Get-Date)"
Write-Host ""

# Installation paths
$toolsDir = "$PSScriptRoot\..\tools"
$nasmDir = "$toolsDir\nasm"
$qemuDir = "$toolsDir\qemu"

# Create directories
New-Item -ItemType Directory -Force -Path $toolsDir, $nasmDir, $qemuDir | Out-Null

# Function to add path to session PATH
function Add-ToSessionPath {
    param([string]$PathToAdd)
    if ($env:PATH -split ';' -notcontains $PathToAdd) {
        $env:PATH = "$PathToAdd;$env:PATH"
        Write-Host "   Added $PathToAdd to session PATH" -ForegroundColor Green
        return $true
    } else {
        Write-Host "   Path $PathToAdd already in PATH" -ForegroundColor Yellow
        return $false
    }
}

# 1. Install NASM (portable)
Write-Host "1. Installing NASM (portable)..." -ForegroundColor Yellow

$nasmUrl = "https://www.nasm.us/pub/nasm/releasebuilds/3.01/win64/nasm-3.01-win64.zip"
$nasmZip = "$toolsDir\nasm.zip"
$nasmExePath = "$nasmDir\nasm.exe"

if (Test-Path $nasmExePath) {
    Write-Host "   ✓ NASM already installed in $nasmDir" -ForegroundColor Green
} else {
    Write-Host "   Downloading NASM from $nasmUrl ..." -ForegroundColor Yellow
    try {
        Invoke-WebRequest -Uri $nasmUrl -OutFile $nasmZip -ErrorAction Stop
        Write-Host "   ✓ NASM downloaded" -ForegroundColor Green
        
        # Extract
        Write-Host "   Extracting NASM..." -ForegroundColor Yellow
        Expand-Archive -Path $nasmZip -DestinationPath $nasmDir -Force
        # Move files from subdirectory
        $subDir = Get-ChildItem -Path $nasmDir -Directory -Filter "nasm-*" | Select-Object -First 1
        if ($subDir) {
            Move-Item -Path "$subDir\*" -Destination $nasmDir -Force
            Remove-Item -Path $subDir -Force -Recurse
        }
        
        Write-Host "   ✓ NASM extracted to $nasmDir" -ForegroundColor Green
        Remove-Item -Path $nasmZip -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Host "   ✗ Error downloading NASM: $_" -ForegroundColor Red
        Write-Host "   Please install NASM manually from https://www.nasm.us/" -ForegroundColor Yellow
    }
}

if (Test-Path $nasmExePath) {
    Add-ToSessionPath -PathToAdd $nasmDir
    Write-Host "   Testing NASM..." -ForegroundColor Yellow
    & $nasmExePath --version 2>&1 | Select-Object -First 1
}

# 2. Install QEMU (portable)
Write-Host ""
Write-Host "2. Installing QEMU (portable)..." -ForegroundColor Yellow

# Using QEMU 8.2.0 portable for Windows
$qemuUrl = "https://qemu.weilnetz.de/w64/20231215/qemu-w64-setup-20231215.exe"
$qemuInstaller = "$toolsDir\qemu-setup.exe"
$qemuExePath = "$qemuDir\qemu-system-i386.exe"

if (Test-Path $qemuExePath) {
    Write-Host "   ✓ QEMU already installed in $qemuDir" -ForegroundColor Green
} else {
    Write-Host "   Downloading QEMU installer..." -ForegroundColor Yellow
    try {
        Invoke-WebRequest -Uri $qemuUrl -OutFile $qemuInstaller -ErrorAction Stop
        Write-Host "   ✓ QEMU installer downloaded" -ForegroundColor Green
        
        Write-Host "   Running QEMU installer in silent mode..." -ForegroundColor Yellow
        Write-Host "   Please wait, this may take a minute..." -ForegroundColor Cyan
        
        # Run installer silently to target directory
        $process = Start-Process -FilePath $qemuInstaller -ArgumentList "/S", "/D=$qemuDir" -Wait -PassThru
        if ($process.ExitCode -eq 0) {
            Write-Host "   ✓ QEMU installed to $qemuDir" -ForegroundColor Green
        } else {
            Write-Host "   ✗ QEMU installer failed with exit code $($process.ExitCode)" -ForegroundColor Red
        }
        
        # Cleanup installer
        Remove-Item -Path $qemuInstaller -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Host "   ✗ Error downloading QEMU: $_" -ForegroundColor Red
        Write-Host "   Please install QEMU manually from https://www.qemu.org/download/" -ForegroundColor Yellow
    }
}

# Find qemu-system-i386.exe in installed folder
if (Test-Path $qemuDir) {
    $foundQemu = Get-ChildItem -Path $qemuDir -Recurse -Filter "qemu-system-i386.exe" | Select-Object -First 1
    if ($foundQemu) {
        $qemuDir = $foundQemu.DirectoryName
        Add-ToSessionPath -PathToAdd $qemuDir
        Write-Host "   Testing QEMU..." -ForegroundColor Yellow
        & $foundQemu.FullName --version 2>&1 | Select-Object -First 1
    }
}

# 3. Check Bash
Write-Host ""
Write-Host "3. Checking Bash..." -ForegroundColor Yellow

$bashFound = $false
$bashPath = ""

# Check Git Bash
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
    Write-Host "   ✓ Git Bash found: $bashPath" -ForegroundColor Green
    $bashDir = Split-Path $bashPath -Parent
    Add-ToSessionPath -PathToAdd $bashDir
} else {
    Write-Host "   ✗ Bash not found" -ForegroundColor Red
    Write-Host "   Install Git Bash from https://git-scm.com/downloads" -ForegroundColor Yellow
}

# Final check
Write-Host ""
Write-Host "=== FINAL CHECK ===" -ForegroundColor Cyan

$nasmOk = Test-Path $nasmExePath
$qemuOk = Test-Path $qemuExePath
$bashOk = $bashFound

Write-Host "NASM: $(if ($nasmOk) { '✓ Installed' } else { '✗ Missing' })" -ForegroundColor $(if ($nasmOk) { 'Green' } else { 'Red' })
Write-Host "QEMU: $(if ($qemuOk) { '✓ Installed' } else { '✗ Missing' })" -ForegroundColor $(if ($qemuOk) { 'Green' } else { 'Red' })
Write-Host "Bash: $(if ($bashOk) { '✓ Found' } else { '✗ Missing' })" -ForegroundColor $(if ($bashOk) { 'Green' } else { 'Red' })

if ($nasmOk -and $qemuOk -and $bashOk) {
    Write-Host ""
    Write-Host "✅ All dependencies installed locally!" -ForegroundColor Green
    Write-Host "Paths added to current session PATH." -ForegroundColor Green
    Write-Host ""
    Write-Host "To make paths permanent, add these to your user PATH variable:" -ForegroundColor Cyan
    Write-Host "  - $nasmDir" -ForegroundColor White
    Write-Host "  - $qemuDir" -ForegroundColor White
    Write-Host "  - $bashDir" -ForegroundColor White
} else {
    Write-Host ""
    Write-Host "⚠️  Some dependencies are missing." -ForegroundColor Yellow
    Write-Host "Manual installation may be required." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Additional Information ===" -ForegroundColor Cyan
Write-Host "  - Test documentation: os/tests/README.md" -ForegroundColor White
Write-Host "  - Main test script: os/tests/scripts/run_test.sh" -ForegroundColor White

Write-Host ""
Write-Host "=== Script completed ===" -ForegroundColor Cyan