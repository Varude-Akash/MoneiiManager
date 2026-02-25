# 05 - RevenueCat Runbook

## SDK packages
- `purchases_flutter`
- `purchases_ui_flutter`

## Environment key
- `REVENUECAT_API_KEY` in `.env.dev` and `.env.prod`

## Dashboard configuration required
1. Entitlements:
   - `Moneii Pro`
   - `Moneii Pro Plus`
2. Products:
   - `monthly`
   - `yearly`
   - optional plus products: `monthly_plus`, `yearly_plus`
3. Offering (current/default) containing active packages
4. Entitlement attached to corresponding products

## App behavior
- SDK initialized via provider in app startup.
- App user is synchronized using Supabase user id.
- Premium gate calls `presentPaywallIfNeeded('Moneii Pro')`.
- Premium users can upgrade to Plus from Profile via
  `presentPaywallIfNeeded('Moneii Pro Plus')`.
- Profile has restore + manage subscription actions.

## Critical platform notes
- RevenueCat paywall must be tested on iOS/Android.
- Web and macOS desktop do not support store purchase flow the same way.
- Android paywall requires `MainActivity` to extend `FlutterFragmentActivity`.

## Test store vs real store
- If API key starts with `test_`, RevenueCat Test Store is active.
- Test Store is for development only.
- Before release, use platform-specific public SDK keys from a real app/store setup.

## Customer center
Use Customer Center if you want users to self-manage subscriptions from app profile.
It is already integrated in app UI path if platform supports it.

## Troubleshooting quick checks
- Paywall not opening on Android: check `MainActivity` subclass.
- "In-app purchase not configured": verify products + offering + entitlement mapping in RevenueCat.
- Entitlement not reflecting: refresh customer info and ensure same app user id/login state.
