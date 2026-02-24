# 04 - Supabase Runbook

## One-time local auth
```bash
supabase login
```

## Link to dev
```bash
supabase link --project-ref enafqqntznyiyarpqvmu
```

## Link to prod
```bash
supabase link --project-ref cdfhshejzvcdhsthagpi
```

## Apply migrations
```bash
supabase db push
```

## Deploy functions
```bash
supabase functions deploy voice-transcribe
supabase functions deploy moneii-ai
supabase functions deploy delete-account
```

## Set function secret(s)
```bash
supabase secrets set OPENAI_API_KEY=<YOUR_OPENAI_KEY>
```

## Seed reference data
Run `supabase/seed/seed_reference_data.sql` in SQL editor for each environment.

This is required to avoid category/account lookup failures for fresh projects.

## Current function JWT mode
In `supabase/config.toml` all three functions currently have:
- `verify_jwt = false`

That means functions are public endpoints. App still sends auth token, but function will not enforce JWT at gateway level.

Recommended future hardening:
- switch to `verify_jwt = true`
- enforce auth inside functions consistently
- use service role only inside edge functions where needed

## Common Supabase checks
- Confirm you are linked to expected project before deploy:
```bash
cat supabase/.temp/project-ref
```
- Confirm functions are present in dashboard: Edge Functions list.
- Confirm migrations applied in dashboard: Database > Migrations.
