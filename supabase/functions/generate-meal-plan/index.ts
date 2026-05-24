// supabase/functions/generate-meal-plan — one-shot personalized daily
// nutrition plan, called at the end of onboarding (and optionally when
// the user manually re-runs it from their profile).
//
// Takes the user's full profile snapshot and returns kcal + macros +
// micros tuned to their goal, sex, age, height, weight, activity, and
// dietary preferences — plus a one-paragraph rationale explaining the
// numbers in the user's voice.
//
// Body:    { profile: { sex, age, heightCm, weightKg, activityLevel, goal, dietaryPrefs } }
// Returns: { kcal, protein, carbs, fat, fiber, sugar, sodium, rationale }

import { corsHeaders, json } from "./_shared/cors.ts";

interface ProfileIn {
  sex?: string;
  age?: number;
  heightCm?: number;
  weightKg?: number;
  activityLevel?: string;
  goal?: string;
  dietaryPrefs?: string[];
}

const SYSTEM_PROMPT = `You are Levla's nutrition planner — a registered dietitian designing a personalised daily nutrition plan for a single user. You produce ONE plan: a single set of daily targets (kcal + macros + micros) that the user will track against every day.

Use Mifflin–St Jeor for the base BMR, multiply by the standard activity factor, then adjust for the user's goal. Be smarter than a textbook calculator: think like a dietitian who's about to write this person's plan.

Macro philosophy:
- Protein: 1.6–2.2 g/kg bodyweight for fat loss or muscle gain (preserves lean mass during deficit, supports hypertrophy during surplus). 1.2–1.6 g/kg for maintenance / general health.
- Fat: 25–35% of total kcal. Lower end for high-protein cutting phases, higher end for hormonal health on lower-carb plans.
- Carbs: remaining kcal. Lean toward complex carbs.
- Fiber: target 14 g per 1000 kcal (Institute of Medicine recommendation), bumping higher for fat loss / gut health.
- Sugar (added/free): cap at 10% of kcal (WHO); aggressive cut for fat-loss goals.
- Sodium: cap at 2000–2300 mg/day (AHA practical target). Athletes can go higher.

Numbers must be honest and round to sensible integers (kcal to nearest 10, macros to nearest 5g, sodium to nearest 100mg).

The rationale is one short paragraph (2-3 sentences) in second person ("you"), explaining what's driving the numbers in plain language the user can understand. Don't quote formulas — explain the trade-off. Example: "You're at a moderate 450-calorie deficit aimed at ~0.4 kg/week of fat loss while keeping protein high enough to hold onto muscle. I've kept fats around 30% for satiety, and bumped fiber to support digestion during the cut."

If the profile is missing fields, use safe averages (5'7", 70 kg, 30 yrs, moderate activity, maintain) but call out the assumption briefly in the rationale.`;

const SCHEMA = {
  type: "object",
  properties: {
    kcal:      { type: "integer" },
    protein:   { type: "integer" },
    carbs:     { type: "integer" },
    fat:       { type: "integer" },
    fiber:     { type: "integer" },
    sugar:     { type: "integer" },
    sodium:    { type: "integer" },
    rationale: { type: "string" },
  },
  required: ["kcal", "protein", "carbs", "fat", "fiber", "sugar", "sodium", "rationale"],
  additionalProperties: false,
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const apiKey = Deno.env.get("OPENAI_API_KEY");
    if (!apiKey) return json({ error: "OPENAI_API_KEY not set" }, { status: 500 });

    const body = await req.json();
    const profile: ProfileIn = body?.profile ?? {};

    const summary = [
      profile.sex ? `Sex: ${profile.sex}` : null,
      typeof profile.age === "number" ? `Age: ${profile.age}` : null,
      typeof profile.heightCm === "number" ? `Height: ${profile.heightCm} cm` : null,
      typeof profile.weightKg === "number" ? `Weight: ${profile.weightKg} kg` : null,
      profile.activityLevel ? `Activity: ${profile.activityLevel}` : null,
      profile.goal ? `Goal: ${profile.goal}` : null,
      Array.isArray(profile.dietaryPrefs) && profile.dietaryPrefs.length > 0
        ? `Dietary preferences: ${profile.dietaryPrefs.join(", ")}`
        : null,
    ].filter(Boolean).join("\n");

    const userMsg = `Design a daily nutrition plan for this user:\n\n${summary || "(no profile data provided)"}\n\nReturn only the JSON object specified by the schema.`;

    const openaiRes = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${apiKey}` },
      body: JSON.stringify({
        model: "gpt-4.1-mini",
        temperature: 0.4,
        response_format: { type: "json_schema", json_schema: { name: "meal_plan", strict: true, schema: SCHEMA } },
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          { role: "user", content: userMsg },
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
