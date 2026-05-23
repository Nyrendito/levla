// supabase/functions/suggest-recipes — GPT-4.1-mini recipe generator w/ strict schema
//
// Body: { fridge: [{ foodKey, name, qty, daysLeft, status }, ...] }
// Returns: { recipes: [Recipe, ...] }   (6 items, exact schema enforced)

import { corsHeaders, json } from "./_shared/cors.ts";
import {
  recipesSchema, strictSchema, FOOD_KEYS, DIFFICULTIES, COLOR_HEXES,
} from "./_shared/schemas.ts";

const SYSTEM_PROMPT = `You are Levla's recipe brain. The user gives you their
current fridge inventory and you respond with exactly 6 recipes they could
cook right now, prioritizing items that are expiring soonest.

The output schema is enforced. You MUST:
- Return EXACTLY 6 recipes (the array length is enforced by the consumer).
- foodKey values in "uses" and "ingredients" MUST be one of: ${FOOD_KEYS.join(", ")}.
- difficulty MUST be one of: ${DIFFICULTIES.join(", ")}.
- colorHex / accentHex MUST be one of: ${COLOR_HEXES.join(", ")} (warm earth tones).
- Each recipe MUST have 4-8 ingredients and 3-6 steps.
- Sort recipes by cook-tonight value (most obviously-make-now first).
- "why" is 1 short sentence explaining why this is a good pick.
- "tags" are 1-3 short tags per recipe.
- Steps are imperative, friendly, complete sentences.

If the fridge has fewer than 3 ingredients, lean on pantry staples
(oil, pasta, rice, bread) but stay within the foodKey list above.
If the fridge is completely empty, still return 6 simple recipes the
user could make with basic ingredients.`;

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
        response_format: strictSchema("recipe_set", recipesSchema),
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

    let parsed: { recipes?: unknown } = {};
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
