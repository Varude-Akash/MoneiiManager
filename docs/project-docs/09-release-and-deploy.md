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
6. Submit to store testing track.
7. Promote to production after policy gates are satisfied.

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

## Google Play release path (required for new personal accounts)
1. Upload AAB to `Internal testing` first for smoke testing.
2. Create `Closed testing` release and publish it.
3. Add at least 12 testers in one tester list and assign that list to the closed track.
4. Share the opt-in link and ensure testers install from Play.
5. Keep the closed test active for at least 14 days with at least 12 opted-in testers.
6. After this gate is completed, apply for production access in Play Console.
7. Create production release and submit for review.

## Versioning rule
- Every new upload (internal/closed/open/production) must have a higher Android `versionCode` than previous uploads.
