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

For the current 2-project setup (`dev` + `prod`), use:

- `.env.dev`
- `.env.prod`

Switch active env file into `.env` using scripts:

```bash
./scripts/use-dev.sh
./scripts/use-prod.sh
```

Detailed workflow guide:

- `docs/TWO_PROJECT_WORKFLOW.md`
- `docs/OPERATIONS_PLAYBOOK.md` (single source of truth for env + backend + git + release steps)

GitHub-friendly docs links:

- [Operations Playbook](./docs/OPERATIONS_PLAYBOOK.md)
- [Project Documentation Index](./docs/project-docs/README.md)
- [Quickstart (Daily Use)](./docs/project-docs/QUICKSTART.md)
- [Two Project Workflow](./docs/TWO_PROJECT_WORKFLOW.md)
- [Publishing Checklist](./docs/PUBLISHING_CHECKLIST.md)
- [Privacy Policy (template)](./docs/PRIVACY_POLICY.md)
- [Terms of Service (template)](./docs/TERMS_OF_SERVICE.md)
- [RevenueCat Setup](./docs/REVENUECAT_SETUP.md)

Detailed runbooks (new):

- [01 - Project Profile](./docs/project-docs/01-project-profile.md)
- [02 - Environments and IDs](./docs/project-docs/02-environments-and-ids.md)
- [03 - Architecture and Code Map](./docs/project-docs/03-architecture-and-code-map.md)
- [04 - Supabase Runbook](./docs/project-docs/04-supabase-runbook.md)
- [05 - RevenueCat Runbook](./docs/project-docs/05-revenuecat-runbook.md)
- [06 - Local Development](./docs/project-docs/06-local-development.md)
- [07 - Testing Checklists](./docs/project-docs/07-testing-checklists.md)
- [08 - Git Workflow](./docs/project-docs/08-git-workflow.md)
- [09 - Release and Deploy](./docs/project-docs/09-release-and-deploy.md)
- [10 - Troubleshooting](./docs/project-docs/10-troubleshooting.md)
- [11 - AI Agent Handoff](./docs/project-docs/11-ai-agent-handoff.md)

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
