//
//  ServiceErrorHandlingTests.swift
//  NutritionTrackerV2Tests
//
//  Comprehensive error handling and edge case tests for data service layer
//

import XCTest
import Supabase
import Auth
@testable import NutritionTrackerV2

@MainActor
class ServiceErrorHandlingTests: XCTestCase {

    var foodService: FoodService!
    var foodLogService: FoodLogService!
    var testUserId: UUID!

    override func setUp() async throws {
        try await super.setUp()

        // Use default services for simplified testing
        foodService = FoodService()
        foodLogService = FoodLogService()
        testUserId = UUID()
    }

    override func tearDown() async throws {
        foodService = nil
        foodLogService = nil
        testUserId = nil
        try await super.tearDown()
    }

    // MARK: - Service Initialization Tests

    func testServiceInitialization() {
        XCTAssertNotNil(foodService)
        XCTAssertNotNil(foodLogService)
        XCTAssertFalse(foodService.isLoading)
        XCTAssertFalse(foodLogService.isLoading)
        XCTAssertNil(foodService.currentError)
        XCTAssertNil(foodLogService.currentError)
    }

    // MARK: - Validation Error Handling Tests

    func testFoodValidationErrors() {
        // Test invalid food models
        let invalidFoods = [
            createInvalidFood(name: ""),  // Empty name
            createInvalidFood(name: "Valid Name", calories: -10),  // Negative calories
            createInvalidFood(name: "Valid Name", protein: -5),    // Negative protein
            createInvalidFood(name: "Valid Name", servingSize: 0)  // Zero serving size
        ]

        for invalidFood in invalidFoods {
            XCTAssertThrowsError(try invalidFood.validate()) { error in
                XCTAssertTrue(error is DataServiceError)
                if case let DataServiceError.validationFailed(errors) = error {
                    XCTAssertFalse(errors.isEmpty)
                } else {
                    XCTFail("Expected validation failed error")
                }
            }
        }
    }

    func testFoodLogValidationErrors() {
        // Test invalid food log models
        let invalidFoodLogs = [
            createInvalidFoodLog(quantity: -1.0),  // Negative quantity
            createInvalidFoodLog(quantity: 1.0, unit: ""),  // Empty unit
            createInvalidFoodLog(quantity: 1.0, loggedAt: Date().addingTimeInterval(86400))  // Future date
        ]

        for invalidFoodLog in invalidFoodLogs {
            XCTAssertThrowsError(try invalidFoodLog.validate()) { error in
                XCTAssertTrue(error is DataServiceError)
                if case let DataServiceError.validationFailed(errors) = error {
                    XCTAssertFalse(errors.isEmpty)
                } else {
                    XCTFail("Expected validation failed error")
                }
            }
        }
    }

    // MARK: - Data Consistency Tests

    func testFoodNutritionalConsistency() {
        // Test food with inconsistent macronutrient calories
        let inconsistentFood = Food(
            id: UUID(),
            name: "Inconsistent Food",
            brand: nil,
            barcode: nil,
            description: nil,
            servingSize: 100.0,
            servingUnit: "g",
            servingSizeGrams: 100.0,
            calories: 100.0,  // Claims 100 calories
            protein: 25.0,    // But 25g protein = 100 calories alone
            carbohydrates: 25.0,  // Plus 25g carbs = 100 more calories
            fat: 11.0,        // Plus 11g fat = 99 more calories (total would be ~299)
            fiber: nil,
            sugar: nil,
            saturatedFat: nil,
            unsaturatedFat: nil,
            transFat: nil,
            sodium: nil,
            potassium: nil,
            calcium: nil,
            iron: nil,
            vitaminA: nil,
            vitaminC: nil,
            vitaminD: nil,
            vitaminE: nil,
            vitaminK: nil,
            vitaminB1: nil,
            vitaminB2: nil,
            vitaminB3: nil,
            vitaminB6: nil,
            vitaminB12: nil,
            folate: nil,
            magnesium: nil,
            phosphorus: nil,
            zinc: nil,
            category: nil,
            isVerified: false,
            source: .userCreated,
            createdAt: Date(),
            updatedAt: Date(),
            createdBy: nil
        )

        XCTAssertFalse(inconsistentFood.hasConsistentMacronutrients)
        XCTAssertThrowsError(try inconsistentFood.validate())
    }

    // MARK: - Edge Case Tests

    func testFoodEdgeCases() {
        // Test food with zero values (0 calories with 0 macros is consistent)
        let zeroCalorieFood = Food(
            id: UUID(),
            name: "Zero Calorie",
            brand: "Test Brand",
            barcode: nil,
            description: nil,
            servingSize: 100.0,
            servingUnit: "g",
            servingSizeGrams: 100.0,
            calories: 0.0,
            protein: 0.0,
            carbohydrates: 0.0,
            fat: 0.0,
            fiber: nil,
            sugar: nil,
            saturatedFat: nil,
            unsaturatedFat: nil,
            transFat: nil,
            sodium: nil,
            potassium: nil,
            calcium: nil,
            iron: nil,
            vitaminA: nil,
            vitaminC: nil,
            vitaminD: nil,
            vitaminE: nil,
            vitaminK: nil,
            vitaminB1: nil,
            vitaminB2: nil,
            vitaminB3: nil,
            vitaminB6: nil,
            vitaminB12: nil,
            folate: nil,
            magnesium: nil,
            phosphorus: nil,
            zinc: nil,
            category: nil,
            isVerified: false,
            source: .userCreated,
            createdAt: Date(),
            updatedAt: Date(),
            createdBy: nil
        )
        XCTAssertNoThrow(try zeroCalorieFood.validate())
        XCTAssertTrue(zeroCalorieFood.hasCompleteBasicNutrition)

        // Test food scaling edge cases
        let originalFood = createMockFood(name: "Test Food")

        // Scale by zero
        let zeroScaled = originalFood.scaled(by: 0.0)
        XCTAssertEqual(zeroScaled.calories, 0.0)
        XCTAssertEqual(zeroScaled.protein, 0.0)

        // Scale by very large number
        let largeScaled = originalFood.scaled(by: 1000.0)
        XCTAssertEqual(largeScaled.calories, originalFood.calories * 1000.0)
    }

    func testFoodLogEdgeCases() {
        // Test food log at boundary dates
        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date())!
        let almostOneYearAgo = oneYearAgo.addingTimeInterval(86400) // One day less than a year ago

        let validOldLog = createMockFoodLog(loggedAt: almostOneYearAgo)
        XCTAssertNoThrow(try validOldLog.validate())

        let tooOldLog = createMockFoodLog(loggedAt: oneYearAgo.addingTimeInterval(-86400))
        XCTAssertThrowsError(try tooOldLog.validate())
    }

    // MARK: - Cache Statistics Tests

    func testCacheStatisticsEdgeCases() {
        let stats = foodService.getCacheStatistics()

        // Initial state should have valid statistics
        XCTAssertGreaterThanOrEqual(stats.hitCount, 0)
        XCTAssertGreaterThanOrEqual(stats.missCount, 0)
        XCTAssertGreaterThanOrEqual(stats.totalRequests, 0)
        XCTAssertGreaterThanOrEqual(stats.hitRate, 0.0)
        XCTAssertLessThanOrEqual(stats.hitRate, 1.0)

        // Clear cache and verify stats
        foodService.clearCache()
        let clearedStats = foodService.getCacheStatistics()
        XCTAssertNotNil(clearedStats)
    }

    // MARK: - Search Parameter Tests

    func testSearchParameterEdgeCases() {
        // Test FoodSearchParameters edge cases
        let emptyQueryParams = FoodSearchParameters(query: "", limit: 0, offset: -1)
        XCTAssertNotNil(emptyQueryParams)

        let extremeParams = FoodSearchParameters(query: "a", limit: 10000, offset: 999999)
        XCTAssertNotNil(extremeParams)

        // Test FoodLogSearchParameters edge cases
        let futureDate = Date().addingTimeInterval(86400 * 365) // One year in future
        let pastDate = Date().addingTimeInterval(-86400 * 365 * 10) // 10 years ago

        let extremeLogParams = FoodLogSearchParameters(
            userId: testUserId,
            startDate: pastDate,
            endDate: futureDate,
            limit: 0,
            offset: -100
        )
        XCTAssertNotNil(extremeLogParams)
    }

    // MARK: - Helper Methods

    private func createInvalidFood(
        name: String = "Valid Name",
        calories: Double = 100.0,
        protein: Double = 10.0,
        servingSize: Double = 100.0
    ) -> Food {
        return Food(
            id: UUID(),
            name: name,
            brand: "Test Brand",
            barcode: "123456789",
            description: "Test food description",
            servingSize: servingSize,
            servingUnit: "g",
            servingSizeGrams: 100.0,
            calories: calories,
            protein: protein,
            carbohydrates: 15.0,
            fat: 5.0,
            fiber: 2.0,
            sugar: 8.0,
            saturatedFat: 1.5,
            unsaturatedFat: 3.5,
            transFat: 0.0,
            sodium: 50.0,
            potassium: 200.0,
            calcium: 100.0,
            iron: 2.0,
            vitaminA: 500.0,
            vitaminC: 10.0,
            vitaminD: 2.0,
            vitaminE: 1.0,
            vitaminK: 10.0,
            vitaminB1: 0.1,
            vitaminB2: 0.2,
            vitaminB3: 2.0,
            vitaminB6: 0.2,
            vitaminB12: 1.0,
            folate: 50.0,
            magnesium: 25.0,
            phosphorus: 100.0,
            zinc: 1.0,
            category: .protein,
            isVerified: false,
            source: .userCreated,
            createdAt: Date(),
            updatedAt: Date(),
            createdBy: UUID()
        )
    }

    private func createInvalidFoodLog(
        quantity: Double = 1.5,
        unit: String = "cups",
        loggedAt: Date = Date()
    ) -> FoodLog {
        return FoodLog(
            id: UUID(),
            userId: testUserId,
            foodId: UUID(),
            quantity: quantity,
            unit: unit,
            totalGrams: 200.0,
            mealType: .lunch,
            loggedAt: loggedAt,
            createdAt: Date(),
            updatedAt: Date(),
            notes: "Test notes",
            brand: nil,
            customName: nil,
            isDeleted: false,
            syncStatus: .synced
        )
    }

    private func createMockFood(
        name: String,
        calories: Double = 145.0,  // Default to nutritionally consistent calories
        protein: Double = 10.0
    ) -> Food {
        // Calculate consistent calories if using default values
        let carbs = 15.0
        let fat = 5.0
        let calculatedCalories = calories == 145.0 ? (protein * 4) + (carbs * 4) + (fat * 9) : calories

        return Food(
            id: UUID(),
            name: name,
            brand: "Test Brand",
            barcode: "123456789",
            description: "Test food description",
            servingSize: 100.0,
            servingUnit: "g",
            servingSizeGrams: 100.0,
            calories: calculatedCalories,
            protein: protein,
            carbohydrates: carbs,
            fat: fat,
            fiber: 2.0,
            sugar: 8.0,
            saturatedFat: 1.5,
            unsaturatedFat: 3.5,
            transFat: 0.0,
            sodium: 50.0,
            potassium: 200.0,
            calcium: 100.0,
            iron: 2.0,
            vitaminA: 500.0,
            vitaminC: 10.0,
            vitaminD: 2.0,
            vitaminE: 1.0,
            vitaminK: 10.0,
            vitaminB1: 0.1,
            vitaminB2: 0.2,
            vitaminB3: 2.0,
            vitaminB6: 0.2,
            vitaminB12: 1.0,
            folate: 50.0,
            magnesium: 25.0,
            phosphorus: 100.0,
            zinc: 1.0,
            category: .protein,
            isVerified: false,
            source: .userCreated,
            createdAt: Date(),
            updatedAt: Date(),
            createdBy: UUID()
        )
    }

    private func createMockFoodLog(loggedAt: Date = Date()) -> FoodLog {
        return FoodLog(
            id: UUID(),
            userId: testUserId,
            foodId: UUID(),
            quantity: 1.5,
            unit: "cups",
            totalGrams: 200.0,
            mealType: .lunch,
            loggedAt: loggedAt,
            createdAt: Date(),
            updatedAt: Date(),
            notes: "Test notes",
            brand: nil,
            customName: nil,
            isDeleted: false,
            syncStatus: .synced
        )
    }
}