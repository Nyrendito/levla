// supabase/functions/suggest-recipes — GPT-4.1-mini recipe generator
//
// Takes the user's current fridge inventory and returns 6 cookable recipes,
// ranked by "what to make tonight". Cached client-side by a hash of the
// food keys so we don't hammer OpenAI on every render.
//
// Body: { fridge: [{ foodKey, name, qty, daysLeft, status }, ...] }
// Returns: { recipes: [Recipe, ...] }

import { corsHeaders, json } from "../_shared/cors.ts";

const SYSTEM_PROMPT = `You are Levla's recipe brain. The user gives you their
current fridge inventory and you respond with exactly 6 recipes they could
cook right now, prioritizing items that are expiring soonest.

You MUST return ONLY valid JSON in this exact shape:
{
  "recipes": [
    {
      "slug": "lemon-butter-salmon",
      "title": "Lemon butter salmon",
      "subtitle": "with crisp spinach",
      "timeMinutes": 22,
      "kcal": 510,
      "protein": 36,
      "carbs": 14,
      "difficulty": "Easy",
      "uses": ["salmon", "spinach", "lemon", "butter", "garlic"],
      "why": "Your spinach should be used today.",
      "colorHex": "EFD8C0",
      "accentHex": "C97B4B",
      "tags": ["high-protein", "use soon", "< 25 min"],
      "ingredients": [
        { "foodKey": "salmon",  "name": "Salmon fillet",  "amount": "2 × 150 g" },
        { "foodKey": "spinach", "name": "Baby spinach",   "amount": "200 g" }
      ],
      "steps": [
        "Pat the salmon dry, season both sides with flaky salt.",
        "Melt butter in a wide pan over medium-high heat."
      ]
    }
  ]
}

Rules:
- Return EXACTLY 6 recipes.
- foodKey values in "uses" and "ingredients" MUST be one of: milk, yogurt,
  butter, feta, egg, spinach, broccoli, tomato, carrot, pepper, lemon, garlic,
  onion, avocado, chicken, salmon, beef, rice, pasta, oil, bread, pesto,
  parmesan, wine, water. Pick the closest match for everything you need.
- Each recipe MUST have 4-8 ingredients and 3-6 steps.
- Sort recipes by cook-tonight value: the FIRST recipe should be the most
  obviously-make-now choice (uses something expiring today). The last
  recipe can be more aspirational.
- "why" is 1 short sentence explaining why this recipe is a good pick
  given the fridge state ("Your spinach should be used today.",
  "Pantry-only weeknight.", "Clears 4 fridge items.")
- colorHex / accentHex MUST be picked from this palette (warm earth tones,
  no neons): EFD8C0/C97B4B, E1E9D2/6B8A5C, DCE6CC/5C7E40, F2E5D2/B8884A,
  F3D6C6/C9543C, F4ECC0/D6A45A, DEE5C9/637840, F1ECDE/D6A45A, E0E5C7/7E904A.
- Tags are short (1-3 words each), max 3 per recipe.
- Steps are imperative, friendly, complete sentences.
- difficulty: "Easy", "Medium", or "Hard".
- If the fridge has fewer than 3 ingredients, lean on pantry staples
  (oil, pasta, rice, bread) but stay within the foodKey list above.
- If the fridge is COMPLETELY empty, still return 6 simple recipes the
  user could make with basic ingredients (oil, pasta, rice, egg, etc).`;

interface IncomingItem {
  foodKey?: string;
  name?: string;
  qty?: string;
  daysLeft?: number;
  status?: string;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const apiKey = Deno.env.get("OPENAI_API_KEY");
    if (!apiKey) return json({ error: "OPENAI_API_KEY not set" }, { status: 500 });

    const body = await req.json();
    const fridge: IncomingItem[] = Array.isArray(body?.fridge) ? body.fridge : [];

    // Build a compact, model-friendly summary of the fridge.
    const summary = fridge.length === 0
      ? "The user's fridge is empty."
      : "The user's fridge contains:\n" + fridge.map((i) => {
          const status = i.status ? ` (${i.status})` : "";
          const days = typeof i.daysLeft === "number" ? `, ${i.daysLeft} days left` : "";
          return `- ${i.name || i.foodKey}${i.qty ? ` (${i.qty})` : ""}${status}${days}`;
        }).join("\n");

    const openaiRes = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: "gpt-4.1-mini",
        temperature: 0.7,
        response_format: { type: "json_object" },
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          { role: "user", content: summary + "\n\nReturn 6 recipes." },
        ],
      }),
    });

    if (!openaiRes.ok) {
      const detail = await openaiRes.text();
      return json({ error: "openai_failed", detail }, { status: 502 });
    }

    const completion = await openaiRes.json();
    const raw = completion?.choices?.[0]?.message?.content ?? "{}";

    let parsed: { recipes?: unknown[] } = {};
    try {
      parsed = JSON.parse(raw);
    } catch {
      return json({ error: "openai_returned_invalid_json", raw }, { status: 502 });
    }

    return json({ recipes: Array.isArray(parsed.recipes) ? parsed.recipes : [] });
  } catch (e) {
    return json({ error: String(e) }, { status: 500 });
  }
});
