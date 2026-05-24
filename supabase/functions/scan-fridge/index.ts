// supabase/functions/scan-fridge v11 — storage-backed video upload
// pipeline + Gemini 2.5 Flash native video understanding.
//
// Why storage and not inline base64:
//   A 20 s 720p H.264 clip is ~5 MB raw, ~7 MB base64. Supabase Edge
//   Functions historically reject inline bodies near that size (502 from
//   the gateway, no function logs). Uploading to a private 'fridge-clips'
//   bucket from iOS, then having this function download via service-role
//   creds, sidesteps the limit AND keeps the iOS request tiny.
//
// Body shapes accepted (preferred first):
//   { videoPath: "<userId>/<uuid>.mp4" }   — path inside the fridge-clips bucket
//   { video:     "data:video/mp4;base64,..." } — legacy inline path, still works
//   { images:   ["data:image/jpeg;base64,...", ...] } — fallback for sim/offline
//
// Returns:
//   { items: [{ name, foodKey, qty, category, daysLeft, confidence }] }

import { corsHeaders, json } from "./_shared/cors.ts";
import { FOOD_KEYS, CATEGORIES, itemsSchema, strictSchema } from "./_shared/schemas.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.0";

const GEMINI_MODEL = "gemini-2.5-flash";
const BUCKET = "fridge-clips";

const FRIDGE_INSTRUCTIONS = `You are Levla's fridge vision model. The user has just recorded a short clip while sweeping their fridge (or you'll receive multiple still photos of the shelves). Your job is to identify EVERY distinct food item visible across the clip / images.

For each item return:
- foodKey: the closest match from this fixed list: ${FOOD_KEYS.join(", ")}. Map specifically (a russet potato → potato, not milk; ginger root → ginger, not garlic).
- category: exactly one of ${CATEGORIES.join(", ")}.
- qty: short estimate ("1 L", "200 g", "3", "1/2 bag", "1 head").
- daysLeft: realistic default — dairy 7, fresh veg 6, meat 2, pantry/dry 90, drinks 30.
- confidence: 0.0-1.0 based on how clearly you can see the item.
- name: short human-readable name.

Combine the SAME item seen from different angles into one row. Skip non-food. If you see nothing food-related, return {"items": []}.`;

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

function splitDataUri(uri: string, defaultMime: string): { mime: string; base64: string } {
  const m = /^data:([^;]+);base64,(.+)$/.exec(uri);
  if (m) return { mime: m[1], base64: m[2] };
  return { mime: defaultMime, base64: uri };
}

/// Encode raw bytes to base64.
function toBase64(bytes: Uint8Array): string {
  let s = "";
  const chunk = 0x8000;
  for (let i = 0; i < bytes.length; i += chunk) {
    s += String.fromCharCode.apply(null, bytes.subarray(i, i + chunk) as unknown as number[]);
  }
  return btoa(s);
}

async function callGemini(base64: string, mime: string, gemKey: string): Promise<Response> {
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
        responseMimeType: "application/json",
        responseSchema: GEMINI_SCHEMA,
        temperature: 0.2,
        mediaResolution: "MEDIA_RESOLUTION_LOW",
      },
    }),
  });

  if (!res.ok) {
    const detail = await res.text();
    console.error("gemini_failed", res.status, detail.slice(0, 600));
    return json({
      error: "gemini_failed",
      status: res.status,
      detail: detail.slice(0, 600),
    }, { status: 502 });
  }

  const data = await res.json();
  const text = data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "{}";
  let parsed: { items?: unknown } = {};
  try { parsed = JSON.parse(text); }
  catch {
    console.error("gemini_invalid_json", text.slice(0, 400));
    return json({ error: "gemini_invalid_json", raw: text.slice(0, 400) }, { status: 502 });
  }
  return json({ items: Array.isArray(parsed.items) ? parsed.items : [] });
}

async function scanViaStorage(videoPath: string, supabaseUrl: string, serviceKey: string, gemKey: string): Promise<Response> {
  const admin = createClient(supabaseUrl, serviceKey);
  const { data: blob, error: dlErr } = await admin.storage.from(BUCKET).download(videoPath);
  if (dlErr || !blob) {
    console.error("storage_download_failed", dlErr?.message ?? "no blob");
    return json({ error: "storage_download_failed", detail: dlErr?.message ?? "empty" }, { status: 502 });
  }
  const buf = new Uint8Array(await blob.arrayBuffer());
  console.log("scan-fridge storage download ok bytes=", buf.length);
  const mime = blob.type && blob.type.length > 0 ? blob.type : "video/mp4";
  const base64 = toBase64(buf);

  const result = await callGemini(base64, mime, gemKey);
  admin.storage.from(BUCKET).remove([videoPath]).catch((e) => {
    console.warn("cleanup_failed", videoPath, String(e));
  });
  return result;
}

async function scanViaInline(videoUri: string, gemKey: string): Promise<Response> {
  const { mime, base64 } = splitDataUri(videoUri, "video/mp4");
  console.log("scan-fridge inline mime=", mime, " base64Len=", base64.length);
  return await callGemini(base64, mime, gemKey);
}

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
    console.error("openai_failed", res.status, text.slice(0, 400));
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
    const gemKey      = Deno.env.get("GEMINI_API_KEY");
    const openaiKey   = Deno.env.get("OPENAI_API_KEY");
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceKey  = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    if (typeof body?.videoPath === "string" && body.videoPath.length > 0) {
      if (!gemKey)      return json({ error: "GEMINI_API_KEY not set" }, { status: 500 });
      if (!supabaseUrl || !serviceKey) return json({ error: "no_supabase_admin" }, { status: 500 });
      return await scanViaStorage(body.videoPath, supabaseUrl, serviceKey, gemKey);
    }

    if (typeof body?.video === "string" && body.video.length > 0) {
      if (!gemKey) return json({ error: "GEMINI_API_KEY not set" }, { status: 500 });
      return await scanViaInline(body.video, gemKey);
    }

    if (Array.isArray(body?.images) && body.images.length > 0) {
      if (!openaiKey) return json({ error: "OPENAI_API_KEY not set" }, { status: 500 });
      return await scanViaOpenAI(body.images as string[], openaiKey);
    }

    return json({ error: "videoPath, video, or images required" }, { status: 400 });
  } catch (e) {
    console.error("scan-fridge unhandled", String(e));
    return json({ error: String(e) }, { status: 500 });
  }
});
