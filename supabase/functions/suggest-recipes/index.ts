// supabase/functions/suggest-recipes — Returns 12 personalized recipes per
// fridge + profile snapshot. Heavily biases toward 100% match against the
// user's actual inventory. Pantry staples (salt/pepper/oil/butter/etc) are
// assumed always-present and never flagged as missing.
//
// Body: { fridge: [{foodKey,name,qty,daysLeft,status}], profile?: {sex,age,heightCm,weightKg,goal,activityLevel,dailyKcalGoal,dailyProteinGoal,dietaryPrefs}}
// Returns: { recipes: Recipe[] }   (always exactly 12 if the model behaves)

import { corsHeaders, json } from "./_shared/cors.ts";
import { recipesSchema, strictSchema, FOOD_KEYS, DIFFICULTIES, MEAL_TYPES, COLOR_HEXES } from "./_shared/schemas.ts";

const PANTRY_STAPLES =
  "salt, pepper, olive oil, butter, water, sugar, common dried spices, vinegar, neutral cooking oil, basic herbs";

function profileSummary(profile: any): string {
  if (!profile || typeof profile !== "object") return "";
  const parts: string[] = [];
  if (profile.sex) parts.push(String(profile.sex));
  if (typeof profile.age === "number") parts.push(`${profile.age} yrs`);
  if (typeof profile.heightCm === "number") parts.push(`${profile.heightCm} cm`);
  if (typeof profile.weightKg === "number") parts.push(`${profile.weightKg} kg`);
  if (profile.activityLevel) parts.push(`activity: ${profile.activityLevel}`);
  if (typeof profile.dailyKcalGoal === "number") parts.push(`~${profile.dailyKcalGoal} kcal/day target`);
  if (typeof profile.dailyProteinGoal === "number") parts.push(`${profile.dailyProteinGoal}g protein/day`);
  if (Array.isArray(profile.dietaryPrefs) && profile.dietaryPrefs.length > 0) {
    parts.push(`dietary: ${profile.dietaryPrefs.join(", ")}`);
  }
  return parts.length ? `\nUser snapshot: ${parts.join(" · ")}.` : "";
}

function goalGuidance(goal: any): string {
  if (!goal) return "";
  return `\nThe user's goal is "${goal}". Tilt every recipe toward this goal:\n- lose_fat: high protein (35-50g per meal), moderate carbs, fibre-heavy, kcal 350-550 per meal.\n- gain_muscle: high protein (40-55g), generous complex carbs, kcal 550-800 per meal.\n- maintain: balanced macros, kcal 450-650 per meal.\n- general_health: balanced + nutrient-dense.`;
}

function systemPrompt(profile: any) {
  return `You are Levla's recipe brain. The user gives you their current fridge inventory and you respond with 12 recipes covering a whole day.${profileSummary(profile)}${goalGuidance(profile?.goal)}

The output schema is enforced.
- Return EXACTLY 12 recipes. Each must have a UNIQUE slug.
- 4 breakfast + 4 lunch + 4 dinner. Label each with mealType.
- mealType must be one of: ${MEAL_TYPES.join(", ")}.
- foodKey values in "uses" and "ingredients" MUST be from: ${FOOD_KEYS.join(", ")}.
- IMPORTANT pantry assumption: the user ALREADY has these staples in the kitchen at all times, you NEVER need to flag them as missing or include them as 'to buy': ${PANTRY_STAPLES}. Map them all to foodKey "oil" if you need a foodKey slot.
- difficulty: ${DIFFICULTIES.join(" / ")}.
- colorHex / accentHex MUST be from: ${COLOR_HEXES.join(", ")}.
- 4-8 ingredients per recipe. Ingredient amounts MUST be specific and measurable ("2 tbsp olive oil", "150 g chicken breast", "1 medium yellow onion, diced", "½ tsp salt") — never vague ("a bit", "some", "to taste" only).
- 5-9 steps per recipe. Steps must be DETAILED enough that someone who has never made this dish can follow it confidently. Each step must include:
  · specific TIMES whenever heat or rest is involved ("simmer 8-10 minutes", "let rest 5 minutes")
  · TEMPERATURES for ovens / pans ("preheat oven to 200°C / 400°F", "medium-high heat", "low simmer")
  · VISUAL OR SENSORY DONENESS CUES ("until golden brown on both sides", "until fragrant, about 30 seconds", "until the eggs are set but still glossy", "until the pasta is al dente")
  · TECHNIQUE verbs ("dice the onion fine", "mince the garlic", "whisk together", "fold gently", "deglaze with a splash of water")
  · EQUIPMENT when it matters ("in a large skillet", "on a parchment-lined baking sheet")
- Step ONE should usually be prep ("Heat oven to X / Bring a large pot of salted water to a boil / Pat the chicken dry"). The last step should plate and finish ("Slice against the grain and serve with a squeeze of lemon").
- Never collapse two actions into one ambiguous instruction. "Cook chicken with onions and serve" is BAD. "Heat 1 tbsp oil in a large skillet over medium-high heat. Sear the chicken 4 minutes per side, until it reaches 74°C / 165°F internal. Rest 5 minutes before slicing." is GOOD.
- HEAVILY favour recipes that use ONLY ingredients the user already has in their fridge. At least 6 of the 12 should be 100% match (use only items present + pantry staples). The rest can require 1-2 missing items max.
- Within each meal type, sort by cook-tonight value (best match first).
- "why" is 1 short sentence; if 100% match say "Made entirely from your fridge."; if the user has a goal, tie the reason to it.
- subtitle is a single short phrase (max 6 words) describing the vibe ("Crispy, golden, ready in 15", "Sheet-pan dinner, minimal cleanup").
- tags: 1-3 short tags.
- Macros must be realistic per serving and aligned with the goal.
- Breakfasts lighter and quicker (timeMinutes 5-20). Lunches medium (10-30). Dinners can be longer (15-45).
- Respect dietaryPrefs (vegan, vegetarian, pescatarian, gluten_free, dairy_free, halal, kosher, low_carb, etc.) if provided — never include a forbidden ingredient.

If fridge has fewer than 3 items, lean entirely on pantry staples.`;
}

interface IncomingItem {
  foodKey?: string;
  name?: string;
  qty?: string;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const apiKey = Deno.env.get("OPENAI_API_KEY");
    if (!apiKey) return json({ error: "OPENAI_API_KEY not set" }, { status: 500 });

    const body = await req.json();
    const fridge: IncomingItem[] = Array.isArray(body?.fridge) ? body.fridge : [];
    const profile = body?.profile ?? null;

    const summary = fridge.length === 0
      ? "The user's fridge is empty."
      : "The user's fridge contains:\n" + fridge.map((i) => `- ${i.name || i.foodKey}${i.qty ? ` (${i.qty})` : ""}`).join("\n");

    const openaiRes = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${apiKey}` },
      body: JSON.stringify({
        model: "gpt-4.1-mini",
        temperature: 0.7,
        response_format: strictSchema("recipe_set", recipesSchema),
        messages: [
          { role: "system", content: systemPrompt(profile) },
          { role: "user", content: summary + "\n\nReturn 12 recipes: 4 breakfast, 4 lunch, 4 dinner." },
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
    try { parsed = JSON.parse(raw); } catch {
      return json({ error: "openai_returned_invalid_json", raw }, { status: 502 });
    }
    return json({ recipes: Array.isArray(parsed.recipes) ? parsed.recipes : [] });
  } catch (e) {
    return json({ error: String(e) }, { status: 500 });
  }
});
