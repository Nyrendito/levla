// supabase/functions/analyze-meal v3 — Cal-AI / BitePal flow with micros.
// Snaps a meal, returns identification + macros + micros (fiber, sugar,
// sodium) computed for the VISIBLE portion. Macros from grams and food
// density (P/C ×4, F ×9); micros from a typical-per-100g lookup the
// model is asked to apply.
//
// Body:    { image: "data:image/jpeg;base64,..." | base64 }
// Returns: { name, portion_g, kcal, protein, carbs, fat,
//            fiber, sugar, sodium,
//            ingredients: [{name, grams, kcal, protein, carbs, fat,
//                           fiber, sugar, sodium}],
//            confidence }

import { corsHeaders, json } from "./_shared/cors.ts";

const SYSTEM_PROMPT = `You are Levla's meal-analysis vision model. The user shows you a photo of a meal or single food item. Your job is to identify it AND estimate the calorie, macro, AND micronutrient content of the SPECIFIC PORTION visible in the photo — not a generic "1 serving".

Portion sizing is mandatory:
- Estimate the total weight of food in grams (portion_g) and the grams of each visible ingredient.
- Use on-screen scale cues: a dinner plate is ~26-28 cm, a fork ~20 cm, a hand ~18-20 cm, a soda can ~12 cm tall.
- Look at FOOD VOLUME, not surface area. A heaped bowl of rice fills more than a flat layer. Sauces and dressings add density.
- If the photo is angled, mentally rotate to estimate. If unclear, lower confidence and pick a sensible middle value rather than defaulting to 1 serving.
- Compute macros from grams using standard food density: protein 4 kcal/g, carbs 4 kcal/g, fat 9 kcal/g. Top-level macros = sum of ingredient macros within ±5 kcal.

Micronutrients are mandatory:
- fiber  (grams): estimate per ingredient using typical per-100g values (vegetables 2-5g/100g, beans/lentils 6-8g/100g, whole-grain bread ~7g/100g, fruit 2-4g/100g, animal protein ~0g/100g). Sum to the meal total.
- sugar  (grams): combined naturally-occurring + added (fruit ~10g/100g, sweetened sauces / drinks high, plain proteins/oils ~0). Be honest about hidden sugar in dressings/sauces.
- sodium (mg):    salt-derived. Restaurant / fried / cured foods can hit 500-1500mg per portion easily; home-cooked vegetable plates 200-500mg; bare fresh fruit ~0.
- Top-level micros must approximately equal the sum of ingredient micros.

Return ONLY JSON in this exact shape, no markdown:
{
  "name": "Grilled chicken, rice & broccoli",
  "portion_g": 420,
  "kcal": 568,
  "protein": 48,
  "carbs": 62,
  "fat": 14,
  "fiber": 6,
  "sugar": 3,
  "sodium": 480,
  "ingredients": [
    { "name": "Grilled chicken breast", "grams": 170, "kcal": 280, "protein": 53, "carbs": 0,  "fat": 6,  "fiber": 0, "sugar": 0, "sodium": 350 },
    { "name": "White rice",             "grams": 200, "kcal": 260, "protein": 5,  "carbs": 56, "fat": 1,  "fiber": 1, "sugar": 0, "sodium": 5  },
    { "name": "Steamed broccoli",       "grams": 50,  "kcal": 17,  "protein": 2,  "carbs": 3,  "fat": 0,  "fiber": 2, "sugar": 1, "sodium": 15 },
    { "name": "Olive oil drizzle",      "grams": 5,   "kcal": 45,  "protein": 0,  "carbs": 0,  "fat": 5,  "fiber": 0, "sugar": 0, "sodium": 0  }
  ],
  "confidence": 0.78
}

Rules:
- name: short, plain-English meal title.
- portion_g / kcal / protein / carbs / fat / fiber / sugar: INTEGERS in grams (sodium in milligrams).
- ingredients: 1-6 items, each fully populated.
- ingredient sums ≈ top-level totals (within rounding).
- confidence 0.0-1.0; lower when portion is hard to judge.
- If you can't identify food, return all zeros + name "Unknown" + confidence 0.1.`;

const INGREDIENT_SCHEMA = {
  type: "object",
  properties: {
    name:    { type: "string" },
    grams:   { type: "integer" },
    kcal:    { type: "integer" },
    protein: { type: "integer" },
    carbs:   { type: "integer" },
    fat:     { type: "integer" },
    fiber:   { type: "integer" },
    sugar:   { type: "integer" },
    sodium:  { type: "integer" },
  },
  required: ["name","grams","kcal","protein","carbs","fat","fiber","sugar","sodium"],
  additionalProperties: false,
};

const SCHEMA = {
  type: "object",
  properties: {
    name:      { type: "string" },
    portion_g: { type: "integer" },
    kcal:      { type: "integer" },
    protein:   { type: "integer" },
    carbs:     { type: "integer" },
    fat:       { type: "integer" },
    fiber:     { type: "integer" },
    sugar:     { type: "integer" },
    sodium:    { type: "integer" },
    ingredients: { type: "array", items: INGREDIENT_SCHEMA },
    confidence:  { type: "number" },
  },
  required: ["name","portion_g","kcal","protein","carbs","fat","fiber","sugar","sodium","ingredients","confidence"],
  additionalProperties: false,
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const apiKey = Deno.env.get("OPENAI_API_KEY");
    if (!apiKey) return json({ error: "OPENAI_API_KEY not set" }, { status: 500 });

    const body = await req.json();
    const raw = String(body?.image ?? "");
    if (!raw) return json({ error: "image: required" }, { status: 400 });
    const url = raw.startsWith("data:") ? raw : `data:image/jpeg;base64,${raw}`;

    const openaiRes = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${apiKey}` },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        temperature: 0.2,
        response_format: { type: "json_schema", json_schema: { name: "meal_macros", strict: true, schema: SCHEMA } },
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          {
            role: "user",
            content: [
              { type: "text", text: "Analyze this meal. Estimate portion in grams via visible scale cues, then return macros AND micronutrients (fiber, sugar, sodium) for that portion." },
              { type: "image_url", image_url: { url, detail: "high" } },
            ],
          },
        ],
      }),
    });

    if (!openaiRes.ok) {
      const detail = await openaiRes.text();
      return json({ error: "openai_failed", detail }, { status: 502 });
    }
    const completion = await openaiRes.json();
    const text = completion?.choices?.[0]?.message?.content ?? "{}";
    try { return json(JSON.parse(text)); }
    catch { return json({ error: "invalid_json_from_model", raw: text }, { status: 502 }); }
  } catch (e) {
    return json({ error: String(e) }, { status: 500 });
  }
});
