@echo off
echo ========================================
echo   Flutter App - Emergency Restart Tool
echo ========================================

echo [1/4] Killing all Flutter and Dart processes...
taskkill /F /IM dart.exe /T >nul 2>&1
taskkill /F /IM flutter.exe /T >nul 2>&1
echo Done.

echo [2/4] Cleaning Flutter build cache...
cd /d "c:\Users\sivaj\Desktop\new one\apps\mobile_app"
flutter clean
echo Done.

echo [3/4] Getting dependencies...
flutter pub get
echo Done.

echo [4/4] Starting Flutter server...
echo   App will be available at: http://192.168.0.113:8080
flutter run -d chrome --web-hostname 0.0.0.0 --web-port 8080
