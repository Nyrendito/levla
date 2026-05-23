# Levla

A smart fridge & cooking app for iOS. Levla helps you cook with what you already have before it goes bad.

Native SwiftUI · iOS 18+ · Supabase backend · Vision-based receipt OCR and food classification.

---

## What's in the box

| Layer | Tech |
|---|---|
| UI | SwiftUI, Manrope variable font, iOS 18 features (Observation, `@Observable`, modern TabView, Sign in with Apple) |
| Backend | [Supabase](https://supabase.com) (Postgres + auth) via the official [supabase-swift SDK](https://github.com/supabase/supabase-swift) |
| Auth | Email + password, Sign in with Apple |
| Camera (photos) | `AVCaptureSession` + `AVCapturePhotoOutput` |
| Camera (barcodes) | `AVCaptureMetadataOutput` — live scanning of EAN-13, UPC-E, Code 128, QR, PDF417, etc. |
| Receipt OCR | `VNRecognizeTextRequest` (accurate, language-corrected) — runs on device, raw text sent to GPT-4.1-mini |
| Fridge vision | **GPT-4o** via a Supabase Edge Function (`scan-fridge`) — multi-shelf identification |
| Receipt parsing | **GPT-4.1-mini** via a Supabase Edge Function (`scan-receipt`) — turns OCR text into structured items |
| Barcode lookup | Open Food Facts via a Supabase Edge Function (`lookup-barcode`) |
| Storage (offline) | In-memory fallback that mirrors the Supabase schema, so you can run the app cold without credentials |

---

## Quick start

### 1. Generate the Xcode project

```bash
brew install xcodegen           # if you haven't
cd "fridge app"
xcodegen generate
open Levla.xcodeproj
```

### 2. Run

Build & run `Levla` on an iOS 18 simulator or device. With no Supabase credentials the app launches into an **offline demo mode** using `SeedData` — you'll land on the Home screen as "Eva" with a stocked fridge.

### 3. Connect Supabase (optional but recommended)

1. Create a project at [supabase.com](https://supabase.com).
2. Run the entire `supabase/schema.sql` in the SQL editor. It creates `profiles`, `food_items`, `shopping_items`, `recipe_favourites`, with RLS policies and a profile-on-signup trigger.
3. Deploy the three Edge Functions (full instructions in [`supabase/README.md`](supabase/README.md)):
   ```bash
   supabase secrets set OPENAI_API_KEY=sk-...
   supabase functions deploy scan-fridge
   supabase functions deploy scan-receipt
   supabase functions deploy lookup-barcode
   ```
4. Open `Levla/App/Info.plist` and add:

```xml
<key>SUPABASE_URL</key>
<string>https://YOUR_PROJECT.supabase.co</string>
<key>SUPABASE_ANON_KEY</key>
<string>YOUR_ANON_KEY</string>
```

5. Re-run. The welcome screen now leads into real Sign up / Sign in, and Scan fridge / Scan receipt / Scan barcode hit the deployed edge functions. Sign in with Apple works once you wire your Apple Developer team in Xcode and add the Apple provider in Supabase Auth → Providers.

### 4. Camera permissions

The Info.plist is pre-populated with `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`, and `NSMicrophoneUsageDescription`. The simulator doesn't have a real camera — for OCR / classification testing, run on a device or use the simulator's "Features → Camera → Add Photo" trick.

---

## Architecture

```
Levla/
├── App/                    LevlaApp entry + AppState
├── Design/                 Tokens + Components (BigCTA, FoodOrb, Dial, etc.)
│   └── Fonts/              Manrope-Variable.ttf + JetBrainsMono-Medium.ttf
├── Features/
│   ├── Auth/               Welcome + Sign in/up + Sign in with Apple
│   ├── Main/               MainTabView with floating tab bar + Scan FAB
│   ├── Home/               Tracking-style dashboard
│   ├── Fridge/             Inventory with status tiles + categories
│   ├── Cook/               Tinder-style recipe deck + Recipe detail
│   ├── Shopping/           Shopping list with big checkboxes
│   └── Scan/               Bottom sheet + Camera + Vision verify flow
├── Models/                 FoodItem, Recipe, ShoppingItem, Profile, SeedData
└── Services/               SupabaseClient, AuthService, FridgeService,
                            ShoppingService, CameraController, VisionRecognizer
```

---

## Design fidelity vs the source mockup

This implementation faithfully follows the v2 design from the handoff bundle (`fridge/project/app/v2/`):

- **Tracking-style Home** — brand row + 7-day strip with dashed circles, swipeable stat carousel (Fresh hero / Mini stats / Fridge Score), recently added, cook tonight.
- **Tab bar** — floating pill, 4 tabs around a center coral Scan FAB.
- **Fridge** — 4 colored status tiles (Today/Soon/Fresh/Low), category grid, big food pills sorted by urgency.
- **Cook** — full Tinder-style swipe deck with SKIP/SAVE/COOK NOW stamps and a 5-button action row.
- **Recipe detail** — hero FoodOrb, pop reason badge, 4-up stat row, ingredient list with use-today/low/buy chips, numbered steps.
- **Shopping** — black progress card with checked / total, grouped sections, 30pt checkboxes, household partner avatars.
- **Scan flow** — bottom sheet with 2 big primary choices (Scan fridge / Scan receipt) + 3 mini rows (Barcode / Voice / Manual). The fridge flow takes **one full-fridge photo** and sends it to GPT-4o; the receipt flow OCRs on device then sends the text to GPT-4.1-mini; the barcode flow runs **live AVCaptureMetadataOutput** detection then resolves the code via Open Food Facts. All three converge on a shared "Just checking" verify screen.
- **Food art** — color-block placeholders (FoodOrb + FoodTile + FoodIllustration). Per the chat transcripts, the designer chose abstract food art over real photos.
- **Typography** — Manrope variable font everywhere, with JetBrains Mono for the small mono labels.
- **Color tokens** — warm cream paper, dark ink, sage mint (fresh), clay coral (use soon / primary accent), sun (low stock), rose (expiring today).

---

## Decisions & trade-offs

- **Variable font** — bundled a single `Manrope-Variable.ttf` instead of five static weights to keep the bundle small. SwiftUI handles weight selection via `.fontWeight()`.
- **Food art** — kept the design's intentional abstract orbs. They render in any locale, don't need image rights, and stay on-brand.
- **VNClassifyImageRequest** — Apple's bundled classifier covers thousands of categories. Specific fridge inventory work would benefit from a fine-tuned Core ML model later, but the keyword mapper in `VisionRecognizer.foodKeyword(for:)` covers the common cases. A fallback list ensures the verify screen always has something to confirm.
- **Receipt OCR** — `VNRecognizeTextRequest.accurate` + a parser that strips totals, dates, currency, and quantity markers, then maps to the app's food keys.
- **Sign in with Apple** — wired end-to-end (nonce, SHA-256, ID token forwarding to Supabase), but **disabled by default** because the capability requires a paid Apple Developer Program account. To enable: (1) join the Apple Developer Program; (2) add the "Sign in with Apple" capability in Xcode (Signing & Capabilities tab); (3) flip `AuthView.enableAppleSignIn = true`; (4) enable the Apple provider in your Supabase project's Auth settings.
- **Offline mode** — without Supabase creds the app silently uses an in-memory store + seed data. This lets you demo every screen without provisioning a backend.
- **Recipes** — ship locally in `SeedData.recipes`. In production you'd move these to a `recipes` table; the data model is already JSON-serializable.

---

## Roadmap (next obvious steps)

- Server-side recipe table (currently local) + cooked / favourited log
- Voice-add via `SFSpeechRecognizer`
- Notification scheduling for items expiring tomorrow
- Receipt photo upload to a Supabase storage bucket per user
- Real-time partner sync on the shopping list (Supabase Realtime subscriptions)
- Onboarding tutorial flow (currently only welcome → auth — the design has 7 onboarding steps)
- Settings + sign-out menu

---

## Files generated outside this codebase

- `project.yml` — XcodeGen config. Run `xcodegen generate` to produce `Levla.xcodeproj`.
- `supabase/schema.sql` — copy-paste-ready SQL. Idempotent (`if not exists`, drop-and-recreate policies).

---

## Credit

The design system, color palette, and screen structure follow the v2 mockup from `fridge/project/app/v2/` in the handoff bundle.
