# Levla — Supabase backend

This folder contains everything the Levla iOS app needs from Supabase:

- `schema.sql` — tables + RLS policies. Run top-to-bottom in the SQL editor.
- `functions/` — three Deno Edge Functions:
  - `scan-fridge` — GPT-4o vision: shelf-by-shelf fridge identification.
  - `scan-receipt` — GPT-4.1-mini: parses Apple-Vision-OCR'd receipt text.
  - `lookup-barcode` — Open Food Facts product lookup by barcode.

## Prerequisites

```bash
brew install supabase/tap/supabase    # the Supabase CLI
supabase login
```

## One-time setup

```bash
cd "fridge app"

# Link to your project (find the ref in your Supabase dashboard URL).
supabase link --project-ref YOUR_PROJECT_REF

# Set the OpenAI key as a function secret.
supabase secrets set OPENAI_API_KEY=sk-...

# Deploy all three functions.
supabase functions deploy scan-fridge
supabase functions deploy scan-receipt
supabase functions deploy lookup-barcode
```

## Schema

Open the Supabase dashboard → SQL editor → paste in `schema.sql` → run. It's
idempotent (`if not exists` + drop/recreate policies), so re-running is safe.

## Smoke-testing the functions

```bash
# replace with your project ref + anon key
PROJECT=YOUR_PROJECT_REF
ANON_KEY=YOUR_ANON_KEY

# scan-receipt — text only, easy to test
curl -X POST "https://$PROJECT.supabase.co/functions/v1/scan-receipt" \
  -H "Authorization: Bearer $ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"text":"DANONE SKYR 0%  2.49\nCHICKEN BREAST  6.80\nEGGS X12  3.20\nCUCUMBER  0.89\nTOTAL  13.38"}'

# lookup-barcode — Nutella, a famously cataloged item on Open Food Facts
curl -X POST "https://$PROJECT.supabase.co/functions/v1/lookup-barcode" \
  -H "Authorization: Bearer $ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"code":"3017620422003"}'
```

## How the iOS app calls these

The iOS client uses the official Supabase Swift SDK's `client.functions.invoke(...)`.
All three functions require a valid user session JWT (the default Edge Function
auth setting). If the app is in offline-demo mode, the client falls back to
local-only behavior — see [`AIScanService.swift`](../Levla/Services/AIScanService.swift).

## Email confirmation

Supabase's email/password auth ships with **email confirmation required** by default. If you sign up via the iOS app while that's on, you'll get a user row with `email_confirmed_at = null` and **no session JWT** — every subsequent backend call returns 401 (including the scan-fridge function).

Two ways to handle it:

**A. Recommended for development — turn it off:**
Supabase dashboard → **Authentication → Sign In / Up → Email** → toggle off **Confirm email** → Save. Sign-up now logs you in immediately.

**B. Keep it on (production behavior):**
Sign up → check inbox → click the confirmation link → return to the app → tap "Already have an account? Sign in" with the same credentials.

If you already have a stuck unconfirmed user, force-confirm them with:

```sql
update auth.users
set email_confirmed_at = now()
where email = 'YOUR_EMAIL' and email_confirmed_at is null;
```

## OAuth providers (Continue with Google / Apple)

The iOS app's welcome screen offers Sign in with **Google** and **Apple** via Supabase's hosted OAuth flow + `ASWebAuthenticationSession`. The redirect URL the app expects is `levla://login-callback` — already registered in the Info.plist via `project.yml`.

### Google

1. [Google Cloud Console](https://console.cloud.google.com/apis/credentials) → create / select a project.
2. **Credentials → Create credentials → OAuth client ID** → application type **Web application** (NOT iOS — Supabase handles the callback).
3. **Authorized redirect URIs** → add:
   ```
   https://cinsozlrpmqbbalivxza.supabase.co/auth/v1/callback
   ```
4. Copy the **Client ID** and **Client secret**.
5. In Supabase dashboard → **Authentication → Providers → Google** → enable, paste both, save.
6. Add `levla://login-callback` to **Authentication → URL Configuration → Redirect URLs** (so Supabase will redirect back to the iOS app after the Google callback completes).

That's it. Tap **Continue with Google** in the app and it opens an in-app Safari sheet with Google's consent screen.

### Apple

Sign in with Apple via Supabase requires the **paid Apple Developer Program** ($99/yr) because Apple's Service ID setup lives behind it.

1. [developer.apple.com](https://developer.apple.com) → **Certificates, IDs & Profiles → Identifiers** → register a **Services ID** (e.g. `app.levla.signin`).
2. On the Services ID → enable **Sign in with Apple** → configure → Primary App ID = your iOS app's bundle ID (`com.nyrendito.levla`) → Web Domain = `cinsozlrpmqbbalivxza.supabase.co` → Return URL = `https://cinsozlrpmqbbalivxza.supabase.co/auth/v1/callback`.
3. **Keys** → create a new **Sign in with Apple** key, download the `.p8`.
4. In Supabase dashboard → **Authentication → Providers → Apple** → enable → paste **Services ID**, **Team ID**, **Key ID**, and the contents of the `.p8`.
5. Add `levla://login-callback` to **Authentication → URL Configuration → Redirect URLs**.

Until that's all set up, the **Continue with Apple** button will surface a Supabase error when tapped — Google works independently.

## Cost notes

Per [OpenAI pricing](https://openai.com/api/pricing/) at the time of writing:
- `gpt-4o` vision ≈ \$2.50 / 1M input tokens, \$10 / 1M output. A 3-shelf fridge
  scan returning ~15 items typically lands at well under one US cent.
- `gpt-4.1-mini` ≈ \$0.40 / 1M input tokens. A receipt parse is a fraction of a cent.
- Open Food Facts is free.
