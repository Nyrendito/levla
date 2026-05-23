// supabase/functions/scan-fridge — vision pipeline with strict JSON Schema
//
// Body: { images: ["data:image/jpeg;base64,...", ...] }
// Returns: { items: [{ name, foodKey, qty, category, daysLeft, confidence }, ...] }

import { corsHeaders, json } from "./_shared/cors.ts";
import { itemsSchema, strictSchema, FOOD_KEYS, CATEGORIES } from "./_shared/schemas.ts";

const SYSTEM_PROMPT = `You are Levla's fridge vision model. You look at one or more
photos of a refrigerator (often shelf by shelf) and identify every distinct food item.

The output schema is enforced — return one item per distinct food, with:
- foodKey: closest match from this list: ${FOOD_KEYS.join(", ")}
- category: one of ${CATEGORIES.join(", ")}
- qty: short estimate ("1 L", "200 g", "3", "½ bag", "1 head")
- daysLeft: realistic default — dairy 7, fresh veg 6, meat 2, pantry/dry 90, drinks 30
- confidence: 0.0-1.0
- name: human-readable name

Combine duplicates across photos (same yoghurt seen on two shelves → one item).
Skip non-food items, empty shelves, drawer dividers.
If you see nothing food-related, return {"items": []}.`;

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const apiKey = Deno.env.get("OPENAI_API_KEY");
    if (!apiKey) return json({ error: "OPENAI_API_KEY not set" }, { status: 500 });

    const body = await req.json();
    const images: unknown = body?.images;
    if (!Array.isArray(images) || images.length === 0) {
      return json({ error: "images: non-empty array required" }, { status: 400 });
    }

    const content: Array<Record<string, unknown>> = [
      { type: "text", text: "Identify every distinct food item across these photos." },
    ];
    for (const raw of images) {
      if (typeof raw !== "string" || raw.length === 0) continue;
      const url = raw.startsWith("data:") ? raw : `data:image/jpeg;base64,${raw}`;
      content.push({ type: "image_url", image_url: { url, detail: "high" } });
    }

    const openaiRes = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        temperature: 0.2,
        response_format: strictSchema("fridge_scan", itemsSchema),
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          { role: "user", content },
        ],
      }),
    });

    if (!openaiRes.ok) {
      const text = await openaiRes.text();
      return json({ error: "openai_failed", detail: text }, { status: 502 });
    }

    const completion = await openaiRes.json();
    const raw = completion?.choices?.[0]?.message?.content ?? "{}";

    let parsed: { items?: unknown } = {};
    try {
      parsed = JSON.parse(raw);
    } catch {
      return json({ error: "openai_returned_invalid_json", raw }, { status: 502 });
    }

    return json({ items: Array.isArray(parsed.items) ? parsed.items : [] });
  } catch (e) {
    return json({ error: String(e) }, { status: 500 });
  }
});
