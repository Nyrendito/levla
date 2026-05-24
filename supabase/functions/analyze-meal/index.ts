// supabase/functions/analyze-meal — Cal-AI / BitePal flow: snap a photo,
// get back identified meal + macros. Uses GPT-4o-mini vision.
//
// Body: { image: "data:image/jpeg;base64,..." | base64 }
// Returns: { name, kcal, protein, carbs, fat, ingredients: [{name, kcal, protein, carbs, fat}], confidence }

import { corsHeaders, json } from "../_shared/cors.ts";

const SYSTEM_PROMPT = `You are Levla's meal-analysis vision model. The user shows you a photo of a meal or single food item. You identify the meal and estimate the macronutrients per serving in the photo.

Return ONLY JSON in this exact shape, no markdown:
{
  "name": "Fried egg, avocado & toast",
  "kcal": 306,
  "protein": 13,
  "carbs": 26,
  "fat": 16,
  "ingredients": [
    { "name": "Fried egg",      "kcal": 137, "protein": 9,  "carbs": 0,  "fat": 10 },
    { "name": "Whole-grain toast", "kcal": 90, "protein": 3,  "carbs": 16, "fat": 1 },
    { "name": "Avocado",        "kcal": 79, "protein": 1,  "carbs": 4,  "fat": 7 }
  ],
  "confidence": 0.84
}

Rules:
- name: short human-readable meal title.
- All macro numbers are INTEGERS in grams (carbs, protein, fat) and INTEGER kcal.
- ingredients lists each visible component with its OWN macros, 1-6 items.
- The top-level macros = sum of ingredient macros (approximately).
- confidence: 0.0-1.0; lower if the photo is unclear or the food is ambiguous.
- If you cannot identify anything food-related, return {"name":"Unknown","kcal":0,"protein":0,"carbs":0,"fat":0,"ingredients":[],"confidence":0.1}.`;

const SCHEMA = {
  type: "object",
  properties: {
    name: { type: "string" },
    kcal: { type: "integer" },
    protein: { type: "integer" },
    carbs: { type: "integer" },
    fat: { type: "integer" },
    ingredients: {
      type: "array",
      items: {
        type: "object",
        properties: {
          name: { type: "string" },
          kcal: { type: "integer" },
          protein: { type: "integer" },
          carbs: { type: "integer" },
          fat: { type: "integer" },
        },
        required: ["name", "kcal", "protein", "carbs", "fat"],
        additionalProperties: false,
      },
    },
    confidence: { type: "number" },
  },
  required: ["name", "kcal", "protein", "carbs", "fat", "ingredients", "confidence"],
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
              { type: "text", text: "Analyze this meal and return JSON." },
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
