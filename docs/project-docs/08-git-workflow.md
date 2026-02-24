# 08 - Git Workflow

## Branch model
- `main`: production-ready only
- `develop`: integration branch
- `feature/*`: active feature work
- `hotfix/*`: urgent production fixes

## Start new work
```bash
git checkout develop
git pull origin develop
git checkout -b feature/<short-name>
```

## During work
```bash
git add -A
git commit -m "<clear message>"
git push -u origin feature/<short-name>
```

## Merge flow
1. PR: `feature/*` -> `develop`
2. Test in dev environment.
3. PR: `develop` -> `main` for release.

## Hotfix flow
```bash
git checkout main
git pull origin main
git checkout -b hotfix/<short-name>
# fix
git add -A
git commit -m "Hotfix: <message>"
git push -u origin hotfix/<short-name>
```
Then merge hotfix to `main`, and merge `main` back into `develop`.

## Important hygiene
- Never commit secrets.
- Before commit, restore Supabase temp link files if they changed:
```bash
git restore supabase/.temp/pooler-url supabase/.temp/project-ref
```
- Check status before push:
```bash
git status
```
