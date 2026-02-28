# 03 - Architecture and Code Map

## Main structure
- `lib/config`: app initialization, router, env
- `lib/core`: shared utilities, premium rules, providers
- `lib/features`: feature modules
- `lib/shared/widgets`: reusable UI components (including premium gate)
- `supabase/migrations`: schema migrations
- `supabase/functions`: edge functions
- `supabase/seed`: reference data seed SQL
- `scripts`: environment switch scripts

## Feature modules
- `auth`: login/register/session/profile bootstrap
- `home`: voice-first home screen
- `expenses`: add/edit/delete/list transactions
- `activity`: transaction activity timeline
- `analytics`: charts and summaries
- `profile`: plan info, legal, account actions, sign-out/delete
- `voice`: recording and transcription pipeline
- `moneii_ai`: assistant UI and interaction with AI backend
- `subscriptions`: RevenueCat provider/state
- `legal`: legal docs screens

## Key files to know first
- `lib/main.dart`
- `lib/app.dart`
- `lib/config/router.dart`
- `lib/config/env.dart`
- `lib/features/subscriptions/presentation/providers/revenuecat_provider.dart`
- `lib/shared/widgets/premium_gate.dart`
- `supabase/functions/voice-transcribe/index.ts`
- `supabase/functions/moneii-ai/index.ts`
- `supabase/functions/delete-account/index.ts`

## Data/control flow (high level)
1. User authenticates with Supabase Auth.
2. App loads profile and plan tier from Supabase.
3. Voice input records audio on device.
4. Audio is sent to `voice-transcribe` function and parsed.
5. Transaction is written to Supabase tables.
6. Analytics and activity read from database.
7. Premium feature taps go through `premium_gate`:
   - if premium in profile or entitlement active, allow
   - else show RevenueCat paywall.
8. Moneii AI:
   - stores successful Q/A in `ai_assistant_requests`
   - keeps last 3 months of history
   - allows new messages only in current month view (older months read-only)
   - response style is natural plain text with hard max 200 words
