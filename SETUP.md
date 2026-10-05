# An Toàn: Setup (Windows)

Do these in order. Each step says what you should see when it works.
If anything fails, copy the exact error text and give it to Claude Code.

---

## Step 1: Create the two accounts (about 10 minutes)

### 1a. Anthropic (Claude) API key
1. Go to https://console.anthropic.com/settings/keys and sign in.
2. Click **Create Key**, copy it into a private note.
3. **Never** paste it into chat, a screenshot, a file in the repo, or GitHub.
4. In the Anthropic Console billing settings, set a spending limit so costs can't run away.

### 1b. Supabase project
1. Go to https://supabase.com/dashboard, click **New project**. Pick a region near you (Singapore is closest).
2. Write down the **database password** (you may never need it again, but keep it private).
3. When the project is ready, open **Project Settings, then API**. Note down:
   - **Project URL**, like `https://abcdxyz.supabase.co`
   - **Project ref**, the `abcdxyz` part
   - the **anon / publishable key** (this one is allowed to be in the app)
4. Do **not** use the `service_role` key anywhere in the app.

---

## Step 2: Put the code in your repo

```powershell
git clone https://github.com/phuvo1304-alt/an-toan.git
cd an-toan
```

Copy everything from the folder Claude gave you (`lib/`, `supabase/`, `l10n.yaml`, `.gitignore`, `CLAUDE.md`, `SETUP.md`) into this repo folder.
**Check `.gitignore` is there before your first commit.**

Create the Flutter platform folders (android/ios) without overwriting my files:

```powershell
flutter create . --org vn.antoan --project-name an_toan --platforms android,ios
```

If it asks about overwriting `lib/main.dart`, keep **my** version (or just re-copy `lib/` afterwards).

---

## Step 3: Add the packages

```powershell
flutter pub add flutter_riverpod go_router http shared_preferences image_picker
flutter pub add flutter_localizations --sdk=flutter
flutter pub add intl:any
```

Now open `pubspec.yaml`, find the `flutter:` section near the bottom, and add `generate: true` right under it:

```yaml
flutter:
  generate: true
  uses-material-design: true
```

Then:

```powershell
flutter pub get
flutter gen-l10n
```

You should see no errors, and a file `lib/l10n/app_localizations.dart` is created for you.
If it is NOT there, tell Claude Code: "gen-l10n put the file somewhere else". Newer Flutter versions
changed where the generated file goes, and the imports in my code may need a one-line fix.

---

## Step 4: Allow internet in release builds (easy to forget)

Open `android/app/src/main/AndroidManifest.xml` and add this line just above `<application ...>`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

Without it, debug works but the **release** app cannot reach the internet.

---

## Step 5: Deploy the backend

Needs Node.js. We use `npx` so you don't have to install the Supabase CLI.

```powershell
npx supabase@latest login
npx supabase@latest link --project-ref YOUR_PROJECT_REF
npx supabase@latest secrets set ANTHROPIC_API_KEY=PASTE_YOUR_KEY_HERE
npx supabase@latest functions deploy analyze-scam
```

Type the key only in your own terminal. Do not paste it into chat.

Optional: change the model without redeploying code:
```powershell
npx supabase@latest secrets set CLAUDE_MODEL=claude-haiku-4-5-20251001
```
The default in the code is `claude-haiku-4-5-20251001`. If the function logs say the model is not found (or that name stops working), check https://docs.claude.com/en/docs/about-claude/models for the current name.

**If the app gets a 401 error:** newer Supabase projects use "publishable" keys that are not JWTs. Redeploy with:
```powershell
npx supabase@latest functions deploy analyze-scam --no-verify-jwt
```
(The function still has its own size limits and per-device rate limit.)

### Test the backend before touching the app

```powershell
$body = '{"text":"Chuc mung ban trung tuyen hoc bong 100%. Chuyen 2 trieu phi ho so vao STK 123456 trong hom nay, khong se mat suat.","language":"vi","device_id":"test1"}'
Invoke-RestMethod -Method Post -Uri "https://YOUR_PROJECT_REF.supabase.co/functions/v1/analyze-scam" `
  -Headers @{ "Authorization" = "Bearer YOUR_ANON_KEY"; "apikey" = "YOUR_ANON_KEY" } `
  -ContentType "application/json" -Body $body
```

You should see `risk_level` of `likely_scam` with red flags in Vietnamese.
If you see an error, run `npx supabase@latest functions logs analyze-scam` (or open Edge Functions, Logs in the dashboard) and give the error to Claude Code.

---

## Step 5b: Database for the Phone Checker

The Phone Checker stores community reports in Postgres. The table and its two
functions are in `supabase/migrations/`. Apply them to your project (uses the
link from Step 5; it may ask for the database password from Step 1b):

```powershell
npx supabase@latest db push
```

It lists the migrations it will apply and asks you to confirm. Run it again
whenever a new file appears in `supabase/migrations/`.

There is no secret to set by hand. Device IDs are hashed with a random salt that
the migration creates inside the database (table `private.app_settings`, which the
app cannot read). It is never in Git, chat or on your laptop. Do not change or delete
it, or the per-phone report limit restarts for everyone.

(An older version of this guide said to run `alter database postgres set app.report_salt = ...`.
Hosted Supabase refuses that with "permission denied", so the salt moved to that table.)

---

## Step 6: Run the app on your Android phone

1. On the phone: enable Developer options, then USB debugging. Plug it in.
2. `flutter devices` should list your phone.
3. Run:

```powershell
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

You should see the Home screen with four cards. "Check a message" opens the checker. Paste a suspicious message and tap Check.

---

## Step 7: Commit

```powershell
git add .
git status
```

Read the `git status` list. If you see `.env`, a `.jks`, or any key, **stop** and ask Claude Code.

```powershell
git commit -m "Day 1: project skeleton, text and screenshot scam checker"
git push
```

---

## What works after this, and what does not

Works:
- Home, and the vi/en switch in Settings.
- Text check and screenshot check, with the result screen and disclaimer.
  The backend (`analyze-scam` Edge Function) uses Anthropic's Claude API, not Gemini,
  with a rule-based pattern pre-check that gives Claude a hint.
- Quiz: 12 bilingual questions bundled in the app, shuffled every round, with the
  best score and best streak saved on the phone.
- Phone Checker: look up how many users reported a Vietnamese mobile number (by category,
  with the last report date) and report a number. Needs Step 5b done first.

Not built yet: audio check, training, onboarding, privacy policy page, store builds.
Home shows "Coming soon" for the Training card.
