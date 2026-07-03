@echo off
title ATD | AppGather
color 0A

echo ============================================================
echo           ATD | AppGather v6.0
echo           Sistem Optimizasyon ve Temizlik Araci
echo ============================================================
echo.

echo [1/2] Yonetici yetkisi kontrol ediliyor...
net session >nul 2>&1
if errorlevel 1 (
    echo [!] Yonetici yetkisi gerekli!
    echo     Kendini yeniden baslatiyor...
    timeout /t 2 /nobreak >nul
    powershell -Command "Start-Process cmd -Verb RunAs -ArgumentList '/c \"%~f0\"'"
    exit
)
echo [OK] Yonetici olarak calistiriliyor!
echo.

echo [2/2] AppGather baslatiliyor...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0main.ps1"

echo.
pause