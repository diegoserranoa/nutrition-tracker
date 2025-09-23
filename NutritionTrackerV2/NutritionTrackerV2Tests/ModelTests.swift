//
//  ModelTests.swift
//  NutritionTrackerV2Tests
//
//  Comprehensive tests for core data models
//

import XCTest
@testable import NutritionTrackerV2

@MainActor
class ModelTests: XCTestCase {

    // MARK: - Food Model Tests

    func testFoodInitialization() async throws {
        let food = Food.sampleFoods[0]

        XCTAssertNotNil(food.id, "Food should have an ID")
        XCTAssertFalse(food.name.isEmpty, "Food should have a name")
        XCTAssertGreaterThan(food.calories, 0, "Food should have calories")
        XCTAssertGreaterThanOrEqual(food.protein, 0, "Protein should not be negative")
        XCTAssertGreaterThanOrEqual(food.carbohydrates, 0, "Carbohydrates should not be negative")
        XCTAssertGreaterThanOrEqual(food.fat, 0, "Fat should not be negative")
    }

    func testFoodCodable() async throws {
        let food = Food.sampleFoods[0]

        // Test encoding
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(food)
        XCTAssertGreaterThan(data.count, 0, "Encoded data should not be empty")

        // Test decoding
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedFood = try decoder.decode(Food.self, from: data)

        XCTAssertEqual(food.id, decodedFood.id, "IDs should match")
        XCTAssertEqual(food.name, decodedFood.name, "Names should match")
        XCTAssertEqual(food.calories, decodedFood.calories, "Calories should match")
        XCTAssertEqual(food.protein, decodedFood.protein, "Protein should match")
    }

    func testFoodScaling() async throws {
        let food = Food.sampleFoods[0] // Banana
        let scaledFood = food.scaled(by: 2.0)

        XCTAssertEqual(scaledFood.calories, food.calories * 2, "Calories should be doubled")
        XCTAssertEqual(scaledFood.protein, food.protein * 2, "Protein should be doubled")
        XCTAssertEqual(scaledFood.carbohydrates, food.carbohydrates * 2, "Carbs should be doubled")
        XCTAssertEqual(scaledFood.fat, food.fat * 2, "Fat should be doubled")

        // Test that non-nutritional fields remain the same
        XCTAssertEqual(scaledFood.id, food.id, "ID should remain the same")
        XCTAssertEqual(scaledFood.name, food.name, "Name should remain the same")
        XCTAssertEqual(scaledFood.source, food.source, "Source should remain the same")
    }

    func testFoodScalingToGrams() async throws {
        let food = Food.sampleFoods[0] // Banana (118g serving size)
        let scaledFood = food.scaledToGrams(59) // Half the serving size

        XCTAssertNotNil(scaledFood, "Should be able to scale to grams")
        XCTAssertEqual(scaledFood!.calories, food.calories / 2, accuracy: 0.1, "Calories should be halved")
        XCTAssertEqual(scaledFood!.protein, food.protein / 2, accuracy: 0.1, "Protein should be halved")
    }

    func testFoodMacronutrientBreakdown() async throws {
        let food = Food.sampleFoods[1] // Chicken breast
        let breakdown = food.macronutrientBreakdown

        XCTAssertGreaterThan(breakdown.protein, 0, "Protein percentage should be positive")
        XCTAssertGreaterThanOrEqual(breakdown.carbs, 0, "Carbs percentage should not be negative")
        XCTAssertGreaterThan(breakdown.fat, 0, "Fat percentage should be positive")

        let total = breakdown.protein + breakdown.carbs + breakdown.fat
        XCTAssertEqual(total, 100, accuracy: 1.0, "Total should be approximately 100%")
    }

    func testFoodValidation() async throws {
        let validFood = Food.sampleFoods[0]
        XCTAssertTrue(validFood.hasCompleteBasicNutrition, "Sample food should have complete nutrition")
        XCTAssertTrue(validFood.hasConsistentMacronutrients, "Sample food should have consistent macros")
    }

    // MARK: - FoodLog Model Tests

    func testFoodLogInitialization() async throws {
        let foodLog = FoodLog.sampleLogs[0]

        XCTAssertNotNil(foodLog.id, "FoodLog should have an ID")
        XCTAssertFalse(foodLog.userId.uuidString.isEmpty, "FoodLog should have a user ID")
        XCTAssertFalse(foodLog.foodId.uuidString.isEmpty, "FoodLog should have a food ID")
        XCTAssertGreaterThan(foodLog.quantity, 0, "Quantity should be positive")
        XCTAssertFalse(foodLog.unit.isEmpty, "Unit should not be empty")
    }

    func testFoodLogCodable() async throws {
        let foodLog = FoodLog.sampleLogs[0]

        // Test encoding
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(foodLog)
        XCTAssertGreaterThan(data.count, 0, "Encoded data should not be empty")

        // Test decoding
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedLog = try decoder.decode(FoodLog.self, from: data)

        XCTAssertEqual(foodLog.id, decodedLog.id, "IDs should match")
        XCTAssertEqual(foodLog.quantity, decodedLog.quantity, "Quantities should match")
        XCTAssertEqual(foodLog.mealType, decodedLog.mealType, "Meal types should match")
    }

    func testFoodLogFactory() async throws {
        let food = Food.sampleFoods[0]
        let userId = UUID()

        let foodLog = FoodLog.create(
            userId: userId,
            food: food,
            quantity: 1.5,
            unit: "servings",
            mealType: .breakfast
        )

        XCTAssertEqual(foodLog.userId, userId, "User ID should match")
        XCTAssertEqual(foodLog.foodId, food.id, "Food ID should match")
        XCTAssertEqual(foodLog.quantity, 1.5, "Quantity should match")
        XCTAssertEqual(foodLog.unit, "servings", "Unit should match")
        XCTAssertEqual(foodLog.mealType, .breakfast, "Meal type should match")
        XCTAssertEqual(foodLog.syncStatus, .pending, "Should start as pending sync")
        XCTAssertFalse(foodLog.isDeleted, "Should not be deleted initially")
    }

    func testFoodLogMutations() async throws {
        let originalLog = FoodLog.sampleLogs[0]
        let updatedLog = originalLog.updated(quantity: 2.0, mealType: .lunch)

        XCTAssertEqual(updatedLog.id, originalLog.id, "ID should remain the same")
        XCTAssertEqual(updatedLog.quantity, 2.0, "Quantity should be updated")
        XCTAssertEqual(updatedLog.mealType, .lunch, "Meal type should be updated")
        XCTAssertEqual(updatedLog.syncStatus, .pending, "Should be marked as pending sync")
        XCTAssertNotEqual(updatedLog.updatedAt, originalLog.updatedAt, "Updated time should change")

        let deletedLog = originalLog.markDeleted()
        XCTAssertTrue(deletedLog.isDeleted, "Should be marked as deleted")
        XCTAssertEqual(deletedLog.syncStatus, .pending, "Should be marked as pending sync")
    }

    func testFoodLogScaledNutrition() async throws {
        let foodLog = FoodLog.sampleLogs[0]
        let scaledNutrition = foodLog.scaledNutrition()

        XCTAssertNotNil(scaledNutrition, "Should be able to calculate scaled nutrition")
        XCTAssertGreaterThan(scaledNutrition!.calories, 0, "Scaled calories should be positive")

        let scaledCalories = foodLog.scaledCalories
        XCTAssertNotNil(scaledCalories, "Should be able to get scaled calories")
        XCTAssertEqual(scaledCalories!, scaledNutrition!.calories, "Scaled calories should match")
    }

    func testFoodLogValidation() async throws {
        let validLog = FoodLog.sampleLogs[0]
        XCTAssertTrue(validLog.isValid, "Sample food log should be valid")

        let syncedLog = FoodLog.sampleLogs[0]
        XCTAssertFalse(syncedLog.needsSync, "Synced log should not need sync")

        let pendingLog = FoodLog.create(
            userId: UUID(),
            food: Food.sampleFoods[0],
            quantity: 1,
            unit: "serving",
            mealType: .breakfast
        )
        XCTAssertTrue(pendingLog.needsSync, "Pending log should need sync")
    }

    // MARK: - Profile Model Tests

    func testProfileInitialization() async throws {
        let profile = Profile.sampleProfile

        XCTAssertNotNil(profile.id, "Profile should have an ID")
        XCTAssertFalse(profile.username.isEmpty, "Profile should have a username")
        XCTAssertFalse(profile.userId.uuidString.isEmpty, "Profile should have a user ID")
    }

    func testProfileCodable() async throws {
        let profile = Profile.sampleProfile

        // Test encoding
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(profile)
        XCTAssertGreaterThan(data.count, 0, "Encoded data should not be empty")

        // Test decoding
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedProfile = try decoder.decode(Profile.self, from: data)

        XCTAssertEqual(profile.id, decodedProfile.id, "IDs should match")
        XCTAssertEqual(profile.username, decodedProfile.username, "Usernames should match")
        XCTAssertEqual(profile.height, decodedProfile.height, "Heights should match")
        XCTAssertEqual(profile.weight, decodedProfile.weight, "Weights should match")
    }

    func testProfileFactory() async throws {
        let userId = UUID()
        let username = "testuser"
        let email = "test@example.com"

        let profile = Profile.createMinimal(userId: userId, username: username, email: email)

        XCTAssertEqual(profile.userId, userId, "User ID should match")
        XCTAssertEqual(profile.username, username, "Username should match")
        XCTAssertEqual(profile.email, email, "Email should match")
        XCTAssertEqual(profile.preferredUnits, .metric, "Should default to metric units")
        XCTAssertFalse(profile.isPublic, "Should default to private")
        XCTAssertTrue(profile.allowDataExport, "Should allow data export by default")
    }

    func testProfileComputedProperties() async throws {
        let profile = Profile.sampleProfile

        XCTAssertNotNil(profile.age, "Should be able to calculate age")
        XCTAssertGreaterThan(profile.age!, 0, "Age should be positive")

        XCTAssertNotNil(profile.bmi, "Should be able to calculate BMI")
        XCTAssertGreaterThan(profile.bmi!, 0, "BMI should be positive")

        XCTAssertNotNil(profile.bmiCategory, "Should have BMI category")

        XCTAssertNotNil(profile.bmr, "Should be able to calculate BMR")
        XCTAssertGreaterThan(profile.bmr!, 0, "BMR should be positive")

        XCTAssertNotNil(profile.tdee, "Should be able to calculate TDEE")
        XCTAssertGreaterThan(profile.tdee!, profile.bmr!, "TDEE should be greater than BMR")

        XCTAssertNotNil(profile.recommendedDailyCalories, "Should have recommended calories")
    }

    func testProfileMutations() async throws {
        let originalProfile = Profile.sampleProfile
        let updatedProfile = originalProfile.updated(
            firstName: "Jane",
            height: 160,
            weight: 65,
            primaryGoal: .loseWeight
        )

        XCTAssertEqual(updatedProfile.id, originalProfile.id, "ID should remain the same")
        XCTAssertEqual(updatedProfile.firstName, "Jane", "First name should be updated")
        XCTAssertEqual(updatedProfile.height, 160, "Height should be updated")
        XCTAssertEqual(updatedProfile.weight, 65, "Weight should be updated")
        XCTAssertEqual(updatedProfile.primaryGoal, .loseWeight, "Goal should be updated")
        XCTAssertNotEqual(updatedProfile.updatedAt, originalProfile.updatedAt, "Updated time should change")

        let nutritionProfile = originalProfile.updatedNutritionGoals(
            calorieGoal: 1800,
            proteinGoal: 120
        )
        XCTAssertEqual(nutritionProfile.dailyCalorieGoal, 1800, "Calorie goal should be updated")
        XCTAssertEqual(nutritionProfile.dailyProteinGoal, 120, "Protein goal should be updated")
    }

    func testProfileValidation() async throws {
        let completeProfile = Profile.sampleProfile
        XCTAssertTrue(completeProfile.hasCompleteBasicInfo, "Sample profile should have complete basic info")
        XCTAssertTrue(completeProfile.hasNutritionGoals, "Sample profile should have nutrition goals")

        let minimalProfile = Profile.createMinimal(userId: UUID(), username: "test")
        XCTAssertFalse(minimalProfile.hasCompleteBasicInfo, "Minimal profile should not have complete basic info")
        XCTAssertFalse(minimalProfile.hasNutritionGoals, "Minimal profile should not have nutrition goals")
    }

    // MARK: - Enum Tests

    func testMealTypeProperties() async throws {
        for mealType in MealType.allCases {
            XCTAssertFalse(mealType.displayName.isEmpty, "Meal type should have display name")
            XCTAssertFalse(mealType.icon.isEmpty, "Meal type should have icon")
            XCTAssertFalse(mealType.color.isEmpty, "Meal type should have color")

            let typicalTime = mealType.typicalTime
            XCTAssertGreaterThanOrEqual(typicalTime.hour, 0, "Hour should be valid")
            XCTAssertLessThan(typicalTime.hour, 24, "Hour should be valid")
            XCTAssertGreaterThanOrEqual(typicalTime.minute, 0, "Minute should be valid")
            XCTAssertLessThan(typicalTime.minute, 60, "Minute should be valid")
        }
    }

    func testFoodCategoryProperties() async throws {
        for category in FoodCategory.allCases {
            XCTAssertFalse(category.displayName.isEmpty, "Category should have display name")
        }
    }

    func testSyncStatusProperties() async throws {
        XCTAssertTrue(SyncStatus.pending.needsSync, "Pending should need sync")
        XCTAssertTrue(SyncStatus.error.needsSync, "Error should need sync")
        XCTAssertFalse(SyncStatus.synced.needsSync, "Synced should not need sync")
        XCTAssertFalse(SyncStatus.conflict.needsSync, "Conflict should not need sync")
    }

    // MARK: - Daily Summary Tests

    func testDailyNutritionSummary() async throws {
        let logs = FoodLog.sampleLogs
        let date = Date()

        let summary = DailyNutritionSummary.from(logs: logs, for: date)

        XCTAssertEqual(summary.date, date, "Date should match")
        XCTAssertGreaterThan(summary.totalCalories, 0, "Total calories should be positive")
        XCTAssertGreaterThan(summary.totalProtein, 0, "Total protein should be positive")
        XCTAssertEqual(summary.logCount, logs.count, "Log count should match")
        XCTAssertGreaterThan(summary.mealBreakdown.count, 0, "Should have meal breakdown")
    }

    // MARK: - Extensions Tests

    func testDoubleFormatting() async throws {
        let calories: Double = 150.5
        XCTAssertEqual(calories.formattedCalories, "151 cal", "Should format calories correctly")

        let grams: Double = 10.25
        XCTAssertEqual(grams.formattedGrams, "10g", "Should format grams correctly")

        let smallGrams: Double = 0.5
        XCTAssertEqual(smallGrams.formattedGrams, "0.5g", "Should format small grams correctly")

        let milligrams: Double = 250.75
        XCTAssertEqual(milligrams.formattedMilligrams, "251mg", "Should format milligrams correctly")
    }

    func testDateExtensions() async throws {
        let now = Date()
        XCTAssertTrue(now.isToday, "Current date should be today")

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        XCTAssertTrue(yesterday.isYesterday, "Yesterday should be yesterday")

        let startOfDay = now.startOfDay
        let endOfDay = now.endOfDay
        XCTAssertLessThan(startOfDay, now, "Start of day should be before now")
        XCTAssertGreaterThan(endOfDay, now, "End of day should be after now")
    }

    func testArrayExtensions() async throws {
        let logs = FoodLog.sampleLogs
        let activeArray = logs.active
        let deletedArray = logs.deleted

        XCTAssertEqual(activeArray.count + deletedArray.count, logs.count, "Active + deleted should equal total")

        let needingSyncArray = logs.needingSync
        let syncedArray = logs.synced

        XCTAssertEqual(needingSyncArray.count + syncedArray.count, logs.count, "Needing sync + synced should equal total")
    }

    // MARK: - Performance Tests

    func testFoodScalingPerformance() async throws {
        let food = Food.sampleFoods[0]

        measure {
            for _ in 0..<1000 {
                let _ = food.scaled(by: 2.0)
            }
        }
    }

    func testJSONEncodingPerformance() async throws {
        let foods = Array(repeating: Food.sampleFoods[0], count: 100)
        let encoder = JSONEncoder()

        measure {
            do {
                let _ = try encoder.encode(foods)
            } catch {
                XCTFail("Encoding failed: \(error)")
            }
        }
    }
}