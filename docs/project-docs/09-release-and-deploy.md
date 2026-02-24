# 09 - Release and Deploy

## Dev deploy (backend)
```bash
./scripts/use-dev.sh
supabase link --project-ref enafqqntznyiyarpqvmu
supabase db push
supabase functions deploy voice-transcribe
supabase functions deploy moneii-ai
supabase functions deploy delete-account
supabase secrets set OPENAI_API_KEY=<YOUR_OPENAI_KEY>
```

## Prod deploy (backend)
```bash
./scripts/use-prod.sh
supabase link --project-ref cdfhshejzvcdhsthagpi
supabase db push
supabase functions deploy voice-transcribe
supabase functions deploy moneii-ai
supabase functions deploy delete-account
supabase secrets set OPENAI_API_KEY=<YOUR_OPENAI_KEY>
```

## Release code flow
1. Merge feature PRs into `develop`.
2. Validate in dev.
3. Merge `develop` -> `main`.
4. Deploy backend to prod.
5. Build release binaries.
6. Submit to stores.

## Build commands
### Android
```bash
flutter build appbundle --release
```

### iOS
```bash
flutter build ipa --release
```

## Optional release tagging
```bash
git checkout main
git pull origin main
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0
```
