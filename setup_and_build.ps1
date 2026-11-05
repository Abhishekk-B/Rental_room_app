# RentPulse - Local Windows Build Script
# This script verifies prerequisites and builds the Android APK locally

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " RentPulse Android App Local Builder    " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# 1. Check Java
Write-Host "`n[1/3] Checking Java runtime..." -ForegroundColor Yellow
try {
    $javaVer = java -version 2>&1 | Out-String
    Write-Host "Java is installed:" -ForegroundColor Green
    Write-Host $javaVer.Split("`n")[0]
} catch {
    Write-Host "Java is not found in PATH. Please install OpenJDK 17 or 21." -ForegroundColor Red
}

# 2. Check Flutter
Write-Host "`n[2/3] Checking Flutter SDK..." -ForegroundColor Yellow
$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue

if (-not $flutterCmd) {
    Write-Host "Flutter is not currently in your system PATH." -ForegroundColor Yellow
    Write-Host "To set up Flutter in 2 minutes:" -ForegroundColor White
    Write-Host "1. Download Flutter SDK for Windows from: https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.24.5-stable.zip"
    Write-Host "2. Extract the zip to C:\src\flutter"
    Write-Host "3. Add 'C:\src\flutter\bin' to your User PATH environment variable."
    Write-Host "4. Restart PowerShell and re-run this script."
    exit 1
} else {
    Write-Host "Flutter found at: $($flutterCmd.Source)" -ForegroundColor Green
}

# 3. Build APK
Write-Host "`n[3/3] Compiling RentPulse Android APK..." -ForegroundColor Yellow
flutter pub get
flutter build apk --debug

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n=========================================" -ForegroundColor Green
    Write-Host " SUCCESS! APK Generated Successfully!   " -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Green
    Write-Host "APK Location: build\app\outputs\flutter-apk\app-debug.apk" -ForegroundColor White
    Write-Host "You can now copy this file to your phone to install." -ForegroundColor White
} else {
    Write-Host "`nBuild failed. Check the error output above." -ForegroundColor Red
}
