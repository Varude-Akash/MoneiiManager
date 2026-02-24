# 10 - Troubleshooting

## "Invalid JWT" from Supabase function
- Confirm user is logged in.
- Confirm request sends bearer token.
- Confirm project link/env is correct for current run.
- If function uses JWT verify in gateway, ensure auth token is from same project.

## CORS or 401/403 in function calls
- Check you are running against the expected project URL.
- Check function is deployed in that project.
- Check secrets are present in that project.

## "Profile not found"
- User row not created in `profiles` table for that auth user.
- Check trigger / signup flow and profile bootstrap logic.

## RevenueCat paywall errors
- Android: ensure `MainActivity : FlutterFragmentActivity`.
- Ensure `REVENUECAT_API_KEY` present in active `.env`.
- Ensure products + offering + entitlement configured in dashboard.
- Ensure testing on iOS/Android, not web for real IAP behavior.

## "In-app purchases not configured on this platform"
- Usually not running on real iOS/Android IAP context.
- Or RevenueCat store/offering not configured for the app/store.

## Android install failure
Use manual reinstall sequence:
```bash
ADB="$HOME/Library/Android/sdk/platform-tools/adb"
$ADB -s emulator-5554 uninstall com.moneii.moneii_manager || true
flutter clean
flutter pub get
flutter build apk --debug
$ADB -s emulator-5554 install -r -d build/app/outputs/flutter-apk/app-debug.apk
```

## Emulator not detected
- Start emulator first.
- Wait, then run `flutter devices`.
- Use detected ID (often `emulator-5554`) in `flutter run -d <id>`.
