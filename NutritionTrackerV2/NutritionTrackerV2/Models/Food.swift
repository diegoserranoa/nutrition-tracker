//
//  Food.swift
//  NutritionTrackerV2
//
//  Core data model for food items with comprehensive nutritional information
//

import Foundation

// MARK: - Food Model

struct Food: Codable, Identifiable, Hashable, Timestamped {
    let id: UUID
    let name: String
    let brand: String?
    let barcode: String?
    let description: String?

    // Serving information
    let servingSize: Double
    let servingUnit: String
    let servingSizeGrams: Double?

    // Macronutrients (per serving)
    let calories: Double
    let protein: Double // grams
    let carbohydrates: Double // grams
    let fat: Double // grams
    let fiber: Double?
    let sugar: Double?
    let saturatedFat: Double?
    let unsaturatedFat: Double?
    let transFat: Double?

    // Micronutrients (per serving) - all in mg unless specified
    let sodium: Double?
    let potassium: Double?
    let calcium: Double?
    let iron: Double?
    let vitaminA: Double? // mcg
    let vitaminC: Double?
    let vitaminD: Double? // mcg
    let vitaminE: Double?
    let vitaminK: Double? // mcg
    let vitaminB1: Double? // thiamin
    let vitaminB2: Double? // riboflavin
    let vitaminB3: Double? // niacin
    let vitaminB6: Double?
    let vitaminB12: Double? // mcg
    let folate: Double? // mcg
    let magnesium: Double?
    let phosphorus: Double?
    let zinc: Double?

    // Metadata
    let category: FoodCategory?
    let isVerified: Bool
    let source: FoodSource
    let createdAt: Date
    let updatedAt: Date
    let createdBy: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case brand
        case barcode
        case description
        case servingSize = "serving_size"
        case servingUnit = "serving_unit"
        case servingSizeGrams = "serving_size_grams"
        case calories
        case protein
        case carbohydrates
        case fat
        case fiber
        case sugar
        case saturatedFat = "saturated_fat"
        case unsaturatedFat = "unsaturated_fat"
        case transFat = "trans_fat"
        case sodium
        case potassium
        case calcium
        case iron
        case vitaminA = "vitamin_a"
        case vitaminC = "vitamin_c"
        case vitaminD = "vitamin_d"
        case vitaminE = "vitamin_e"
        case vitaminK = "vitamin_k"
        case vitaminB1 = "vitamin_b1"
        case vitaminB2 = "vitamin_b2"
        case vitaminB3 = "vitamin_b3"
        case vitaminB6 = "vitamin_b6"
        case vitaminB12 = "vitamin_b12"
        case folate
        case magnesium
        case phosphorus
        case zinc
        case category
        case isVerified = "is_verified"
        case source
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case createdBy = "created_by"
    }
}

// MARK: - Food Category

enum FoodCategory: String, Codable, CaseIterable {
    case fruits = "fruits"
    case vegetables = "vegetables"
    case grains = "grains"
    case protein = "protein"
    case dairy = "dairy"
    case fats = "fats"
    case beverages = "beverages"
    case snacks = "snacks"
    case sweets = "sweets"
    case condiments = "condiments"
    case spices = "spices"
    case nuts = "nuts"
    case seeds = "seeds"
    case legumes = "legumes"
    case seafood = "seafood"
    case poultry = "poultry"
    case meat = "meat"
    case eggs = "eggs"
    case plantBased = "plant_based"
    case processed = "processed"
    case baked = "baked"
    case frozen = "frozen"
    case canned = "canned"
    case fresh = "fresh"
    case other = "other"

    var displayName: String {
        switch self {
        case .fruits: return "Fruits"
        case .vegetables: return "Vegetables"
        case .grains: return "Grains"
        case .protein: return "Protein"
        case .dairy: return "Dairy"
        case .fats: return "Fats & Oils"
        case .beverages: return "Beverages"
        case .snacks: return "Snacks"
        case .sweets: return "Sweets & Desserts"
        case .condiments: return "Condiments"
        case .spices: return "Spices & Herbs"
        case .nuts: return "Nuts"
        case .seeds: return "Seeds"
        case .legumes: return "Legumes"
        case .seafood: return "Seafood"
        case .poultry: return "Poultry"
        case .meat: return "Meat"
        case .eggs: return "Eggs"
        case .plantBased: return "Plant-Based"
        case .processed: return "Processed Foods"
        case .baked: return "Baked Goods"
        case .frozen: return "Frozen Foods"
        case .canned: return "Canned Foods"
        case .fresh: return "Fresh Foods"
        case .other: return "Other"
        }
    }
}

// MARK: - Food Source

enum FoodSource: String, Codable {
    case usda = "usda"
    case userCreated = "user_created"
    case barcodeLookup = "barcode_lookup"
    case manual = "manual"
    case restaurant = "restaurant"
    case recipe = "recipe"
    case imported = "imported"

    var displayName: String {
        switch self {
        case .usda: return "USDA Database"
        case .userCreated: return "User Created"
        case .barcodeLookup: return "Barcode Lookup"
        case .manual: return "Manual Entry"
        case .restaurant: return "Restaurant Data"
        case .recipe: return "Recipe"
        case .imported: return "Imported"
        }
    }
}

// MARK: - Food Extensions

extension Food {

    // MARK: - Computed Properties

    /// Calories per gram
    var caloriesPerGram: Double? {
        guard let servingSizeGrams = servingSizeGrams, servingSizeGrams > 0 else { return nil }
        return calories / servingSizeGrams
    }

    /// Macronutrient breakdown as percentages
    var macronutrientBreakdown: (protein: Double, carbs: Double, fat: Double) {
        let totalCalories = max(calories, 1) // Avoid division by zero
        let proteinCalories = protein * 4 // 4 calories per gram
        let carbCalories = carbohydrates * 4 // 4 calories per gram
        let fatCalories = fat * 9 // 9 calories per gram

        return (
            protein: (proteinCalories / totalCalories) * 100,
            carbs: (carbCalories / totalCalories) * 100,
            fat: (fatCalories / totalCalories) * 100
        )
    }

    /// Display name with brand if available
    var displayName: String {
        if let brand = brand, !brand.isEmpty {
            return "\(brand) \(name)"
        }
        return name
    }

    /// Full serving description
    var servingDescription: String {
        "\(servingSize.formatted(.number.precision(.fractionLength(0...2)))) \(servingUnit)"
    }

    // MARK: - Nutritional Scaling

    /// Scale nutritional values for a given serving multiplier
    /// - Parameter multiplier: The multiplier for the serving size (e.g., 2.0 for double serving)
    /// - Returns: A new Food instance with scaled nutritional values
    func scaled(by multiplier: Double) -> Food {
        return Food(
            id: self.id,
            name: self.name,
            brand: self.brand,
            barcode: self.barcode,
            description: self.description,
            servingSize: self.servingSize * multiplier,
            servingUnit: self.servingUnit,
            servingSizeGrams: self.servingSizeGrams.map { $0 * multiplier },
            calories: self.calories * multiplier,
            protein: self.protein * multiplier,
            carbohydrates: self.carbohydrates * multiplier,
            fat: self.fat * multiplier,
            fiber: self.fiber.map { $0 * multiplier },
            sugar: self.sugar.map { $0 * multiplier },
            saturatedFat: self.saturatedFat.map { $0 * multiplier },
            unsaturatedFat: self.unsaturatedFat.map { $0 * multiplier },
            transFat: self.transFat.map { $0 * multiplier },
            sodium: self.sodium.map { $0 * multiplier },
            potassium: self.potassium.map { $0 * multiplier },
            calcium: self.calcium.map { $0 * multiplier },
            iron: self.iron.map { $0 * multiplier },
            vitaminA: self.vitaminA.map { $0 * multiplier },
            vitaminC: self.vitaminC.map { $0 * multiplier },
            vitaminD: self.vitaminD.map { $0 * multiplier },
            vitaminE: self.vitaminE.map { $0 * multiplier },
            vitaminK: self.vitaminK.map { $0 * multiplier },
            vitaminB1: self.vitaminB1.map { $0 * multiplier },
            vitaminB2: self.vitaminB2.map { $0 * multiplier },
            vitaminB3: self.vitaminB3.map { $0 * multiplier },
            vitaminB6: self.vitaminB6.map { $0 * multiplier },
            vitaminB12: self.vitaminB12.map { $0 * multiplier },
            folate: self.folate.map { $0 * multiplier },
            magnesium: self.magnesium.map { $0 * multiplier },
            phosphorus: self.phosphorus.map { $0 * multiplier },
            zinc: self.zinc.map { $0 * multiplier },
            category: self.category,
            isVerified: self.isVerified,
            source: self.source,
            createdAt: self.createdAt,
            updatedAt: self.updatedAt,
            createdBy: self.createdBy
        )
    }

    /// Scale nutritional values for a specific gram amount
    /// - Parameter grams: The target weight in grams
    /// - Returns: A new Food instance scaled to the specified gram amount
    func scaledToGrams(_ grams: Double) -> Food? {
        guard let servingSizeGrams = servingSizeGrams, servingSizeGrams > 0 else { return nil }
        let multiplier = grams / servingSizeGrams
        return scaled(by: multiplier)
    }

    // MARK: - Validation

    /// Validates that the food has complete basic nutritional information
    var hasCompleteBasicNutrition: Bool {
        return calories >= 0 && protein >= 0 && carbohydrates >= 0 && fat >= 0
    }

    /// Validates that macronutrient calories roughly match total calories (within 10% tolerance)
    var hasConsistentMacronutrients: Bool {
        let macroCalories = (protein * 4) + (carbohydrates * 4) + (fat * 9)
        let difference = abs(macroCalories - calories)
        let tolerance = calories * 0.1 // 10% tolerance
        return difference <= tolerance
    }
}

// MARK: - Sample Data

extension Food {

    /// Sample food data for testing and previews
    static let sampleFoods: [Food] = [
        Food(
            id: UUID(),
            name: "Banana",
            brand: nil,
            barcode: nil,
            description: "Fresh banana, medium size",
            servingSize: 1,
            servingUnit: "medium",
            servingSizeGrams: 118,
            calories: 105,
            protein: 1.3,
            carbohydrates: 27,
            fat: 0.4,
            fiber: 3.1,
            sugar: 14.4,
            saturatedFat: 0.1,
            unsaturatedFat: 0.1,
            transFat: 0,
            sodium: 1,
            potassium: 422,
            calcium: 6,
            iron: 0.3,
            vitaminA: 3,
            vitaminC: 10.3,
            vitaminD: 0,
            vitaminE: 0.1,
            vitaminK: 0.5,
            vitaminB1: 0.04,
            vitaminB2: 0.09,
            vitaminB3: 0.8,
            vitaminB6: 0.4,
            vitaminB12: 0,
            folate: 20,
            magnesium: 32,
            phosphorus: 26,
            zinc: 0.2,
            category: .fruits,
            isVerified: true,
            source: .usda,
            createdAt: Date(),
            updatedAt: Date(),
            createdBy: nil
        ),
        Food(
            id: UUID(),
            name: "Chicken Breast",
            brand: nil,
            barcode: nil,
            description: "Skinless, boneless chicken breast, cooked",
            servingSize: 100,
            servingUnit: "grams",
            servingSizeGrams: 100,
            calories: 165,
            protein: 31,
            carbohydrates: 0,
            fat: 3.6,
            fiber: 0,
            sugar: 0,
            saturatedFat: 1.0,
            unsaturatedFat: 2.6,
            transFat: 0,
            sodium: 74,
            potassium: 256,
            calcium: 15,
            iron: 1.04,
            vitaminA: 6,
            vitaminC: 0,
            vitaminD: 0.2,
            vitaminE: 0.27,
            vitaminK: 0.4,
            vitaminB1: 0.07,
            vitaminB2: 0.1,
            vitaminB3: 13.7,
            vitaminB6: 0.6,
            vitaminB12: 0.3,
            folate: 4,
            magnesium: 29,
            phosphorus: 228,
            zinc: 1.0,
            category: .poultry,
            isVerified: true,
            source: .usda,
            createdAt: Date(),
            updatedAt: Date(),
            createdBy: nil
        )
    ]
}