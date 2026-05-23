// supabase/functions/lookup-barcode — Open Food Facts product lookup
//
// Body: { code: "5901234123457" }
// Returns: { item: { name, foodKey, qty, category, daysLeft, confidence } } | { item: null }
//
// Uses the public Open Food Facts API (no key required).

import { corsHeaders, json } from "../_shared/cors.ts";

// Maps OpenFoodFacts category strings → Levla's foodKey set.
const KEYWORD_TO_FOOD: [string, { food: string; category: string; days: number }][] = [
  ["milk",          { food: "milk",     category: "Dairy",      days: 7 }],
  ["yogurt",        { food: "yogurt",   category: "Dairy",      days: 14 }],
  ["yoghurt",       { food: "yogurt",   category: "Dairy",      days: 14 }],
  ["skyr",          { food: "yogurt",   category: "Dairy",      days: 14 }],
  ["butter",        { food: "butter",   category: "Dairy",      days: 30 }],
  ["feta",          { food: "feta",     category: "Dairy",      days: 14 }],
  ["parmesan",      { food: "parmesan", category: "Pantry",     days: 60 }],
  ["cheese",        { food: "feta",     category: "Dairy",      days: 14 }],
  ["egg",           { food: "egg",      category: "Dairy",      days: 21 }],
  ["spinach",       { food: "spinach",  category: "Vegetables", days: 4 }],
  ["broccoli",      { food: "broccoli", category: "Vegetables", days: 5 }],
  ["tomato",        { food: "tomato",   category: "Vegetables", days: 6 }],
  ["carrot",        { food: "carrot",   category: "Vegetables", days: 14 }],
  ["pepper",        { food: "pepper",   category: "Vegetables", days: 7 }],
  ["capsicum",      { food: "pepper",   category: "Vegetables", days: 7 }],
  ["lemon",         { food: "lemon",    category: "Vegetables", days: 14 }],
  ["garlic",        { food: "garlic",   category: "Vegetables", days: 30 }],
  ["onion",         { food: "onion",    category: "Vegetables", days: 21 }],
  ["avocado",       { food: "avocado",  category: "Vegetables", days: 3 }],
  ["chicken",       { food: "chicken",  category: "Meat",       days: 2 }],
  ["salmon",        { food: "salmon",   category: "Meat",       days: 2 }],
  ["beef",          { food: "beef",     category: "Meat",       days: 2 }],
  ["rice",          { food: "rice",     category: "Pantry",     days: 365 }],
  ["pasta",         { food: "pasta",    category: "Pantry",     days: 365 }],
  ["spaghetti",     { food: "pasta",    category: "Pantry",     days: 365 }],
  ["olive oil",     { food: "oil",      category: "Pantry",     days: 365 }],
  ["bread",         { food: "bread",    category: "Pantry",     days: 5 }],
  ["sourdough",     { food: "bread",    category: "Pantry",     days: 5 }],
  ["pesto",         { food: "pesto",    category: "Pantry",     days: 30 }],
  ["wine",          { food: "wine",     category: "Drinks",     days: 30 }],
  ["water",         { food: "water",    category: "Drinks",     days: 365 }],
];

function mapToFood(haystack: string): { food: string; category: string; days: number } {
  const l = haystack.toLowerCase();
  for (const [needle, mapping] of KEYWORD_TO_FOOD) {
    if (l.includes(needle)) return mapping;
  }
  return { food: "milk", category: "Pantry", days: 30 };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { code } = await req.json();
    if (typeof code !== "string" || code.length < 6) {
      return json({ error: "code: barcode string required" }, { status: 400 });
    }

    const url = `https://world.openfoodfacts.org/api/v2/product/${encodeURIComponent(code)}.json?fields=product_name,brands,quantity,categories_tags`;
    const offRes = await fetch(url, {
      headers: { "User-Agent": "Levla/1.0 (https://levla.app)" },
    });

    if (!offRes.ok) {
      return json({ item: null, error: "openfoodfacts_failed" });
    }

    const data = await offRes.json();
    if (data?.status !== 1 || !data?.product) {
      return json({ item: null });
    }

    const p = data.product;
    const name: string = (p.product_name || p.generic_name || "Unknown product").toString().trim();
    const brand: string = (p.brands || "").toString().split(",")[0].trim();
    const qty: string = (p.quantity || "1").toString().trim();
    const haystack = [name, brand, ...(p.categories_tags || [])].join(" ");
    const m = mapToFood(haystack);

    return json({
      item: {
        name: brand ? `${brand} ${name}` : name,
        foodKey: m.food,
        qty: qty || "1",
        category: m.category,
        daysLeft: m.days,
        confidence: 0.86,
      },
    });
  } catch (e) {
    return json({ error: String(e) }, { status: 500 });
  }
});
