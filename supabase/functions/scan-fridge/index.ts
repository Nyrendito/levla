// supabase/functions/scan-fridge v10 — video-first fridge vision via
// Gemini 2.5 Flash's native video API.
//
// The user records a short (4-8 s) fridge sweep on iOS. We receive the
// clip as inline base64 data and send ONE multimodal request to Gemini
// with a strict JSON responseSchema. Gemini samples the clip at ~1 fps
// internally and preserves motion continuity across the frames — much
// better signal than the old GPT-4o multi-image grid for a fraction of
// the token cost.
//
// Body (preferred): { video: "data:video/mp4;base64,..." }
// Body (fallback):  { images: ["data:image/jpeg;base64,...", ...] }
// Returns: { items: [{ name, foodKey, qty, category, daysLeft, confidence }] }

import { corsHeaders, json } from "./_shared/cors.ts";
import { FOOD_KEYS, CATEGORIES, itemsSchema, strictSchema } from "./_shared/schemas.ts";

const GEMINI_MODEL = "gemini-2.5-flash";

const FRIDGE_INSTRUCTIONS = `You are Levla's fridge vision model. The user has just recorded a short clip while sweeping their fridge (or you'll receive multiple still photos of the shelves). Your job is to identify EVERY distinct food item visible across the clip / images.

For each item return:
- foodKey: the closest match from this fixed list: ${FOOD_KEYS.join(", ")}. Map specifically (a russet potato → potato, not milk; ginger root → ginger, not garlic).
- category: exactly one of ${CATEGORIES.join(", ")}.
- qty: short estimate ("1 L", "200 g", "3", "1/2 bag", "1 head").
- daysLeft: realistic default — dairy 7, fresh veg 6, meat 2, pantry/dry 90, drinks 30.
- confidence: 0.0-1.0 based on how clearly you can see the item.
- name: short human-readable name.

Combine the SAME item seen from different angles into one row (a yoghurt seen on two shelves is one item). Skip empty shelves, drawer dividers, and non-food (jars of pickles, sauces, drinks count as food; a paper towel does not).

If you see nothing food-related, return {"items": []}.`;

// Gemini's structured-output schema syntax is OpenAPI 3 with uppercase
// type strings. We mirror our existing FOOD_KEYS + CATEGORIES enums so
// the iOS-side ScanCandidate decoder needs no changes.
const GEMINI_SCHEMA = {
  type: "OBJECT",
  properties: {
    items: {
      type: "ARRAY",
      items: {
        type: "OBJECT",
        properties: {
          name:       { type: "STRING" },
          foodKey:    { type: "STRING", enum: [...FOOD_KEYS] },
          qty:        { type: "STRING" },
          category:   { type: "STRING", enum: [...CATEGORIES] },
          daysLeft:   { type: "INTEGER" },
          confidence: { type: "NUMBER" },
        },
        required: ["name", "foodKey", "qty", "category", "daysLeft", "confidence"],
        propertyOrdering: ["name", "foodKey", "qty", "category", "daysLeft", "confidence"],
      },
    },
  },
  required: ["items"],
};

/// Strip a data URI prefix and return the raw base64 plus the MIME type.
function splitDataUri(uri: string, defaultMime: string): { mime: string; base64: string } {
  const m = /^data:([^;]+);base64,(.+)$/.exec(uri);
  if (m) return { mime: m[1], base64: m[2] };
  return { mime: defaultMime, base64: uri };
}

/// Gemini path — ONE call with the video clip + strict JSON schema.
async function scanViaGemini(videoUri: string, gemKey: string): Promise<Response> {
  const { mime, base64 } = splitDataUri(videoUri, "video/mp4");
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${gemKey}`;

  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      contents: [{
        parts: [
          { inline_data: { mime_type: mime, data: base64 } },
          { text: FRIDGE_INSTRUCTIONS },
        ],
      }],
      generationConfig: {
        // Force strict JSON — Gemini validates against the schema before
        // returning, so we don't need permissive parsing on the client.
        responseMimeType: "application/json",
        responseSchema: GEMINI_SCHEMA,
        temperature: 0.2,
        // Low resolution roughly thirds token cost on video with
        // negligible quality loss on grocery item identification.
        mediaResolution: "MEDIA_RESOLUTION_LOW",
      },
    }),
  });

  if (!res.ok) {
    const detail = await res.text();
    return json({ error: "gemini_failed", detail: detail.slice(0, 400) }, { status: 502 });
  }

  const data = await res.json();
  // Gemini returns the JSON text in candidates[0].content.parts[0].text.
  const text = data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "{}";
  let parsed: { items?: unknown } = {};
  try { parsed = JSON.parse(text); }
  catch { return json({ error: "gemini_invalid_json", raw: text.slice(0, 400) }, { status: 502 }); }

  return json({ items: Array.isArray(parsed.items) ? parsed.items : [] });
}

/// Fallback OpenAI path — unchanged from the old function. Used when the
/// client falls back to sending images (offline / simulator) instead of a
/// real video clip.
async function scanViaOpenAI(images: string[], apiKey: string): Promise<Response> {
  const content: Array<Record<string, unknown>> = [
    { type: "text", text: FRIDGE_INSTRUCTIONS },
  ];
  for (const raw of images) {
    if (typeof raw !== "string" || raw.length === 0) continue;
    const u = raw.startsWith("data:") ? raw : `data:image/jpeg;base64,${raw}`;
    content.push({ type: "image_url", image_url: { url: u, detail: "high" } });
  }

  const res = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${apiKey}` },
    body: JSON.stringify({
      model: "gpt-4o-mini",
      temperature: 0.2,
      response_format: strictSchema("fridge_scan", itemsSchema),
      messages: [{ role: "user", content }],
    }),
  });

  if (!res.ok) {
    const text = await res.text();
    return json({ error: "openai_failed", detail: text.slice(0, 400) }, { status: 502 });
  }
  const completion = await res.json();
  const raw = completion?.choices?.[0]?.message?.content ?? "{}";
  let parsed: { items?: unknown } = {};
  try { parsed = JSON.parse(raw); }
  catch { return json({ error: "openai_invalid_json", raw }, { status: 502 }); }
  return json({ items: Array.isArray(parsed.items) ? parsed.items : [] });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const body = await req.json();

    // Video-first: preferred path when iOS records a real clip.
    if (typeof body?.video === "string" && body.video.length > 0) {
      const gemKey = Deno.env.get("GEMINI_API_KEY");
      if (!gemKey) return json({ error: "GEMINI_API_KEY not set" }, { status: 500 });
      return await scanViaGemini(body.video, gemKey);
    }

    // Multi-image fallback (simulator / older clients).
    if (Array.isArray(body?.images) && body.images.length > 0) {
      const apiKey = Deno.env.get("OPENAI_API_KEY");
      if (!apiKey) return json({ error: "OPENAI_API_KEY not set" }, { status: 500 });
      return await scanViaOpenAI(body.images as string[], apiKey);
    }

    return json({ error: "video or images required" }, { status: 400 });
  } catch (e) {
    return json({ error: String(e) }, { status: 500 });
  }
});
