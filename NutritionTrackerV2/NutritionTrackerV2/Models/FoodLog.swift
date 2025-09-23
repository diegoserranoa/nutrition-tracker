//
//  FoodLog.swift
//  NutritionTrackerV2
//
//  Core data model for food consumption tracking and logging
//

import Foundation

// MARK: - FoodLog Model

struct FoodLog: Codable, Identifiable, Hashable, Syncable, SoftDeletable, Timestamped {
    let id: UUID
    let userId: UUID
    let foodId: UUID

    // Consumption details
    let quantity: Double
    let unit: String // The unit for the quantity (e.g., "cups", "pieces", "grams")
    let totalGrams: Double? // Actual weight consumed in grams

    // Meal information
    let mealType: MealType
    let loggedAt: Date // When the food was consumed
    let createdAt: Date // When the log entry was created
    let updatedAt: Date

    // Optional fields
    let notes: String?
    let brand: String? // Brand override if different from food item
    let customName: String? // Custom name override

    // Metadata
    let isDeleted: Bool
    let syncStatus: SyncStatus

    // Related food item (loaded separately, not stored in DB)
    var food: Food?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case foodId = "food_id"
        case quantity
        case unit
        case totalGrams = "total_grams"
        case mealType = "meal_type"
        case loggedAt = "logged_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case notes
        case brand
        case customName = "custom_name"
        case isDeleted = "is_deleted"
        case syncStatus = "sync_status"
    }
}

// Note: MealType and SyncStatus are defined in Models.swift

// MARK: - FoodLog Extensions

extension FoodLog {

    // MARK: - Computed Properties

    /// Display name for the logged food item
    var displayName: String {
        if let customName = customName, !customName.isEmpty {
            return customName
        }
        if let food = food {
            if let brand = brand ?? food.brand, !brand.isEmpty {
                return "\(brand) \(food.name)"
            }
            return food.name
        }
        return "Unknown Food"
    }

    /// Quantity description with unit
    var quantityDescription: String {
        "\(quantity.formatted(.number.precision(.fractionLength(0...2)))) \(unit)"
    }

    /// Total grams description
    var gramsDescription: String? {
        guard let totalGrams = totalGrams else { return nil }
        return "\(totalGrams.formatted(.number.precision(.fractionLength(0...1))))g"
    }

    /// Formatted logged time
    var loggedTimeDescription: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: loggedAt)
    }

    /// Formatted logged date
    var loggedDateDescription: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: loggedAt)
    }

    /// Whether this log entry is from today
    var isToday: Bool {
        Calendar.current.isDateInToday(loggedAt)
    }

    /// Whether this log entry is from yesterday
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(loggedAt)
    }

    // MARK: - Nutritional Calculations

    /// Calculate scaled nutritional values based on the logged quantity
    /// - Returns: A Food object with nutritional values scaled to the logged quantity
    func scaledNutrition() -> Food? {
        guard let food = food else { return nil }

        // If we have total grams, use that for scaling
        if let totalGrams = totalGrams {
            return food.scaledToGrams(totalGrams)
        }

        // Otherwise, try to calculate based on quantity and food serving size
        // This assumes the unit matches the food's serving unit
        let multiplier = quantity / food.servingSize
        return food.scaled(by: multiplier)
    }

    /// Get scaled calories for this log entry
    var scaledCalories: Double? {
        return scaledNutrition()?.calories
    }

    /// Get scaled macronutrients for this log entry
    var scaledMacros: (protein: Double, carbs: Double, fat: Double)? {
        guard let nutrition = scaledNutrition() else { return nil }
        return (
            protein: nutrition.protein,
            carbs: nutrition.carbohydrates,
            fat: nutrition.fat
        )
    }

    // MARK: - Validation

    /// Validates that the log entry has complete required information
    var isValid: Bool {
        return !userId.uuidString.isEmpty &&
               !foodId.uuidString.isEmpty &&
               quantity > 0 &&
               !unit.isEmpty
    }

    /// Whether this log entry needs to be synced
    var needsSync: Bool {
        return syncStatus == .pending || syncStatus == .error
    }

    // MARK: - Factory Methods

    /// Create a new food log entry
    /// - Parameters:
    ///   - userId: The user ID
    ///   - food: The food item being logged
    ///   - quantity: The quantity consumed
    ///   - unit: The unit of measurement
    ///   - mealType: The meal type
    ///   - loggedAt: When the food was consumed (defaults to now)
    ///   - totalGrams: Optional total weight in grams
    ///   - notes: Optional notes
    /// - Returns: A new FoodLog instance
    static func create(
        userId: UUID,
        food: Food,
        quantity: Double,
        unit: String,
        mealType: MealType,
        loggedAt: Date = Date(),
        totalGrams: Double? = nil,
        notes: String? = nil
    ) -> FoodLog {
        let now = Date()
        return FoodLog(
            id: UUID(),
            userId: userId,
            foodId: food.id,
            quantity: quantity,
            unit: unit,
            totalGrams: totalGrams,
            mealType: mealType,
            loggedAt: loggedAt,
            createdAt: now,
            updatedAt: now,
            notes: notes,
            brand: nil,
            customName: nil,
            isDeleted: false,
            syncStatus: .pending,
            food: food
        )
    }

    // MARK: - Mutations

    /// Update the food log with new values
    /// - Parameters:
    ///   - quantity: New quantity
    ///   - unit: New unit
    ///   - mealType: New meal type
    ///   - totalGrams: New total grams
    ///   - notes: New notes
    /// - Returns: Updated FoodLog instance
    func updated(
        quantity: Double? = nil,
        unit: String? = nil,
        mealType: MealType? = nil,
        totalGrams: Double? = nil,
        notes: String? = nil
    ) -> FoodLog {
        return FoodLog(
            id: self.id,
            userId: self.userId,
            foodId: self.foodId,
            quantity: quantity ?? self.quantity,
            unit: unit ?? self.unit,
            totalGrams: totalGrams ?? self.totalGrams,
            mealType: mealType ?? self.mealType,
            loggedAt: self.loggedAt,
            createdAt: self.createdAt,
            updatedAt: Date(),
            notes: notes ?? self.notes,
            brand: self.brand,
            customName: self.customName,
            isDeleted: self.isDeleted,
            syncStatus: .pending,
            food: self.food
        )
    }

    /// Mark the food log as deleted
    /// - Returns: Updated FoodLog instance marked as deleted
    func markDeleted() -> FoodLog {
        return FoodLog(
            id: self.id,
            userId: self.userId,
            foodId: self.foodId,
            quantity: self.quantity,
            unit: self.unit,
            totalGrams: self.totalGrams,
            mealType: self.mealType,
            loggedAt: self.loggedAt,
            createdAt: self.createdAt,
            updatedAt: Date(),
            notes: self.notes,
            brand: self.brand,
            customName: self.customName,
            isDeleted: true,
            syncStatus: .pending,
            food: self.food
        )
    }
}

// MARK: - Daily Summary

struct DailyNutritionSummary: Codable {
    let date: Date
    let totalCalories: Double
    let totalProtein: Double
    let totalCarbohydrates: Double
    let totalFat: Double
    let totalFiber: Double?
    let totalSodium: Double?
    let mealBreakdown: [MealType: MealNutritionSummary]
    let logCount: Int

    /// Calculate summary from an array of food logs
    /// - Parameters:
    ///   - logs: Array of FoodLog entries for the day
    ///   - date: The date for this summary
    /// - Returns: DailyNutritionSummary
    static func from(logs: [FoodLog], for date: Date) -> DailyNutritionSummary {
        var totalCalories: Double = 0
        var totalProtein: Double = 0
        var totalCarbohydrates: Double = 0
        var totalFat: Double = 0
        var totalFiber: Double = 0
        var totalSodium: Double = 0
        var mealBreakdown: [MealType: MealNutritionSummary] = [:]

        for log in logs {
            guard let nutrition = log.scaledNutrition() else { continue }

            totalCalories += nutrition.calories
            totalProtein += nutrition.protein
            totalCarbohydrates += nutrition.carbohydrates
            totalFat += nutrition.fat
            totalFiber += nutrition.fiber ?? 0
            totalSodium += nutrition.sodium ?? 0

            // Update meal breakdown
            if var mealSummary = mealBreakdown[log.mealType] {
                mealSummary.addNutrition(from: nutrition)
                mealBreakdown[log.mealType] = mealSummary
            } else {
                mealBreakdown[log.mealType] = MealNutritionSummary.from(nutrition: nutrition, mealType: log.mealType)
            }
        }

        return DailyNutritionSummary(
            date: date,
            totalCalories: totalCalories,
            totalProtein: totalProtein,
            totalCarbohydrates: totalCarbohydrates,
            totalFat: totalFat,
            totalFiber: totalFiber > 0 ? totalFiber : nil,
            totalSodium: totalSodium > 0 ? totalSodium : nil,
            mealBreakdown: mealBreakdown,
            logCount: logs.count
        )
    }
}

struct MealNutritionSummary: Codable {
    let mealType: MealType
    var calories: Double
    var protein: Double
    var carbohydrates: Double
    var fat: Double
    var logCount: Int

    static func from(nutrition: Food, mealType: MealType) -> MealNutritionSummary {
        return MealNutritionSummary(
            mealType: mealType,
            calories: nutrition.calories,
            protein: nutrition.protein,
            carbohydrates: nutrition.carbohydrates,
            fat: nutrition.fat,
            logCount: 1
        )
    }

    mutating func addNutrition(from nutrition: Food) {
        calories += nutrition.calories
        protein += nutrition.protein
        carbohydrates += nutrition.carbohydrates
        fat += nutrition.fat
        logCount += 1
    }
}

// MARK: - Sample Data

extension FoodLog {

    /// Sample food log data for testing and previews
    static let sampleLogs: [FoodLog] = [
        FoodLog(
            id: UUID(),
            userId: UUID(),
            foodId: Food.sampleFoods[0].id,
            quantity: 1,
            unit: "medium",
            totalGrams: 118,
            mealType: .breakfast,
            loggedAt: Date(),
            createdAt: Date(),
            updatedAt: Date(),
            notes: nil,
            brand: nil,
            customName: nil,
            isDeleted: false,
            syncStatus: .synced,
            food: Food.sampleFoods[0]
        ),
        FoodLog(
            id: UUID(),
            userId: UUID(),
            foodId: Food.sampleFoods[1].id,
            quantity: 150,
            unit: "grams",
            totalGrams: 150,
            mealType: .lunch,
            loggedAt: Calendar.current.date(byAdding: .hour, value: -2, to: Date()) ?? Date(),
            createdAt: Date(),
            updatedAt: Date(),
            notes: "Grilled with herbs",
            brand: nil,
            customName: nil,
            isDeleted: false,
            syncStatus: .synced,
            food: Food.sampleFoods[1]
        )
    ]
}