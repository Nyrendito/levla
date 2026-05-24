// supabase/functions/gen-food-image — generates a food / recipe image via
// Google Imagen 4 (Gemini API), uploads to the public 'food-images'
// bucket, returns a stable public URL. Cached by (kind, key) so we never
// re-generate.
//
// Body: { kind: "food" | "recipe", key: "salmon" | "lemon-butter-salmon", title?: string, uses?: string[] }
// Returns: { url: "https://..." } | { url: null, reason: "..." }
//
// Requires GEMINI_API_KEY (Supabase secret) with access to the Imagen 4
// family. Tested with imagen-4.0-generate-001 on a standard key —
// produces 1024×1024 photographs in the 400–800 KB range.

import { corsHeaders, json } from "./_shared/cors.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.0";

const BUCKET = "food-images";
const MODEL = "imagen-4.0-generate-001";

function promptFor(kind: string, key: string, title?: string, uses?: string[]): string {
  // Strong, consistent style locked in across every request. The strict
  // no-text clauses are necessary — Imagen will occasionally leak training
  // data captions / fake labels onto product shots otherwise.
  const styleSuffix =
    ", clean pure white seamless background, soft natural daylight from above, subtle soft shadow on the surface, top-down centered composition, minimalist food photography, photorealistic. Strictly no text, no captions, no watermarks, no URLs, no labels, no logos, no signatures, no overlays, no annotations of any kind. Subject only.";
  if (kind === "recipe" && title) {
    const ingredientHint = uses && uses.length > 0 ? ` featuring ${uses.slice(0, 3).join(", ")}` : "";
    return `Studio still life of a single beautifully plated portion of ${title.toLowerCase()}${ingredientHint}, served on a simple white ceramic plate, isolated subject${styleSuffix}`;
  }
  const display = key.replace(/-/g, " ");
  return `Studio still life of a single fresh whole ${display} ingredient, isolated subject${styleSuffix}`;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const gemKey = Deno.env.get("GEMINI_API_KEY");
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!gemKey) return json({ url: null, reason: "no_gemini_key" }, { status: 500 });
    if (!supabaseUrl || !serviceKey) return json({ url: null, reason: "no_supabase_admin" }, { status: 500 });

    const body = await req.json();
    const kind = String(body?.kind ?? "");
    const key  = String(body?.key  ?? "").toLowerCase().replace(/[^a-z0-9-]/g, "-");
    if ((kind !== "food" && kind !== "recipe") || !key) {
      return json({ url: null, reason: "bad_input" }, { status: 400 });
    }

    const cacheKey = `${kind}:${key}`;
    const admin = createClient(supabaseUrl, serviceKey);

    // 1. Cache hit?
    const { data: hit } = await admin
      .from("image_cache")
      .select("url")
      .eq("cache_key", cacheKey)
      .maybeSingle();
    if (hit?.url) return json({ url: hit.url, cached: true });

    // 2. Generate via Imagen 4. Retry once on 429.
    const prompt = promptFor(kind, key, body?.title, body?.uses);
    const imagenURL = `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:predict?key=${gemKey}`;
    async function attempt() {
      return await fetch(imagenURL, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          instances: [{ prompt }],
          parameters: { sampleCount: 1, aspectRatio: "1:1", personGeneration: "dont_allow", safetyFilterLevel: "block_only_high" },
        }),
      });
    }
    let genRes = await attempt();
    if (genRes.status === 429) {
      await new Promise((r) => setTimeout(r, 2200));
      genRes = await attempt();
    }
    if (!genRes.ok) {
      const text = await genRes.text();
      let parsed: any = null;
      try { parsed = JSON.parse(text); } catch {}
      return json({
        url: null,
        reason: "imagen_failed",
        status: genRes.status,
        detail: (parsed?.error?.message ?? text).slice(0, 240),
      }, { status: 502 });
    }

    const data = await genRes.json();
    const b64: string | undefined = data?.predictions?.[0]?.bytesBase64Encoded;
    if (!b64) return json({ url: null, reason: "no_image_in_response" }, { status: 502 });

    const bytes = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));

    // 3. Upload + 4. cache.
    const path = `${kind}/${key}-${Date.now()}.png`;
    const { error: upErr } = await admin.storage.from(BUCKET).upload(path, bytes, { contentType: "image/png", upsert: true });
    if (upErr) return json({ url: null, reason: "upload_failed", detail: upErr.message }, { status: 502 });

    const { data: pub } = admin.storage.from(BUCKET).getPublicUrl(path);
    const publicUrl = pub.publicUrl;

    await admin.from("image_cache").upsert({
      cache_key: cacheKey,
      kind,
      url: publicUrl,
      prompt,
    }, { onConflict: "cache_key" });

    return json({ url: publicUrl, cached: false });
  } catch (e) {
    return json({ url: null, reason: String(e) }, { status: 500 });
  }
});
