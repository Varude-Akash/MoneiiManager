# 02 - Environments and IDs

## Supabase projects

### Dev
- Name: `moneii-dev`
- Project ref: `enafqqntznyiyarpqvmu`
- Dashboard: `https://supabase.com/dashboard/project/enafqqntznyiyarpqvmu`

### Prod
- Name: `MoneiiManager` (existing prod project)
- Project ref: `cdfhshejzvcdhsthagpi`
- Dashboard: `https://supabase.com/dashboard/project/cdfhshejzvcdhsthagpi`

## Env files
- `.env.dev`: dev runtime values
- `.env.prod`: prod runtime values
- `.env`: active file used by Flutter app (copied from dev/prod by scripts)
- `.env.example`: template

## Required env keys
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `OPENAI_API_KEY`
- `REVENUECAT_API_KEY`

## RevenueCat
- App: `Moneii`
- Entitlement: `Moneii Pro`
- Products: `monthly`, `yearly`
- Keep API key in env files, never hardcode in source.

## Supabase functions in this repo
- `voice-transcribe`
- `moneii-ai`
- `delete-account`

## Important security notes
- Do not commit `.env`, `.env.dev`, `.env.prod`.
- Do not commit service role keys or OpenAI secret keys in docs or source.
- `supabase/.temp/*` must not be committed.
