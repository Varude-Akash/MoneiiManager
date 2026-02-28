# Publishing Checklist (Play Store + App Store)

Use this checklist before every public release.

## 1) Product + Stability

- [ ] App runs with production env (`./scripts/use-prod.sh`)
- [ ] `flutter analyze` passes
- [ ] `flutter test` passes
- [ ] No blocker errors in login, home, add expense, activity, analytics, profile
- [ ] Voice entry works on production backend
- [ ] Moneii AI works and plan limits behave correctly

## 2) Backend Deployment

- [ ] Linked to production project ref (`cdfhshejzvcdhsthagpi`)
- [ ] `supabase db push` executed successfully
- [ ] Functions deployed:
  - [ ] `voice-transcribe`
  - [ ] `moneii-ai`
  - [ ] `delete-account`
- [ ] `OPENAI_API_KEY` secret set for production functions

## 3) Privacy + Legal (Required)

- [ ] Privacy Policy page available in-app
- [ ] Terms of Service page available in-app
- [ ] Account deletion available in-app (Profile > Delete Account)
- [ ] Public privacy policy URL added in store listings
- [ ] Public terms URL added in store listings

## 4) Data Safety / App Privacy Declarations

- [ ] Play Store Data safety form completed accurately
- [ ] App Store privacy nutrition labels completed accurately
- [ ] Microphone usage description is accurate
- [ ] Financial data usage purpose is accurately declared

## 5) Store Assets

- [ ] App icon finalized
- [ ] Screenshots for required device sizes
- [ ] Short description + full description finalized
- [ ] Support email and website configured

## 6) Release Process

- [ ] Release branch merged to `main`
- [ ] Production backend deployment done from latest `main`
- [ ] Internal testing pass completed
- [ ] Closed testing release published
- [ ] At least 12 testers opted in to closed testing
- [ ] Closed test has run for at least 14 days (for personal Play account production access)
- [ ] Staged rollout enabled (recommended)

## 7) Security

- [ ] Leaked keys rotated (OpenAI/service role if exposed)
- [ ] No secrets committed in git
- [ ] `.env*` files remain ignored
