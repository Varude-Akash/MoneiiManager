# 07 - Testing Checklists

## Fast smoke test (dev)
1. Register/login works.
2. Home loads without errors.
3. Add manual transaction works.
4. Voice record -> parse -> save works.
5. Activity list shows new entry.
6. Tap transaction opens edit, long-press opens delete confirm.
7. Analytics reflects data.
8. Profile loads and sign-out works.

## Premium test matrix
Use 3 dev users:
- Free user
- Premium user
- Premium Plus user

Validate:
1. Free user sees locked premium UI and paywall trigger.
2. Premium user can access premium features.
3. Premium Plus gets higher limits/features.
4. Free voice limits: 3/day and 93/month.
5. Premium voice limit: 10/day.
6. Premium+ voice limit: product-unlimited, backend safety cap 200/day.
7. Moneii AI limits: Premium 5/day, Premium+ 50/day.
8. Moneii AI response is plain natural text (no forced Summary/Insights/Next Steps format).
9. Moneii AI response never exceeds 200 words.
10. Moneii AI month tabs show current + previous 2 months, and older tabs are read-only.

## RevenueCat checks (mobile)
1. Tap locked feature -> paywall opens.
2. Purchase monthly/yearly.
3. Entitlement `Moneii Pro` becomes active.
4. Feature unlock works immediately.
5. Restore purchases works.
6. Customer center opens from profile.

## Supabase backend checks
1. Migrations up-to-date on target project.
2. Functions deployed on target project.
3. Required secrets set (`OPENAI_API_KEY`).
4. Seed reference data present.

## Pre-release quality checks
```bash
flutter analyze
flutter test
```
Then run manual smoke on Android and iOS test devices/emulators.
