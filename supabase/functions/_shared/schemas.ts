// Shared OpenAI Structured Outputs schemas. Passed to chat.completions via
// `response_format: { type: "json_schema", json_schema: { ... strict: true } }`.
// When strict is true the model is GUARANTEED to return JSON matching this
// schema exactly — no drifting field names, no number-as-string surprises.

export const FOOD_KEYS = [
  // dairy
  "milk", "yogurt", "butter", "feta", "egg", "cream", "cheese",
  // vegetables
  "spinach", "broccoli", "tomato", "carrot", "pepper", "lemon", "lime",
  "garlic", "ginger", "onion", "avocado", "potato", "sweet-potato",
  "mushroom", "cucumber", "zucchini", "lettuce", "cabbage",
  // proteins
  "chicken", "salmon", "beef", "tuna", "shrimp", "tofu",
  // pantry
  "rice", "pasta", "oil", "bread", "pesto", "parmesan",
  // drinks
  "wine", "water",
] as const;

export const CATEGORIES = [
  "Dairy", "Vegetables", "Meat", "Pantry", "Drinks", "Freezer",
] as const;

export const DIFFICULTIES = ["Easy", "Medium", "Hard"] as const;

export const MEAL_TYPES = ["breakfast", "lunch", "dinner"] as const;

export const COLOR_HEXES = [
  "EFD8C0", "C97B4B", "E1E9D2", "6B8A5C", "DCE6CC", "5C7E40",
  "F2E5D2", "B8884A", "F3D6C6", "C9543C", "F4ECC0", "D6A45A",
  "DEE5C9", "637840", "F1ECDE", "E0E5C7", "7E904A",
];

/// Schema used by BOTH scan-fridge and scan-receipt — same item shape.
export const itemsSchema = {
  type: "object",
  properties: {
    items: {
      type: "array",
      items: {
        type: "object",
        properties: {
          name:       { type: "string" },
          foodKey:    { type: "string", enum: [...FOOD_KEYS] },
          qty:        { type: "string" },
          category:   { type: "string", enum: [...CATEGORIES] },
          daysLeft:   { type: "integer" },
          confidence: { type: "number" },
        },
        required: ["name", "foodKey", "qty", "category", "daysLeft", "confidence"],
        additionalProperties: false,
      },
    },
  },
  required: ["items"],
  additionalProperties: false,
};

/// Schema for the suggest-recipes function. 12 recipes split across
/// breakfast/lunch/dinner, each fully specified including fat + mealType.
export const recipesSchema = {
  type: "object",
  properties: {
    recipes: {
      type: "array",
      items: {
        type: "object",
        properties: {
          slug:        { type: "string" },
          title:       { type: "string" },
          subtitle:    { type: "string" },
          timeMinutes: { type: "integer" },
          kcal:        { type: "integer" },
          protein:     { type: "integer" },
          carbs:       { type: "integer" },
          fat:         { type: "integer" },
          mealType:    { type: "string", enum: [...MEAL_TYPES] },
          difficulty:  { type: "string", enum: [...DIFFICULTIES] },
          uses:        { type: "array", items: { type: "string", enum: [...FOOD_KEYS] } },
          why:         { type: "string" },
          colorHex:    { type: "string", enum: [...COLOR_HEXES] },
          accentHex:   { type: "string", enum: [...COLOR_HEXES] },
          tags:        { type: "array", items: { type: "string" } },
          ingredients: {
            type: "array",
            items: {
              type: "object",
              properties: {
                foodKey: { type: "string", enum: [...FOOD_KEYS] },
                name:    { type: "string" },
                amount:  { type: "string" },
              },
              required: ["foodKey", "name", "amount"],
              additionalProperties: false,
            },
          },
          steps: { type: "array", items: { type: "string" } },
        },
        required: [
          "slug", "title", "subtitle", "timeMinutes", "kcal", "protein", "carbs", "fat",
          "mealType", "difficulty", "uses", "why", "colorHex", "accentHex", "tags",
          "ingredients", "steps",
        ],
        additionalProperties: false,
      },
    },
  },
  required: ["recipes"],
  additionalProperties: false,
};

/// Wrap a schema in the OpenAI `response_format` envelope.
export function strictSchema(name: string, schema: unknown) {
  return {
    type: "json_schema",
    json_schema: { name, strict: true, schema },
  };
}
