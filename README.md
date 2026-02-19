# MoneiiManager

Voice-powered expense tracker built with Flutter + Supabase + OpenAI Whisper.

## Features

- Email/password auth with onboarding + quick setup
- Voice input flow: record -> transcribe -> parse -> edit -> save
- Manual add/edit expense flow with category/subcategory picker
- Expense list grouped by date, swipe edit/delete, undo
- Analytics dashboard (pie, bars, trend line, summary cards)
- Profile management (avatar, optional details, currency preference)
- Theme mode toggle (dark default), notification preference toggle
- Premium feature placeholders with locked UX
- Micro-interactions: haptics, animated transitions, shimmer loading, first-expense confetti

## Tech Stack

- Flutter (Riverpod, GoRouter, fl_chart, flutter_animate)
- Supabase (Auth, Postgres, RLS, Storage)
- OpenAI Whisper API for transcription

## Prerequisites

- Flutter SDK (stable)
- Supabase project
- OpenAI API key with Whisper access

## Environment

Create `.env` (or copy `.env.example`):

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
OPENAI_API_KEY=sk-your-openai-key-here
```

## Supabase Setup

1. Run schema + RLS migration:

- `supabase/migrations/20260219_001_init_schema.sql`

2. Seed categories and premium placeholders:

- `supabase/seed/seed_reference_data.sql`

3. Create a public storage bucket named `avatars`.

## Run

```bash
flutter pub get
flutter run
```

## Verification Checklist

- First launch shows onboarding once
- Register/sign-in works
- Setup name + optional avatar works
- Add manual expense -> appears in Home and Analytics
- Voice add works (with valid OpenAI key)
- Swipe delete + undo works
- Profile save works, theme toggle works, sign out redirects to login

## Project Structure

- `lib/config/` app config (theme/router/env)
- `lib/features/auth/`
- `lib/features/expenses/`
- `lib/features/voice/`
- `lib/features/analytics/`
- `lib/features/profile/`
- `lib/features/onboarding/`
- `supabase/migrations/` SQL migrations
- `supabase/seed/` seed scripts

## Quality

Current status:

- `flutter analyze` passes
- `flutter test` passes
