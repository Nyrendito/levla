// supabase/functions/scan-fridge — GPT-4o vision pipeline
//
// Accepts one or more shelf photos (as data: URIs or base64 strings) and
// returns a structured list of food items.
//
// Body: { images: ["data:image/jpeg;base64,...", ...] }
// Returns: { items: [{ name, foodKey, qty, category, daysLeft, confidence }, ...] }
//
// Set the secret with:
//   supabase secrets set OPENAI_API_KEY=sk-...

import { corsHeaders, json } from "../_shared/cors.ts";

const SYSTEM_PROMPT = `You are Levla's fridge vision model. You look at one or more
photos of a refrigerator (often shelf by shelf) and identify every distinct food item.

You MUST return ONLY valid JSON in this exact shape:
{
  "items": [
    {
      "name": "Whole milk",
      "foodKey": "milk",
      "qty": "1 L",
      "category": "Dairy",
      "daysLeft": 7,
      "confidence": 0.92
    }
  ]
}

Rules:
- foodKey MUST be one of: milk, yogurt, butter, feta, egg, spinach, broccoli, tomato,
  carrot, pepper, lemon, garlic, onion, avocado, chicken, salmon, beef, rice, pasta,
  oil, bread, pesto, parmesan, wine, water. Pick the closest match.
- category MUST be one of: Dairy, Vegetables, Meat, Pantry, Drinks, Freezer.
- qty: short human-readable estimate ("1 L", "200 g", "3", "½ bag", "1 head").
- daysLeft: realistic default — dairy 7, fresh veg 6, meat 2, pantry/dry 90, drinks 30.
- confidence: how confident you are this is correctly identified (0.0–1.0).
- Combine duplicates across photos (same yoghurt seen on two shelves → one item).
- Skip non-food items, empty shelves, drawer dividers.
- If you see nothing food-related, return {"items": []}.`;

interface Item {
  name: string;
  foodKey: string;
  qty: string;
  category: string;
  daysLeft: number;
  confidence: number;
}

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

    // Build the user content: one text block + N image blocks.
    const content: Array<Record<string, unknown>> = [
      { type: "text", text: "Identify every distinct food item across these shelf photos." },
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
        // gpt-4o-mini: vision-capable, available on standard OpenAI tiers,
        // and ~6× cheaper than gpt-4o. Plenty good for shelf-by-shelf food ID.
        model: "gpt-4o-mini",
        temperature: 0.2,
        response_format: { type: "json_object" },
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

    let parsed: { items?: Item[] } = {};
    try {
      parsed = JSON.parse(raw);
    } catch {
      return json({ error: "openai_returned_invalid_json", raw }, { status: 502 });
    }

    const items = Array.isArray(parsed.items) ? parsed.items : [];
    return json({ items });
  } catch (e) {
    return json({ error: String(e) }, { status: 500 });
  }
});
