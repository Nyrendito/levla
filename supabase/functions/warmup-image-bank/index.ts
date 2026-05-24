// supabase/functions/warmup-image-bank — one-shot batch image generator.
// Generates Imagen 4 product shots for a list of food keys and writes them
// to image_cache. Skips keys that are already cached unless `force` is set.
//
// Gated by a shared-secret header (X-Warmup-Secret) — NOT exposed to end
// users. Used to pre-warm the cache so common ingredients show their
// real photos instantly when the iOS app first asks for them.
//
// Body: { keys?: string[], force?: boolean, limit?: number }
// Returns: { processed, generated, errors, remaining, total_keys, already_cached }
//
// To run a full pre-warm after the Imagen daily quota resets:
//   for i in {1..30}; do
//     curl -s -X POST "$SUPABASE_URL/functions/v1/warmup-image-bank" \
//       -H "X-Warmup-Secret: levla-warmup-2026" \
//       -H "Content-Type: application/json" \
//       -d '{"limit": 4}'
//     sleep 12
//   done

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.0";

const BUCKET = "food-images";
const MODEL = "imagen-4.0-generate-001";
const WARMUP_SECRET = "levla-warmup-2026";

const DEFAULT_KEYS = [
  "milk","yogurt","butter","feta","egg","cream","cheese","mozzarella","cheddar","ricotta",
  "spinach","broccoli","tomato","carrot","pepper","lemon","lime",
  "garlic","ginger","onion","avocado","potato","sweet-potato",
  "mushroom","cucumber","zucchini","lettuce","cabbage",
  "corn","peas","asparagus","celery","leek","eggplant","beet","radish",
  "pumpkin","cauliflower","green-beans","kale","arugula",
  "basil","parsley","cilantro","dill","thyme","rosemary","mint",
  "chicken","salmon","beef","tuna","shrimp","tofu","bacon","ham","sausage","pork","lamb",
  "turkey","duck","crab","lobster",
  "rice","pasta","oil","bread","pesto","parmesan",
  "oats","quinoa","flour","sugar","honey","jam",
  "chickpeas","black-beans","lentils","almonds","peanut-butter",
  "soy-sauce","ketchup","mustard","mayo","hummus","olives","pickles",
  "apple","banana","orange","strawberry","blueberry","raspberry",
  "mango","pineapple","grape","watermelon","peach","pear","kiwi","pomegranate",
  "wine","water","juice","coffee","tea",
];

const INGREDIENT_HINTS: Record<string, string> = {
  "milk": "a single clear glass bottle of fresh whole milk",
  "yogurt": "a small clear cup of plain white yogurt",
  "butter": "a single rectangular stick of yellow butter",
  "feta": "a chunk of white feta cheese on a small white plate",
  "egg": "two large brown chicken eggs",
  "cream": "a small clear glass bottle of heavy cream",
  "cheese": "a small wedge of pale yellow cheddar cheese",
  "mozzarella": "a fresh round white ball of mozzarella cheese",
  "cheddar": "a small wedge of bright orange cheddar cheese",
  "ricotta": "a small white bowl of fresh white ricotta cheese",
  "spinach": "a small bunch of fresh dark green spinach leaves",
  "broccoli": "a single fresh head of bright green broccoli",
  "tomato": "a single round ripe red tomato with a green stem",
  "carrot": "a single whole bright orange carrot with a green leafy top",
  "pepper": "a single shiny red bell pepper",
  "lemon": "a single bright yellow whole lemon",
  "lime": "a single bright green whole lime",
  "garlic": "a single whole white garlic bulb (head of garlic), papery white skin",
  "ginger": "a single fresh raw ginger root, knobby beige rhizome",
  "onion": "a single whole yellow onion with papery brown skin",
  "avocado": "a single whole dark green ripe avocado",
  "potato": "a single whole russet potato with brown skin",
  "sweet-potato": "a single whole sweet potato with reddish-orange skin",
  "mushroom": "three whole white button mushrooms",
  "cucumber": "a single whole long green cucumber with smooth skin",
  "zucchini": "a single whole green zucchini",
  "lettuce": "a single small head of green leaf lettuce",
  "cabbage": "a single small head of green cabbage",
  "corn": "a single ear of yellow corn with green husk pulled back",
  "peas": "a small white bowl of fresh green peas",
  "asparagus": "a small bunch of fresh green asparagus spears",
  "celery": "three fresh green celery stalks bound together",
  "leek": "a single fresh whole green leek",
  "eggplant": "a single whole dark purple eggplant",
  "beet": "a single whole red beetroot with green leafy tops",
  "radish": "three small red radishes with green tops",
  "pumpkin": "a single small orange pumpkin",
  "cauliflower": "a single fresh head of white cauliflower",
  "green-beans": "a small bunch of fresh green string beans",
  "kale": "a small bunch of dark green curly kale leaves",
  "arugula": "a small handful of fresh dark green arugula leaves",
  "basil": "a small bunch of fresh bright green basil leaves",
  "parsley": "a small bunch of fresh flat-leaf parsley",
  "cilantro": "a small bunch of fresh cilantro leaves",
  "dill": "a small bunch of fresh feathery dill fronds",
  "thyme": "a small bunch of fresh thyme sprigs",
  "rosemary": "a small bunch of fresh rosemary sprigs",
  "mint": "a small bunch of fresh bright green mint leaves",
  "chicken": "a single raw boneless skinless chicken breast, pinkish-white",
  "salmon": "a single raw pink salmon fillet",
  "beef": "a single fresh raw beef steak, deep red, well-marbled",
  "tuna": "a small piece of fresh raw red tuna",
  "shrimp": "three peeled raw pink shrimp",
  "tofu": "a single block of firm white tofu",
  "bacon": "three strips of raw streaky bacon",
  "ham": "three folded slices of pink cured ham",
  "sausage": "two whole raw fresh pork sausages",
  "pork": "a single raw pink pork chop",
  "lamb": "a single raw red lamb chop",
  "turkey": "a single raw boneless turkey breast",
  "duck": "a single raw boneless duck breast with skin",
  "crab": "a single whole cooked red crab",
  "lobster": "a single whole cooked red lobster",
  "rice": "a small white bowl of fluffy plain cooked white rice",
  "pasta": "a small handful of dry uncooked spaghetti pasta noodles",
  "oil": "a small clear glass bottle of olive oil",
  "bread": "a small artisan loaf of crusty bread",
  "pesto": "a small clear glass jar of green basil pesto, no label",
  "parmesan": "a small wedge of parmesan cheese",
  "oats": "a small white bowl of dry rolled oats",
  "quinoa": "a small white bowl of dry uncooked quinoa",
  "flour": "a small white bowl of fine white flour",
  "sugar": "a small white bowl of white sugar",
  "honey": "a small clear glass jar of golden honey, no label",
  "jam": "a small clear glass jar of red strawberry jam, no label",
  "chickpeas": "a small white bowl of dry uncooked chickpeas",
  "black-beans": "a small white bowl of dry uncooked black beans",
  "lentils": "a small white bowl of dry uncooked red lentils",
  "almonds": "a small handful of raw whole almonds",
  "peanut-butter": "a small clear glass jar of creamy peanut butter, no label",
  "soy-sauce": "a small clear glass bottle of dark soy sauce, no label",
  "ketchup": "a small clear glass bottle of red ketchup, no label",
  "mustard": "a small clear glass jar of yellow mustard, no label",
  "mayo": "a small clear glass jar of white mayonnaise, no label",
  "hummus": "a small white bowl of beige hummus",
  "olives": "a small white bowl of black olives",
  "pickles": "three small whole green pickles",
  "apple": "a single whole red apple with a green leaf",
  "banana": "a single whole yellow ripe banana",
  "orange": "a single whole orange citrus fruit",
  "strawberry": "three fresh red strawberries with green tops",
  "blueberry": "a small handful of fresh blueberries",
  "raspberry": "a small handful of fresh red raspberries",
  "mango": "a single whole ripe yellow mango",
  "pineapple": "a single whole pineapple with green leaves on top",
  "grape": "a small bunch of fresh green grapes",
  "watermelon": "a single triangular slice of red watermelon with green rind",
  "peach": "a single whole ripe yellow-pink peach",
  "pear": "a single whole green pear",
  "kiwi": "a single whole brown kiwi fruit",
  "pomegranate": "a single whole red pomegranate fruit",
  "wine": "a single bottle of red wine, no label, dark glass",
  "water": "a single clear glass bottle of water, no label",
  "juice": "a single clear glass bottle of orange juice, no label",
  "coffee": "a single small white ceramic cup of black coffee",
  "tea": "a single small white ceramic cup of brown tea",
};

function hintFor(key: string): string {
  return INGREDIENT_HINTS[key] ?? `a single fresh whole ${key.replace(/-/g, " ")}`;
}

function promptFor(key: string): string {
  const styleSuffix =
    ", centered on a pure white seamless studio background, photographed top-down with a 90 degree overhead camera angle, bright even soft-box lighting from directly above, subtle soft drop shadow directly under the subject, sharp focus, photorealistic, in the visual style of premium grocery delivery service catalog photography. The subject fills 55-65% of the frame, perfectly centered. Strictly nothing else in frame — no plates, no utensils, no garnishes, no hands, no text, no captions, no labels, no watermarks, no URLs, no logos, no signatures, no overlays, no annotations of any kind. Pure white background only.";
  return `Premium food product photography. ${hintFor(key)}, isolated subject${styleSuffix}`;
}

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-warmup-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function j(body: unknown, init: ResponseInit = {}): Response {
  return new Response(JSON.stringify(body), {
    ...init,
    headers: { ...CORS, "Content-Type": "application/json", ...(init.headers || {}) },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.headers.get("X-Warmup-Secret") !== WARMUP_SECRET) {
    return j({ error: "unauthorized" }, { status: 401 });
  }

  try {
    const gemKey = Deno.env.get("GEMINI_API_KEY");
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!gemKey) return j({ error: "no_gemini_key" }, { status: 500 });
    if (!supabaseUrl || !serviceKey) return j({ error: "no_supabase_admin" }, { status: 500 });

    const body = await req.json().catch(() => ({}));
    const keys: string[] = Array.isArray(body?.keys) ? body.keys : DEFAULT_KEYS;
    const force = Boolean(body?.force);
    const limit = typeof body?.limit === "number" ? Math.min(20, Math.max(1, body.limit)) : 5;

    const admin = createClient(supabaseUrl, serviceKey);

    // Pre-fetch all cached keys so we can skip them without N round-trips.
    const { data: cached } = await admin
      .from("image_cache")
      .select("cache_key")
      .eq("kind", "food");
    const cachedSet = new Set((cached ?? []).map((r) => r.cache_key));

    // Filter keys to only the missing ones, then process up to `limit`.
    const candidates: string[] = [];
    for (const rawKey of keys) {
      const key = String(rawKey).toLowerCase().replace(/[^a-z0-9-]/g, "-");
      if (!key) continue;
      const cacheKey = `food:${key}`;
      if (!force && cachedSet.has(cacheKey)) continue;
      candidates.push(key);
    }

    let generated = 0;
    const errors: Array<{ key: string; reason: string }> = [];
    let processed = 0;

    for (const key of candidates) {
      if (processed >= limit) break;
      const cacheKey = `food:${key}`;
      const prompt = promptFor(key);

      // Retry on 429 with exponential backoff up to ~6s.
      let success = false;
      let lastErr = "";
      for (const wait of [0, 2000, 4000]) {
        if (wait > 0) await new Promise((r) => setTimeout(r, wait));
        const url = `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:predict?key=${gemKey}`;
        const genRes = await fetch(url, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            instances: [{ prompt }],
            parameters: { sampleCount: 1, aspectRatio: "1:1", personGeneration: "dont_allow", safetyFilterLevel: "block_only_high" },
          }),
        });
        if (genRes.ok) {
          const data = await genRes.json();
          const b64: string | undefined = data?.predictions?.[0]?.bytesBase64Encoded;
          if (!b64) { lastErr = "no_image"; break; }
          const bytes = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
          const path = `food/${key}-${Date.now()}.png`;
          const { error: upErr } = await admin.storage.from(BUCKET).upload(path, bytes, { contentType: "image/png", upsert: true });
          if (upErr) { lastErr = upErr.message; break; }
          const { data: pub } = admin.storage.from(BUCKET).getPublicUrl(path);
          await admin.from("image_cache").upsert({
            cache_key: cacheKey, kind: "food", url: pub.publicUrl, prompt,
          }, { onConflict: "cache_key" });
          success = true;
          generated++;
          break;
        }
        lastErr = `imagen_${genRes.status}`;
        if (genRes.status !== 429) break;
      }
      if (!success) errors.push({ key, reason: lastErr });
      processed++;
      // small inter-request delay to be polite to Imagen quota
      await new Promise((r) => setTimeout(r, 800));
    }

    return j({
      processed,
      generated,
      errors,
      remaining: Math.max(0, candidates.length - processed),
      total_keys: keys.length,
      already_cached: cachedSet.size,
    });
  } catch (e) {
    return j({ error: String(e) }, { status: 500 });
  }
});
