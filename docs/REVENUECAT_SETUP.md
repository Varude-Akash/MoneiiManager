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

Add to your local env files:

```env
REVENUECAT_API_KEY=test_VtxxJTvCkNrEneiunqbTppwsTqR
```

Files:

- `.env.dev`
- `.env.prod`

Then switch env:

```bash
./scripts/use-dev.sh
```

## 3) RevenueCat Dashboard Configuration

### 3.1 Entitlement

Create entitlement exactly:

- `Moneii Pro`

### 3.2 Products

Create two subscription products in stores and import into RevenueCat:

- Monthly product id: `monthly`
- Yearly product id: `yearly`

### 3.3 Packages / Offering

Create a current offering (e.g. `default`) with packages:

- `$rc_monthly` -> product `monthly`
- `$rc_annual` -> product `yearly`

Set this offering as current.

### 3.4 Attach entitlement

Attach both products (`monthly`, `yearly`) to entitlement:

- `Moneii Pro`

## 4) What App Code Does

### 4.1 Initialization

- Initializes RevenueCat using `REVENUECAT_API_KEY`
- Logs in RevenueCat using Supabase user id
- Listens to customer info updates

Code:

- `lib/features/subscriptions/presentation/providers/revenuecat_provider.dart`
- `lib/app.dart` (provider bootstrapped)

### 4.2 Entitlement check

- Checks entitlement key: `Moneii Pro`
- Exposes `hasMoneiiPro` in app state

### 4.3 Paywall

- Premium gate now opens RevenueCat paywall
- Uses `RevenueCatUI.presentPaywallIfNeeded('Moneii Pro')`

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

- If `Moneii Pro` active: user is treated premium in app gating.
- Provider attempts to promote `profiles.plan_tier` from `free` -> `premium`.
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

## 7) Error Handling in App

- Missing `REVENUECAT_API_KEY`: shows configuration error.
- Unsupported platform (web/desktop): paywall button disabled/graceful message.
- Purchase cancelled/error: user-friendly snackbars.

## 8) Important Store Notes

- Use App Store/Play billing products (required for digital subscriptions).
- Do not use Stripe checkout for in-app premium unlock on iOS/Android.
- Keep your RevenueCat public SDK key in app env.
- Keep store API keys and webhook secrets server-side only.
