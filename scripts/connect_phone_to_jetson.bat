@echo off
echo ==========================================================
echo Connecting Phone to Jetson Orin Nano via Tailscale Bridge
echo ==========================================================

REM Set ADB path
set ADB="C:\Android\Sdk\platform-tools\adb.exe"

REM 1. Check Tailscale connection to Jetson
echo [1/3] Checking connection to Jetson at 100.104.251.40:8000...
powershell -Command "Test-NetConnection -ComputerName 100.104.251.40 -Port 8000 -WarningAction SilentlyContinue | Select-Object -ExpandProperty TcpTestSucceeded"

REM 2. Forward ADB port from phone to laptop
echo [2/3] Setting up ADB reverse port forwarding (phone 127.0.0.1:8000 -^> PC)...
if exist %ADB% (
    %ADB% reverse tcp:8000 tcp:8000
    %ADB% reverse --list
) else (
    adb reverse tcp:8000 tcp:8000
)

REM 3. Run Jetson bridge
echo [3/3] Starting Jetson forward proxy (PC:8000 -^> 100.104.251.40:8000)...
echo.
echo ==========================================================
echo Connection is active!
echo - Phone connected via USB: uses 127.0.0.1:8000
echo - Phone connected via Wi-Fi: uses 192.168.1.7:8000
echo - Phone with Tailscale app: uses 100.104.251.40:8000
echo ==========================================================
python "%~dp0forward_jetson.py"
