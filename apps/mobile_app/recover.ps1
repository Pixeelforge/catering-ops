Stop-Process -Name "dart" -Force -ErrorAction SilentlyContinue
Stop-Process -Name "flutter" -Force -ErrorAction SilentlyContinue
Stop-Process -Name "chrome" -Force -ErrorAction SilentlyContinue

echo "Cleaning project..."
flutter clean

echo "Fetching dependencies..."
flutter pub get

echo "Starting server..."
flutter run -d chrome --web-port 8080 --no-pub
