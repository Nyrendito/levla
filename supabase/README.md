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

## Cost notes

Per [OpenAI pricing](https://openai.com/api/pricing/) at the time of writing:
- `gpt-4o` vision ≈ \$2.50 / 1M input tokens, \$10 / 1M output. A 3-shelf fridge
  scan returning ~15 items typically lands at well under one US cent.
- `gpt-4.1-mini` ≈ \$0.40 / 1M input tokens. A receipt parse is a fraction of a cent.
- Open Food Facts is free.
