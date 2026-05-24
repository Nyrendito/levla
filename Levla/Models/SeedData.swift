import Foundation

/// Static seed recipes — the design's RECIPES table. These ship locally so
/// the Cook deck has content even before the user adds anything to the fridge.
/// In production you'd back this with a `recipes` table on Supabase.
enum SeedData {
    static let recipes: [Recipe] = [
        Recipe(
            id: UUID(uuidString: "11111111-0000-0000-0000-000000000001")!,
            slug: "lem-salmon", title: "Lemon butter salmon", subtitle: "with crisp spinach",
            timeMinutes: 22, kcal: 510, protein: 36, carbs: 14, fat: 32, mealType: .dinner, difficulty: "Easy",
            matchPct: 100, missing: [],
            uses: ["salmon", "spinach", "lemon", "butter", "garlic"],
            why: "Your spinach should be used today.",
            colorHex: "EFD8C0", accentHex: "C97B4B",
            tags: ["high-protein", "use soon", "< 25 min"],
            ingredients: [
                .init(foodKey: "salmon", name: "Salmon fillet", amount: "2 × 150 g"),
                .init(foodKey: "spinach", name: "Baby spinach", amount: "200 g", useSoon: true),
                .init(foodKey: "lemon", name: "Lemon", amount: "1"),
                .init(foodKey: "butter", name: "Butter", amount: "40 g"),
                .init(foodKey: "garlic", name: "Garlic", amount: "2 cloves"),
                .init(foodKey: "oil", name: "Olive oil", amount: "1 tbsp", low: true),
            ],
            steps: [
                "Pat the salmon dry, season both sides with flaky salt.",
                "Melt butter in a wide pan over medium-high heat.",
                "Sear salmon skin-down 4 min, flip and add lemon + garlic.",
                "Wilt spinach in the buttery pan juices, plate and spoon over.",
            ]
        ),
        Recipe(
            id: UUID(uuidString: "11111111-0000-0000-0000-000000000002")!,
            slug: "pasta-pesto", title: "Pesto pasta, blistered tomatoes", subtitle: "pantry-only weeknight",
            timeMinutes: 16, kcal: 580, protein: 19, carbs: 78, fat: 22, mealType: .lunch, difficulty: "Easy",
            matchPct: 100, missing: [],
            uses: ["pasta", "pesto", "tomato", "parmesan"],
            why: "You have everything for this.",
            colorHex: "E1E9D2", accentHex: "6B8A5C",
            tags: ["15 min", "pantry", "vegetarian"],
            ingredients: [
                .init(foodKey: "pasta", name: "Spaghetti", amount: "200 g"),
                .init(foodKey: "pesto", name: "Basil pesto", amount: "4 tbsp"),
                .init(foodKey: "tomato", name: "Vine tomatoes", amount: "8"),
                .init(foodKey: "parmesan", name: "Parmesan", amount: "30 g"),
                .init(foodKey: "oil", name: "Olive oil", amount: "1 tbsp", low: true),
            ],
            steps: [
                "Salt water heavily, boil pasta to al dente.",
                "Blister tomatoes in a hot pan with olive oil, 4 min.",
                "Toss pasta with pesto, a splash of pasta water, tomatoes.",
                "Shower with parmesan, crack of pepper.",
            ]
        ),
        Recipe(
            id: UUID(uuidString: "11111111-0000-0000-0000-000000000003")!,
            slug: "roast-veg", title: "Sheet-pan roast veg & feta", subtitle: "low effort, big flavor",
            timeMinutes: 35, kcal: 460, protein: 18, carbs: 42, fat: 24, mealType: .lunch, difficulty: "Easy",
            matchPct: 92, missing: ["Honey"],
            uses: ["broccoli", "carrot", "feta", "onion", "oil"],
            why: "Clears 4 fridge items.",
            colorHex: "DCE6CC", accentHex: "5C7E40",
            tags: ["one-pan", "vegetarian", "meal-prep"],
            ingredients: [
                .init(foodKey: "broccoli", name: "Broccoli", amount: "1 head", useSoon: true),
                .init(foodKey: "carrot", name: "Carrots", amount: "300 g"),
                .init(foodKey: "onion", name: "Red onion", amount: "1"),
                .init(foodKey: "feta", name: "Feta", amount: "180 g"),
                .init(foodKey: "oil", name: "Olive oil", amount: "3 tbsp", low: true),
                .init(foodKey: "lemon", name: "Honey", amount: "1 tbsp", have: false),
            ],
            steps: [
                "Heat oven to 220°C.",
                "Toss veg with oil, salt, roast 25 min.",
                "Crumble feta + honey over warm tray.",
                "Squeeze lemon, serve.",
            ]
        ),
        Recipe(
            id: UUID(uuidString: "11111111-0000-0000-0000-000000000004")!,
            slug: "sour-toast", title: "Avocado sourdough, soft egg", subtitle: "8 minute breakfast",
            timeMinutes: 8, kcal: 380, protein: 18, carbs: 36, fat: 18, mealType: .breakfast, difficulty: "Easy",
            matchPct: 100, missing: [],
            uses: ["avocado", "bread", "egg", "lemon"],
            why: "Bread expires in 2 days.",
            colorHex: "E0E5C7", accentHex: "7E904A",
            tags: ["breakfast", "fast"],
            ingredients: [
                .init(foodKey: "avocado", name: "Avocado", amount: "1"),
                .init(foodKey: "bread", name: "Sourdough", amount: "2 slices", useSoon: true),
                .init(foodKey: "egg", name: "Egg", amount: "1"),
                .init(foodKey: "lemon", name: "Lemon", amount: "½"),
            ],
            steps: [
                "Toast the sourdough until deeply golden.",
                "Soft-boil the egg 6 minutes, run under cold water.",
                "Mash avocado with lemon and salt.",
                "Pile onto toast, halve the egg over it.",
            ]
        ),
        Recipe(
            id: UUID(uuidString: "11111111-0000-0000-0000-000000000005")!,
            slug: "tomato-pasta", title: "Garlicky tomato spaghetti", subtitle: "pantry classic, 12 min",
            timeMinutes: 12, kcal: 480, protein: 14, carbs: 76, fat: 14, mealType: .dinner, difficulty: "Easy",
            matchPct: 100, missing: [],
            uses: ["pasta", "tomato", "garlic", "oil", "parmesan"],
            why: "Tonight, no thinking.",
            colorHex: "F3D6C6", accentHex: "C9543C",
            tags: ["fast", "pantry"],
            ingredients: [
                .init(foodKey: "pasta", name: "Spaghetti", amount: "200 g"),
                .init(foodKey: "tomato", name: "Vine tomatoes", amount: "6"),
                .init(foodKey: "garlic", name: "Garlic", amount: "3 cloves"),
                .init(foodKey: "oil", name: "Olive oil", amount: "2 tbsp", low: true),
                .init(foodKey: "parmesan", name: "Parmesan", amount: "20 g"),
            ],
            steps: [
                "Bring salted water to a boil; cook spaghetti.",
                "Sweat garlic in oil, add halved tomatoes.",
                "Smash tomatoes lightly, add a splash of pasta water.",
                "Toss pasta through, finish with parmesan.",
            ]
        ),
        Recipe(
            id: UUID(uuidString: "11111111-0000-0000-0000-000000000006")!,
            slug: "frittata", title: "Fridge-clean frittata", subtitle: "whatever's leftover",
            timeMinutes: 22, kcal: 360, protein: 24, carbs: 8, fat: 22, mealType: .breakfast, difficulty: "Easy",
            matchPct: 100, missing: [],
            uses: ["egg", "spinach", "feta", "tomato", "onion"],
            why: "Clears 5 fridge items.",
            colorHex: "F1ECDE", accentHex: "D6A45A",
            tags: ["use up", "breakfast"],
            ingredients: [
                .init(foodKey: "egg", name: "Eggs", amount: "6"),
                .init(foodKey: "spinach", name: "Baby spinach", amount: "1 handful", useSoon: true),
                .init(foodKey: "feta", name: "Feta", amount: "80 g"),
                .init(foodKey: "tomato", name: "Tomatoes", amount: "3"),
                .init(foodKey: "onion", name: "Onion", amount: "½"),
            ],
            steps: [
                "Heat oven to 180°C.",
                "Soften onion in an oven-safe pan with oil.",
                "Pour over beaten eggs, scatter spinach, tomato, feta.",
                "Bake 12 minutes until just set.",
            ]
        ),
    ]

    /// Demo inventory for first launch (or unauthenticated preview).
    static func demoInventory(userId: UUID) -> [FoodItem] {
        let base = Date()
        let item: (String, String, FoodCategory, String, Int, Bool) -> FoodItem = { key, name, cat, qty, days, low in
            FoodItem(userId: userId, name: name, foodKey: key, category: cat, qty: qty, daysLeft: days, addedAt: base, source: .scan, isLow: low)
        }
        return [
            item("milk", "Whole milk", .dairy, "1.2 L", 3, false),
            item("yogurt", "Greek yoghurt", .dairy, "450 g", 8, false),
            item("butter", "Salted butter", .dairy, "½ block", 22, false),
            item("feta", "Feta", .dairy, "180 g", 12, false),
            item("egg", "Eggs", .dairy, "6", 9, false),
            item("spinach", "Baby spinach", .vegetables, "½ bag", 0, false),
            item("broccoli", "Broccoli", .vegetables, "1 head", 2, false),
            item("tomato", "Vine tomatoes", .vegetables, "4", 5, false),
            item("avocado", "Avocado", .vegetables, "2", 2, false),
            item("lemon", "Lemon", .vegetables, "3", 11, false),
            item("garlic", "Garlic", .vegetables, "1 bulb", 21, false),
            item("onion", "Red onion", .vegetables, "2", 18, false),
            item("carrot", "Carrots", .vegetables, "500 g", 13, false),
            item("chicken", "Chicken thighs", .meat, "600 g", 2, false),
            item("salmon", "Salmon fillet", .meat, "2 × 150g", 1, false),
            item("rice", "Arborio rice", .pantry, "~ ¾ bag", 120, false),
            item("pasta", "Spaghetti", .pantry, "350 g", 240, false),
            item("oil", "Olive oil", .pantry, "~ ⅓", 60, true),
            item("bread", "Sourdough", .pantry, "½ loaf", 2, false),
            item("pesto", "Basil pesto", .pantry, "½ jar", 14, false),
            item("parmesan", "Parmesan", .pantry, "120 g", 30, false),
            item("wine", "White wine", .drinks, "½ btl", 4, false),
            item("water", "Sparkling", .drinks, "4 btls", 90, false),
        ]
    }

    static func demoShopping(userId: UUID) -> [ShoppingListItem] {
        func item(_ name: String, _ qty: String, _ section: String, auto: Bool, forRecipe: String? = nil, addedBy: String? = nil, checked: Bool = false) -> ShoppingListItem {
            ShoppingListItem(id: UUID(), userId: userId, name: name, qty: qty, section: section, auto: auto, forRecipe: forRecipe, checked: checked, inFridge: false, addedBy: addedBy, createdAt: Date())
        }
        return [
            item("Honey", "1 jar", "Produce", auto: true, forRecipe: "Sheet-pan veg"),
            item("Fresh thyme", "1 bunch", "Produce", auto: true, forRecipe: "Galette"),
            item("Lemons", "3", "Produce", auto: false, addedBy: "Sam", checked: true),
            item("Whole milk", "1 L", "Dairy", auto: true, forRecipe: "Running low"),
            item("Eggs", "12", "Dairy", auto: false),
            item("Orzo", "500 g", "Pantry", auto: true, forRecipe: "Lemon orzo"),
            item("Chicken stock", "1 L", "Pantry", auto: true, forRecipe: "Lemon orzo"),
            item("Puff pastry", "1 sheet", "Pantry", auto: true, forRecipe: "Galette"),
            item("Olive oil", "500 ml", "Pantry", auto: true, forRecipe: "Running low"),
            item("Sourdough", "1 loaf", "Bakery", auto: false),
        ]
    }
}
