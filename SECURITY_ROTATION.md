# Security Rotation Playbook — Apex Run

> **Status:** Phase 0 code-side scrub COMPLETE. Steps 1–7 below are external service rotations + git history scrub that **only the repo owner can perform**. Until those are done, treat every credential previously visible in this repo as compromised.

## What was exposed (and still is, in git history)

These secrets were committed to `main` and remain in git history until scrubbed:

| Secret | Last Seen At | File | Action |
|---|---|---|---|
| Supabase Anon JWT (`eyJhbGciOi…klM`) | HEAD~ | `lib/core/config/env.dart`, `seed_data.ps1`, `DEPLOY_DIGITALOCEAN.md` | **ROTATE** |
| Supabase Service Role Key | history | `backend/.env` (was committed?) | **ROTATE** (regardless) |
| Mapbox public token (`pk.eyJ1IjoiZGVlcGFrNzIzOC…Pgg`) | HEAD~ | `lib/core/config/env.dart`, `android/gradle.properties` | **ROTATE** |
| Gemini API key (`AQ.Ab8RN…HyQ`) | HEAD~ | `lib/core/config/env.dart` | **ROTATE** |
| Redis password (`Dream@885890`) | HEAD~ | `lib/core/config/env.dart`, `DEPLOY_DIGITALOCEAN.md` | **ROTATE + harden network** |
| Redis IP `134.199.187.2:6379` | HEAD~ | `lib/core/config/env.dart`, `DEPLOY_DIGITALOCEAN.md`, `CICD.md` | **Firewall + VPC** |
| Firebase API key (`AIzaSy…qsw`) | HEAD~ | `android/app/google-services.json` | **Restrict in GCP Console** |
| Supabase project ref (`voddddmmiarnbvwmgzgo`) | HEAD~ | many docs | Not a credential but exposes target |

Assume any third party that scraped GitHub between commit `23947bb` (Feb 13) and now has all of these. Rotate **every** one even if you think it's unused.

---

## Step 1 — Supabase keys

1. Open `https://supabase.com/dashboard/project/<project>/settings/api`.
2. Click **Roll** next to **anon (public) key**. Save new key.
3. Click **Roll** next to **service_role**. Save new key. **Store in 1Password / Bitwarden / Doppler — never in repo.**
4. Click **JWT Secret → Roll**. (This invalidates every active user session — accept the trade-off.)
5. Under **Database → Connection string** → copy the new postgres password OR reset under **Settings → Database → Reset database password**.

Update where credentials are consumed:
- CI (GitHub Actions → Settings → Secrets and variables → Actions): `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_KEY`, `SUPABASE_JWT_SECRET`.
- Backend production env (DigitalOcean App Platform / Droplet).
- Edge Functions (Supabase dashboard → Functions → Secrets).
- Local dev: `.env.json` (gitignored — copy from `.env.example.json`).

If you'd rather **migrate to a fresh Supabase project entirely** (recommended given the breach scope), follow `DATABASE_MIGRATION_GUIDE.md` then update every `voddddmmiarnbvwmgzgo` reference to the new ref.

## Step 2 — Mapbox tokens

1. Open `https://account.mapbox.com/access-tokens/`.
2. Find the leaked public token (`pk.eyJ1IjoiZGVlcGFr…`). Click **Delete**.
3. Create two new tokens:
   - **Public (runtime)**: scopes `styles:read`, `fonts:read`, `tiles:read`, `datasets:read`, `vision:read`. URL-restrict to `apexrun://*` + your bundle IDs.
   - **Secret (downloads)**: scope `downloads:read` only. **Never put in client.**
4. Put the public token into `.env.json` → `MAPBOX_ACCESS_TOKEN`.
5. Put the secret token into `~/.gradle/gradle.properties` (user-global, never in repo):
   ```
   MAPBOX_DOWNLOADS_TOKEN=sk.eyJ1IjoiZGVlcGFr...
   ```
6. In CI: store as GitHub Action secret `ORG_GRADLE_PROJECT_MAPBOX_DOWNLOADS_TOKEN` — Gradle picks it up automatically.

## Step 3 — Gemini API key

1. Open `https://aistudio.google.com/app/apikey` (or Vertex AI Console).
2. Delete the leaked key.
3. Create a new key. Restrict by IP allowlist (only your backend/Edge Functions). NEVER restrict to "any" or "this app's origin" — that's bypassable.
4. **Move all Gemini calls server-side.** See audit plan Section 5 — there is a Supabase Edge Function template (`coach-insight`) ready to drop in. Until that's done, the new key is at risk again.
5. Set monthly budget alerts in Google Cloud Console at $25/$100/$500 thresholds.

## Step 4 — Redis hardening

The Redis instance was internet-reachable with a weak password. This is the highest immediate risk — it can be used for RCE on some Redis versions and is a stepping stone into the backend network.

1. SSH into the host (`134.199.187.2`).
2. Edit `redis.conf`:
   ```
   bind 127.0.0.1 ::1     # localhost only
   protected-mode yes
   requirepass <new-32-char-random>
   ```
3. Generate password:
   ```bash
   openssl rand -base64 32
   ```
4. Restart Redis: `systemctl restart redis`.
5. Verify port closed externally: from another machine, `nc -vz 134.199.187.2 6379` → connection refused.
6. Backend now connects via private network (DigitalOcean VPC) or SSH tunnel. Update `REDIS_URL` accordingly (e.g. `localhost:6379` if co-located).
7. Add a firewall rule (DigitalOcean → Networking → Firewalls) blocking inbound 6379 from anything except your backend droplet's private IP.

## Step 5 — Firebase API key (google-services.json)

Firebase API keys are intended to be public **only when properly restricted**.

1. Open `https://console.cloud.google.com/apis/credentials?project=apex-run-c8fb9`.
2. Find `AIzaSyBEi5YYR60DlRgNTh_rREyEOOPZylRsqsw`.
3. Set **Application restrictions** → **Android apps**:
   - Package: `com.apexrun.app`
   - SHA-1: your release-signing cert fingerprint (run `keytool -list -keystore release.keystore -alias apexrun -storepass <pwd>`).
4. Set **API restrictions** → only the APIs you actually use (Firebase Cloud Messaging once added, Identity Toolkit if using Firebase Auth).
5. If you're fully on Supabase and never plan to use Firebase: delete `google-services.json` + remove the gradle plugin (`id("com.google.gms.google-services")` from `android/app/build.gradle.kts` and `android/settings.gradle.kts`). Cleanest.

## Step 6 — Google OAuth client IDs

Less urgent (these IDs are public-by-design) but verify restrictions:

1. Open `https://console.cloud.google.com/apis/credentials`.
2. For each OAuth 2.0 Client ID (web + iOS + Android):
   - Web: authorized redirect URIs = ONLY `https://<your-project-ref>.supabase.co/auth/v1/callback`.
   - iOS: package name = `com.apexrun.app`, no extra schemes.
   - Android: package name + release SHA-1 fingerprint.

## Step 7 — Git history scrub (DESTRUCTIVE — read first)

> ⚠️ **DESTRUCTIVE OPERATION**. This rewrites history. Any collaborator's existing clone breaks. Open PRs become invalid. CI history (commit references in deploy logs) goes stale.

Decision tree:
- **Solo repo, no public forks, no critical PRs:** scrub in place is fine.
- **Has collaborators or public forks:** consider creating a fresh repo instead — copy current `main` snapshot into a new empty repo, abandon old one (archive on GitHub or delete after grace period).

### Scrub in place

Use `git-filter-repo` (modern replacement for `filter-branch`). Install: `pip install git-filter-repo`.

```bash
# 1. Mirror-clone (work on a copy, never the working tree)
cd /tmp
git clone --mirror https://github.com/<owner>/apex_run.git apex_run.git
cd apex_run.git

# 2. Build a replacement-text file
cat > replacements.txt <<'EOF'
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZvZGRkZG1taWFybmJ2d21nemdvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA2NTE3OTcsImV4cCI6MjA4NjIyNzc5N30.i7Ni-NHsmbwaXEoyOut_26PH1PK_Xycw3ChzkvPtklM==>***REDACTED_SUPABASE_ANON***
pk.eyJ1IjoiZGVlcGFrNzIzOCIsImEiOiJjbWxnZjAwMTMwOWo5M2xzaHF3eTd1eTd6In0.cNbgPuE749GMnCztExzPgg==>***REDACTED_MAPBOX***
AQ.Ab8RN6JLx52aNNnmEVb6IoVrkCrsN5Hq3XKUW3hRn2gRKaxHyQ==>***REDACTED_GEMINI***
Dream@885890==>***REDACTED_REDIS_PWD***
AIzaSyBEi5YYR60DlRgNTh_rREyEOOPZylRsqsw==>***REDACTED_FIREBASE***
EOF

# 3. Run the rewrite
git filter-repo --replace-text replacements.txt --force

# 4. Verify no secrets remain anywhere
git log -p --all | grep -E "eyJhbGciOi|pk\.eyJ|AIza|AQ\.Ab8RN|Dream@" && echo "STILL PRESENT" || echo "CLEAN"

# 5. Force-push to GitHub (DESTRUCTIVE)
git push --force --all
git push --force --tags
```

### Then notify collaborators

```
The apex_run main branch has been rewritten to remove leaked credentials.
Your existing clone is now incompatible. Please:
  1) git fetch origin
  2) git reset --hard origin/main
  3) Delete any open branches that were based on the old history; re-create from new main.
```

### GitHub Secret Scanning

After force-push, GitHub may still display the leaked secrets in pre-rewrite cached views for ~24h. File a request via Settings → Security → Secret scanning → Bypass → Mark as revoked (this also notifies the partner service, e.g., Supabase).

---

## Step 8 — Verify the scrub locally

```bash
# Verify no live secret strings in the working tree:
grep -rE "eyJhbGciOi|pk\.eyJ|AIza|AQ\.Ab8RN|Dream@" . \
  --exclude-dir=.git --exclude-dir=build --exclude=SECURITY_ROTATION.md
# Expected: only matches inside SECURITY_ROTATION.md (this file) for documentation.

# Verify .gitignore covers env files:
git check-ignore -v .env.json
# Expected: matches the .env.*.json rule.

# Verify env.dart no longer has defaults:
grep -E "defaultValue: ['\"]\\w" lib/core/config/env.dart
# Expected: only short non-secret defaults (model name, style URL).
```

---

## Step 9 — Production keystore (Android signing)

Before any Play Store upload, replace the debug signing block:

1. Generate keystore:
   ```bash
   keytool -genkey -v -keystore ~/.android/apexrun-release.keystore \
     -alias apexrun -keyalg RSA -keysize 2048 -validity 10000
   ```
2. Store the keystore in 1Password (file attachment). Lose this = can't ship updates.
3. Create `android/key.properties` (gitignored):
   ```
   storeFile=/Users/<you>/.android/apexrun-release.keystore
   storePassword=<from-1password>
   keyAlias=apexrun
   keyPassword=<from-1password>
   ```
4. Add to `android/app/build.gradle.kts`:
   ```kotlin
   val keystoreProperties = Properties().apply {
       val f = rootProject.file("key.properties")
       if (f.exists()) load(f.inputStream())
   }

   android {
       signingConfigs {
           create("release") {
               storeFile = file(keystoreProperties["storeFile"] as String)
               storePassword = keystoreProperties["storePassword"] as String
               keyAlias = keystoreProperties["keyAlias"] as String
               keyPassword = keystoreProperties["keyPassword"] as String
           }
       }
       buildTypes {
           getByName("release") {
               signingConfig = signingConfigs.getByName("release")
               isMinifyEnabled = true
               isShrinkResources = true
           }
       }
   }
   ```
5. Enroll in **Play App Signing** at first upload — Google holds the upload key + signing key separately; if your upload key is ever compromised, recovery is possible.

---

## Step 10 — One-time abuse audit

After rotating, check whether the old keys were already abused:

1. Supabase: Dashboard → Logs → Auth + DB logs for unfamiliar IPs in the past 30 days.
2. Mapbox: Dashboard → Statistics → Token usage spikes.
3. Gemini: Cloud Console → Billing → Filter by API → spikes outside your usage windows.
4. Redis: check `redis-cli INFO commandstats` for unusual command volume.

If any look suspicious, file:
- Supabase: support@supabase.com with the project ref + window of suspicion.
- Mapbox: support@mapbox.com (may credit usage if abuse confirmed).
- Google Cloud: report via Cloud Console → Support.

---

## Quick reference — what's in this repo NOW vs MUST be

| Concern | Current state | Required state |
|---|---|---|
| Secrets in `lib/core/config/env.dart` | ✅ Removed (defaults stripped) | (keep as-is) |
| Secrets in `seed_data.ps1` | ✅ Removed (env var pull) | (keep as-is) |
| Secrets in `android/gradle.properties` | ✅ Removed | (keep as-is) |
| Secrets in `DEPLOY_DIGITALOCEAN.md` | ✅ Sanitized to placeholders | (keep as-is) |
| Old secrets in git history | ❌ Still present | Run Step 7 |
| Live Supabase / Mapbox / Gemini / Redis services | ❌ Old creds still active | Steps 1–4 |
| `.env.example.json` | ✅ Created | (commit) |
| `.gitignore` covers env files | ✅ Updated | (keep as-is) |
| `main.dart` fails fast on missing config | ✅ Asserts in debug | (keep as-is) |
| Android release signing | ❌ Debug keystore | Step 9 |
| Firebase API key restricted | ❌ Unrestricted | Step 5 |

## Timeline

| Action | Owner | Deadline |
|---|---|---|
| Steps 1–4 (rotate live keys) | Repo owner | **TODAY** |
| Step 5 (Firebase restrict) | Repo owner | Today |
| Step 7 (git scrub + force push) | Repo owner | Today |
| Step 8 (verify) | Repo owner | Today |
| Step 9 (release keystore) | Repo owner | Before Play submission |
| Step 10 (abuse audit) | Repo owner | Within 72h of rotation |
