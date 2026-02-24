# Moneii Operations Playbook (Dev + Prod + Git)

This is the single guide to run your app safely with your current free-tier setup.

For complete structured documentation, start here:
- `docs/project-docs/README.md`

Current environment model (current repo status):

- Dev Supabase project: `moneii-dev` (`enafqqntznyiyarpqvmu`)
- Prod Supabase project: `cdfhshejzvcdhsthagpi`
- No staging project (free-tier limit)
- Git branch currently present: `main`

---

## 0) One-Time Setup Checklist

### 0.1 Required local files

- `.env.dev` (dev keys)
- `.env.prod` (prod keys)
- `.env` (active file used by app)
- Include `REVENUECAT_API_KEY` in both env files for subscriptions.

Switch active env:

```bash
./scripts/use-dev.sh
./scripts/use-prod.sh
```

### 0.2 Supabase CLI login and link

```bash
supabase login
supabase link --project-ref enafqqntznyiyarpqvmu
```

### 0.3 Initialize dev backend

```bash
supabase db push
supabase functions deploy voice-transcribe
supabase functions deploy moneii-ai
supabase functions deploy delete-account
supabase secrets set OPENAI_API_KEY=<YOUR_OPENAI_KEY>
```

### 0.4 Seed shared reference data (important)

Run SQL from:

- `supabase/seed/seed_reference_data.sql`

Reason: without seeded categories, expense insert can fail with 409 conflict.

---

## 1) What To Do Right Now (Exact Current Situation)

You currently have local file changes. Do these in order:

1. Switch app env to dev:

```bash
./scripts/use-dev.sh
```

2. Run and test app:

```bash
flutter pub get
flutter run -d chrome
```

3. Test core flows:

- Sign up / login
- Add expense
- Edit and delete expense
- Voice add
- Moneii AI open and ask
- Analytics and profile load

4. Run checks:

```bash
flutter analyze
flutter test
```

5. Create proper Git branch model (one-time):

```bash
git checkout main
git pull
git checkout -b develop
git push -u origin develop
```

6. Put current local work into a feature branch:

```bash
git checkout -b feature/dev-prod-ops-setup
git add -A
git commit -m "Add env switch scripts and operations playbook"
git push -u origin feature/dev-prod-ops-setup
```

7. Open PR:
- `feature/dev-prod-ops-setup` -> `develop`

8. After PR merge, keep working from `develop` (not directly from main).

---

## 2) Git Workflow (Detailed, Every Time)

### 2.1 Branch policy

- `main`: production-ready code only
- `develop`: integration branch for ongoing work
- `feature/*`: each task/feature/fix
- Optional: `hotfix/*` from `main` for urgent prod bug

### 2.2 Start new work

```bash
git checkout develop
git pull
git checkout -b feature/<short-name>
```

Examples:

- `feature/voice-error-copy-fix`
- `feature/premium-limit-ui`
- `feature/export-pdf-csv`

### 2.3 During work

- Commit small and clear:

```bash
git add -A
git commit -m "Short meaningful message"
```

- Push branch:

```bash
git push -u origin feature/<short-name>
```

### 2.4 Open PR

- PR target should be `develop` (not `main`).
- Run checks before marking ready:
  - `flutter analyze`
  - `flutter test`
  - app smoke test on dev backend

### 2.5 Promote to production code

- When a release is ready, open PR:
  - `develop` -> `main`

### 2.6 Hotfix production bug

```bash
git checkout main
git pull
git checkout -b hotfix/<short-name>
```

- Fix + test + push.
- PR `hotfix/* -> main`.
- After merge, also merge `main -> develop` so branches stay aligned.

### 2.7 Commit hygiene rules

- Do NOT commit secrets (`.env`, `.env.dev`, `.env.prod`).
- Do NOT commit Supabase local temp files (`supabase/.temp/*`) if they appear.
- Commit migration SQL and function code when backend changes.

---

## 3) Daily Development Routine (Env + Backend)

1. Switch to dev env:

```bash
./scripts/use-dev.sh
```

2. Run app and build feature:

```bash
flutter run -d chrome
```

3. If you changed migrations/functions:

```bash
supabase link --project-ref enafqqntznyiyarpqvmu
supabase db push
supabase functions deploy voice-transcribe
supabase functions deploy moneii-ai
supabase functions deploy delete-account
```

4. Pre-push checks:

```bash
flutter analyze
flutter test
```

5. Commit/push with feature branch flow from section 2.

---

## 4) Production Release Routine (Only When Ready)

1. Switch app to prod env:

```bash
./scripts/use-prod.sh
```

2. Link CLI to prod:

```bash
supabase link --project-ref cdfhshejzvcdhsthagpi
```

3. Deploy backend:

```bash
supabase db push
supabase functions deploy voice-transcribe
supabase functions deploy moneii-ai
supabase functions deploy delete-account
```

4. Smoke test with prod account.

5. Build and publish app.

6. Optional release tag:

```bash
git checkout main
git pull
git tag -a v0.1.0 -m "Release v0.1.0"
git push origin v0.1.0
```

---

## 5) Common Errors and Fixes

### Error: `POST /rest/v1/expenses 409 Conflict`

Cause:
- category/account reference missing in DB (usually categories not seeded).

Fix:
- run `supabase/seed/seed_reference_data.sql` in current project.

### Error: `404` on `profiles` / `expenses`

Cause:
- schema/migrations not applied to that project.

Fix:

```bash
supabase db push
```

### Error: Voice CORS / function unavailable

Cause:
- function not deployed or missing secret.

Fix:

```bash
supabase functions deploy voice-transcribe
supabase secrets set OPENAI_API_KEY=<YOUR_OPENAI_KEY>
```

### Error: Login works on prod but not dev

Cause:
- users are separate per project.

Fix:
- create/login with a user in the currently active project.

---

## 6) Security Rules (Must Follow)

- Never paste keys in screenshots/chats.
- Rotate leaked keys immediately.
- Keep real keys only in local env files and Supabase secrets.
- Never test random experiments on prod project.

---

## 7) Quick Command Cheat Sheet

```bash
# Switch environment
./scripts/use-dev.sh
./scripts/use-prod.sh

# Dev backend deploy
supabase link --project-ref enafqqntznyiyarpqvmu
supabase db push
supabase functions deploy voice-transcribe
supabase functions deploy moneii-ai
supabase functions deploy delete-account
supabase secrets set OPENAI_API_KEY=<YOUR_OPENAI_KEY>

# Prod backend deploy
supabase link --project-ref cdfhshejzvcdhsthagpi
supabase db push
supabase functions deploy voice-transcribe
supabase functions deploy moneii-ai
supabase functions deploy delete-account

# Quality checks
flutter analyze
flutter test

# Git one-time setup
git checkout main
git pull
git checkout -b develop
git push -u origin develop

# Git new feature
git checkout develop
git pull
git checkout -b feature/<name>
git add -A
git commit -m "message"
git push -u origin feature/<name>
```
