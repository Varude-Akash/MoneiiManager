# 01 - Project Profile

## Product
- App name: `MoneiiManager` (user-facing brand: `Moneii`)
- Type: Personal finance manager
- Core flows: voice expense capture, manual transaction logging, analytics, profile, premium gating

## Tech stack
- Frontend: Flutter + Riverpod + GoRouter
- Backend: Supabase (Auth, Postgres, Edge Functions)
- AI voice: OpenAI via Supabase Edge Function (`voice-transcribe`)
- AI assistant: Supabase Edge Function (`moneii-ai`)
- Subscriptions: RevenueCat SDK (`purchases_flutter`, `purchases_ui_flutter`)

## Platforms currently used
- Android emulator and Android device
- macOS desktop
- Chrome web for quick local debugging (not valid for in-app purchase flow)

## App identity
- Android application id: `com.moneii.moneii_manager`
- iOS bundle id: `com.moneii.moneiiManager`
- Version: `1.0.0+1` (from `pubspec.yaml`)

## Premium model
- Free
- Premium
- Premium Plus

RevenueCat entitlement currently used in app code:
- `Moneii Pro`

RevenueCat product ids currently expected:
- `monthly`
- `yearly`
