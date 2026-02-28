# RevenueCat Setup (Moneii)

This guide matches the current app code.

## 1) SDK Installation

Already added to `pubspec.yaml`:

- `purchases_flutter`
- `purchases_ui_flutter`

If needed again:

```bash
flutter pub add purchases_flutter purchases_ui_flutter
```

## 2) Environment Variable

Add `REVENUECAT_API_KEY` to your local env files with the correct key type:

```env
REVENUECAT_API_KEY=<KEY_HERE>
```

Files:

- `.env.dev`
- `.env.prod`

Key rules:

- Use `test_...` key only for local dev/test store testing.
- Use Play Store public SDK key (`goog_...`) in `.env.prod` for Android releases distributed via Google Play.
- Use Apple public SDK key (`appl_...`) in iOS builds from App Store Connect/TestFlight.
- Never put RevenueCat secret API keys in app env files.

Then switch env:

```bash
./scripts/use-dev.sh
```

## 3) RevenueCat Dashboard Configuration

### 3.1 Entitlements

Create entitlements exactly:

- `Moneii Pro`
- `Moneii Pro Plus`

### 3.2 Products

Create two subscription products in stores and import into RevenueCat:

- Monthly product id: `monthly`
- Yearly product id: `yearly`

Optional for Premium+ (recommended):

- Monthly Plus product id: `monthly_plus`
- Yearly Plus product id: `yearly_plus`

### 3.3 Packages / Offering

Create a current offering (e.g. `default`) with packages:

- `$rc_monthly` -> product `monthly`
- `$rc_annual` -> product `yearly`

Set this offering as current.

### 3.4 Attach entitlement(s)

Attach both products (`monthly`, `yearly`) to entitlement:

- `Moneii Pro`

Attach plus products (`monthly_plus`, `yearly_plus`) to:

- `Moneii Pro Plus`

## 4) What App Code Does

### 4.1 Initialization

- Initializes RevenueCat using `REVENUECAT_API_KEY`
- Logs in RevenueCat using Supabase user id
- Listens to customer info updates

Code:

- `lib/features/subscriptions/presentation/providers/revenuecat_provider.dart`
- `lib/app.dart` (provider bootstrapped)

### 4.2 Entitlement checks

- Checks entitlement keys: `Moneii Pro`, `Moneii Pro Plus`
- Exposes `hasMoneiiPro` and `hasMoneiiProPlus` in app state

### 4.3 Paywall

- Premium gate now opens RevenueCat paywall
- Uses `RevenueCatUI.presentPaywallIfNeeded('Moneii Pro')`
- Profile supports Premium+ upsell from Premium users:
  - `RevenueCatUI.presentPaywallIfNeeded('Moneii Pro Plus')`

Code:

- `lib/shared/widgets/premium_gate.dart`

### 4.4 Customer Center

- Added `Manage Subscription` button in Profile
- Calls `RevenueCatUI.presentCustomerCenter()`

Code:

- `lib/features/profile/presentation/screens/profile_screen.dart`

### 4.5 Customer info / restore

- Restore purchases button in Profile
- Refreshes customer info and updates entitlement state

## 5) Moneii Pro Mapping

Current behavior:

- If `Moneii Pro Plus` active: user treated as `premium_plus`.
- Else if `Moneii Pro` active: user treated premium in app gating.
- Provider attempts to promote `profiles.plan_tier` from `free` -> `premium`.
- Provider promotes to `premium_plus` if Plus entitlement is active.
- It does not auto-downgrade `premium_plus` to avoid breaking manual/admin tiers.

Important best practice:

- For production-grade source-of-truth, add RevenueCat webhook -> Supabase function to update `plan_tier` server-side.

## 6) Testing Checklist

1. Login with test user (sandbox account).
2. Tap locked premium feature -> paywall appears.
3. Purchase monthly/yearly -> entitlement active.
4. Reopen locked feature -> unlocked.
5. Open Profile -> Manage Subscription opens Customer Center.
6. Tap Restore Purchases -> entitlement restored on reinstall/new device.
7. If distributed through Play closed/internal testing, install only via Play opt-in link (not direct APK) before testing purchases.

## 7) Error Handling in App

- Missing `REVENUECAT_API_KEY`: shows configuration error.
- Unsupported platform (web/desktop): paywall button disabled/graceful message.
- Purchase cancelled/error: user-friendly snackbars.

## 8) Important Store Notes

- Use App Store/Play billing products (required for digital subscriptions).
- Do not use Stripe checkout for in-app premium unlock on iOS/Android.
- Keep your RevenueCat public SDK key in app env.
- Keep store API keys and webhook secrets server-side only.
