# Quickstart (Daily Use)

Use this when you just want commands without reading full docs.

## 0) One-time setup
```bash
supabase login
```

## 1) Start development (dev backend)
```bash
cd /Users/sky/Projects/MoneiiManager
git checkout develop
git pull origin develop
./scripts/use-dev.sh
flutter pub get
flutter run -d emulator-5554
```

If emulator is not running:
```bash
flutter emulators --launch Medium_Phone_API_35
flutter devices
```

## 2) New feature flow
```bash
git checkout -b feature/<short-name>
# do code changes
flutter analyze
flutter test
git restore supabase/.temp/pooler-url supabase/.temp/project-ref
git add -A
git commit -m "<clear message>"
git push -u origin feature/<short-name>
```

Then open PR: `feature/<short-name> -> develop`.

## 3) Deploy backend to dev (if migrations/functions changed)
```bash
./scripts/use-dev.sh
supabase link --project-ref enafqqntznyiyarpqvmu
supabase db push
supabase functions deploy voice-transcribe
supabase functions deploy moneii-ai
supabase functions deploy delete-account
supabase secrets set OPENAI_API_KEY=<YOUR_OPENAI_KEY>
```

## 4) Release flow (code)
1. Merge feature PRs into `develop`.
2. Validate in dev.
3. Merge `develop -> main`.

## 5) Deploy backend to prod
```bash
./scripts/use-prod.sh
supabase link --project-ref cdfhshejzvcdhsthagpi
supabase db push
supabase functions deploy voice-transcribe
supabase functions deploy moneii-ai
supabase functions deploy delete-account
supabase secrets set OPENAI_API_KEY=<YOUR_OPENAI_KEY>
```

## 6) Run app against prod
```bash
./scripts/use-prod.sh
flutter run -d emulator-5554
```

## 7) RevenueCat checks
- `REVENUECAT_API_KEY` must exist in `.env.dev` and `.env.prod`.
- Test paywall on Android/iOS only (not web).
- Entitlement must be exactly: `Moneii Pro`.

## 8) Fast failure fixes

### APK install failed
```bash
ADB="$HOME/Library/Android/sdk/platform-tools/adb"
$ADB -s emulator-5554 uninstall com.moneii.moneii_manager || true
flutter clean
flutter pub get
flutter build apk --debug
$ADB -s emulator-5554 install -r -d build/app/outputs/flutter-apk/app-debug.apk
```

### Emulator not found
```bash
flutter devices
```
Use detected id in:
```bash
flutter run -d <device-id>
```

## 9) Do not commit
- `.env`, `.env.dev`, `.env.prod`
- `supabase/.temp/*`
- Any secret keys

## 10) Full documentation index
- `docs/project-docs/README.md`
