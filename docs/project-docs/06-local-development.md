# 06 - Local Development

## Switch environment
```bash
./scripts/use-dev.sh
# or
./scripts/use-prod.sh
```

## Install dependencies
```bash
flutter pub get
```

## List devices
```bash
flutter devices
flutter emulators
```

## Run on Android emulator
1. Launch emulator:
```bash
flutter emulators --launch Medium_Phone_API_35
```
2. Confirm device id:
```bash
flutter devices
```
3. Run app:
```bash
flutter run -d emulator-5554
```

## Run on macOS
```bash
flutter run -d macos
```

## Run on Chrome
```bash
flutter run -d chrome
```

## If emulator launched but Flutter cannot find it
```bash
flutter devices
# wait 10-20s
flutter run -d emulator-5554
```

## If APK install fails
```bash
ADB="$HOME/Library/Android/sdk/platform-tools/adb"
$ADB -s emulator-5554 uninstall com.moneii.moneii_manager || true
flutter clean
flutter pub get
flutter build apk --debug
$ADB -s emulator-5554 install -r -d build/app/outputs/flutter-apk/app-debug.apk
```

## Useful development commands
```bash
flutter analyze
flutter test
flutter pub outdated
```
