// supabase/functions/scan-receipt — GPT-4.1-mini receipt parser
//
// The iOS app runs Apple Vision OCR locally and ships the raw text up here.
// We turn it into a structured list of food items.
//
// Body: { text: "DANONE SKYR 0%  2.49\nCHICKEN BREAST 6.80\n..." }
// Returns: { items: [{ name, foodKey, qty, category, daysLeft, confidence }, ...] }

import { corsHeaders, json } from "../_shared/cors.ts";

const SYSTEM_PROMPT = `You are Levla's receipt parser. You receive the raw OCR text
from a grocery receipt and must produce a clean list of food items the user bought.

You MUST return ONLY valid JSON in this exact shape:
{
  "items": [
    {
      "name": "Danone Skyr 0%",
      "foodKey": "yogurt",
      "qty": "1",
      "category": "Dairy",
      "daysLeft": 14,
      "confidence": 0.92
    }
  ]
}

Rules:
- foodKey MUST be one of: milk, yogurt, butter, feta, egg, spinach, broccoli, tomato,
  carrot, pepper, lemon, garlic, onion, avocado, chicken, salmon, beef, rice, pasta,
  oil, bread, pesto, parmesan, wine, water. Pick the closest match.
- category MUST be one of: Dairy, Vegetables, Meat, Pantry, Drinks, Freezer.
- Skip non-food items (bags, plastic, deposit, tax, total, store branding, dates, payment).
- Normalize messy uppercase OCR ("CHICKEN BREAST" → "Chicken breast").
- qty: extract from the line if present ("2X", "1 KG"); otherwise "1".
- daysLeft realistic default — dairy 7, meat 2, vegetables 6, pantry/dry 90, drinks 30.
- confidence: 0.0–1.0; lower if the OCR line is ambiguous or messy.
- Combine obvious duplicates from typos.
- If there are no food items, return {"items": []}.`;

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
    const text: unknown = body?.text;
    if (typeof text !== "string" || text.trim().length === 0) {
      return json({ error: "text: non-empty string required" }, { status: 400 });
    }

    const openaiRes = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: "gpt-4.1-mini",
        temperature: 0.1,
        response_format: { type: "json_object" },
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          { role: "user", content: text.slice(0, 8000) }, // hard cap, receipts are short
        ],
      }),
    });

    if (!openaiRes.ok) {
      const detail = await openaiRes.text();
      return json({ error: "openai_failed", detail }, { status: 502 });
    }

    const completion = await openaiRes.json();
    const raw = completion?.choices?.[0]?.message?.content ?? "{}";

    let parsed: { items?: Item[] } = {};
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
