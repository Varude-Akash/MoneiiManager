# Two-Project Workflow (Dev + Prod)

This project currently uses:

- `dev` Supabase project: `moneii-dev` (new)
- `prod` Supabase project: `cdfhshejzvcdhsthagpi` (existing live project)

Because free tier allows only 2 active projects, this is the safest flow.

## 1) One-time local setup

1. Fill `.env.dev` with `moneii-dev` values:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
   - `OPENAI_API_KEY` (if needed by client)
2. `.env.prod` is already created from the current production `.env`.
3. Switch active app env with:
   - `./scripts/use-env.sh dev`
   - `./scripts/use-env.sh prod`

## 2) Daily development

1. Switch app env to dev:
   - `./scripts/use-env.sh dev`
2. Run app:
   - `flutter run -d chrome`
3. Link Supabase CLI to dev (only once per machine/session as needed):
   - `supabase link --project-ref <DEV_PROJECT_REF>`
4. Apply backend changes to dev:
   - `supabase db push`
   - `supabase functions deploy voice-transcribe`
   - `supabase functions deploy moneii-ai`

## 3) Production release

1. Switch app env to prod:
   - `./scripts/use-env.sh prod`
2. Link Supabase CLI to prod:
   - `supabase link --project-ref cdfhshejzvcdhsthagpi`
3. Deploy backend to prod:
   - `supabase db push`
   - `supabase functions deploy voice-transcribe`
   - `supabase functions deploy moneii-ai`

## 4) Mandatory checks before prod deploy

- Auth flow works
- Add/edit/delete expense works
- Voice transcribe works
- Moneii AI works
- Premium limits/plan checks work
- `flutter analyze` passes

## 5) Security notes

- Rotate leaked keys immediately.
- Keep real keys only in local env files and Supabase secrets.
- Never commit `.env`, `.env.dev`, `.env.prod`.
