# 11 - AI Agent Handoff

This file is for any new coding agent that gets this repository.

## What cannot be inferred from code alone
- Two Supabase environments are actively used.
- Dev project ref: `enafqqntznyiyarpqvmu`.
- Prod project ref: `cdfhshejzvcdhsthagpi`.
- Env switching happens by copying `.env.dev/.env.prod` to `.env` via scripts.
- RevenueCat is integrated and requires dashboard configuration to match code identifiers.

## Non-code operational assumptions
- `supabase login` already done locally.
- Migrations are source-controlled; deployment is explicit (`supabase db push`).
- Reference seed SQL must be applied for fresh projects.
- Edge function secrets are per-project and must be set separately.

## High-priority identifiers
- RevenueCat entitlement: `Moneii Pro`
- RevenueCat products: `monthly`, `yearly`
- Android package id: `com.moneii.moneii_manager`
- iOS bundle id: `com.moneii.moneiiManager`

## First commands an agent should run
```bash
git status
./scripts/use-dev.sh
flutter pub get
flutter analyze
```

## Before any deploy
1. Confirm current linked Supabase project ref.
2. Confirm correct env selected (`dev` vs `prod`).
3. Confirm migrations/functions/secrets in target project.

## Before any commit
1. Avoid committing `.env*` secrets.
2. Restore Supabase temp files if changed:
```bash
git restore supabase/.temp/pooler-url supabase/.temp/project-ref
```
3. Run quality checks (`flutter analyze`, optionally `flutter test`).
