// supabase/functions/analyze-meal — Cal-AI / BitePal flow: snap a photo,
// get back identified meal + macros computed for the VISIBLE portion.
//
// The previous version asked the model for macros "per serving", which is
// ambiguous and often defaults to a generic 1-serving estimate even when
// the user clearly snapped a half portion or a heaped double. This version
// is much stricter: it has to estimate grams using on-screen scale cues
// (plate diameter, fork length, hand width, etc.) and compute macros for
// THAT portion. The response now includes portion_g + per-ingredient
// grams so the iOS side can show "~340g portion".
//
// Body: { image: "data:image/jpeg;base64,..." | base64 }
// Returns: { name, portion_g, kcal, protein, carbs, fat,
//            ingredients: [{name, grams, kcal, protein, carbs, fat}],
//            confidence }

import { corsHeaders, json } from "../_shared/cors.ts";

const SYSTEM_PROMPT = `You are Levla's meal-analysis vision model. The user shows you a photo of a meal or single food item. Your job is to identify it AND estimate the calorie/macro content of the SPECIFIC PORTION visible in the photo — not a generic "1 serving".

Portion sizing is mandatory:
- Estimate the total weight of food in grams (portion_g) and the grams of each visible ingredient.
- Use on-screen scale cues: a dinner plate is ~26-28 cm diameter, a side plate ~20 cm, a fork ~20 cm long, a chopstick ~24 cm, a soda can ~12 cm tall, a hand ~18-20 cm long, a slice of bread ~12 cm wide.
- Look at FOOD VOLUME, not surface area. A heaped scoop of rice that fills a 14 cm bowl to the brim is roughly 250 g cooked rice. A flat layer is closer to 130 g. Sauces and dressings add density — don't undercount them.
- If the photo is angled, mentally rotate to estimate volume. If you genuinely can't tell, lower the confidence and pick a sensible middle value rather than 1 serving.
- Compute kcal/protein/carbs/fat from THAT gram estimate using standard food density: protein has 4 kcal/g, carbs 4 kcal/g, fat 9 kcal/g. The top-level macros must equal the sum of ingredient macros within rounding (±5 kcal).

Return ONLY JSON in this exact shape, no markdown:
{
  "name": "Grilled chicken, rice & broccoli",
  "portion_g": 420,
  "kcal": 568,
  "protein": 48,
  "carbs": 62,
  "fat": 14,
  "ingredients": [
    { "name": "Grilled chicken breast", "grams": 170, "kcal": 280, "protein": 53, "carbs": 0,  "fat": 6 },
    { "name": "White rice",             "grams": 200, "kcal": 260, "protein": 5,  "carbs": 56, "fat": 1 },
    { "name": "Steamed broccoli",       "grams": 50,  "kcal": 17,  "protein": 2,  "carbs": 3,  "fat": 0 },
    { "name": "Olive oil drizzle",      "grams": 5,   "kcal": 45,  "protein": 0,  "carbs": 0,  "fat": 5 }
  ],
  "confidence": 0.78
}

Rules:
- name: short, plain-English meal title.
- portion_g: INTEGER, total weight of visible food in grams.
- kcal / protein / carbs / fat: INTEGERS (grams for macros, kcal for energy).
- ingredients: 1–6 items, each with its own grams + macros.
- The kcal/protein/carbs/fat sum of ingredients must approximately equal the top-level numbers.
- confidence: 0.0–1.0. Lower it when portion size is hard to judge (no scale cue, weird angle, partially obscured).
- If you can't identify any food, return {"name":"Unknown","portion_g":0,"kcal":0,"protein":0,"carbs":0,"fat":0,"ingredients":[],"confidence":0.1}.`;

const SCHEMA = {
  type: "object",
  properties: {
    name:      { type: "string" },
    portion_g: { type: "integer" },
    kcal:      { type: "integer" },
    protein:   { type: "integer" },
    carbs:     { type: "integer" },
    fat:       { type: "integer" },
    ingredients: {
      type: "array",
      items: {
        type: "object",
        properties: {
          name:    { type: "string" },
          grams:   { type: "integer" },
          kcal:    { type: "integer" },
          protein: { type: "integer" },
          carbs:   { type: "integer" },
          fat:     { type: "integer" },
        },
        required: ["name", "grams", "kcal", "protein", "carbs", "fat"],
        additionalProperties: false,
      },
    },
    confidence: { type: "number" },
  },
  required: ["name", "portion_g", "kcal", "protein", "carbs", "fat", "ingredients", "confidence"],
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
              { type: "text", text: "Analyze this meal. Estimate portion size in grams using visible scale cues, then return macros for THAT portion." },
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
    try {
      return json(JSON.parse(text));
    } catch {
      return json({ error: "invalid_json_from_model", raw: text }, { status: 502 });
    }
  } catch (e) {
    return json({ error: String(e) }, { status: 500 });
  }
});
