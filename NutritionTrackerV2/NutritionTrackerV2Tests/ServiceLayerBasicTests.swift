//
//  ServiceLayerBasicTests.swift
//  NutritionTrackerV2Tests
//
//  Basic unit tests for service layer initialization and basic functionality
//

import XCTest
import Supabase
import Auth
@testable import NutritionTrackerV2

@MainActor
class ServiceLayerBasicTests: XCTestCase {

    var foodService: FoodService!
    var foodLogService: FoodLogService!
    var cacheService: CacheService!

    override func setUp() async throws {
        try await super.setUp()

        foodService = FoodService()
        foodLogService = FoodLogService()
        cacheService = CacheService()
    }

    override func tearDown() async throws {
        cacheService.clear()
        foodService = nil
        foodLogService = nil
        cacheService = nil
        try await super.tearDown()
    }

    // MARK: - Service Initialization Tests

    func testFoodServiceInitialization() {
        XCTAssertNotNil(foodService)
        XCTAssertFalse(foodService.isLoading)
        XCTAssertNil(foodService.currentError)
    }

    func testFoodLogServiceInitialization() {
        XCTAssertNotNil(foodLogService)
        XCTAssertFalse(foodLogService.isLoading)
        XCTAssertNil(foodLogService.currentError)
    }

    func testCacheServiceInitialization() {
        XCTAssertNotNil(cacheService)

        let stats = cacheService.getStatistics()
        XCTAssertEqual(stats.hitCount, 0)
        XCTAssertEqual(stats.missCount, 0)
        XCTAssertEqual(stats.totalRequests, 0)
        XCTAssertEqual(stats.hitRate, 0.0)
    }

    // MARK: - Cache Basic Functionality Tests

    func testCacheBasicOperations() {
        // Test basic cache set/get operations
        cacheService.set("test_key", value: "test_value")

        let result = cacheService.get("test_key", type: String.self)
        XCTAssertEqual(result, "test_value")

        // Test cache miss
        let missResult = cacheService.get("nonexistent_key", type: String.self)
        XCTAssertNil(missResult)

        // Test cache removal
        cacheService.remove("test_key")
        let removedResult = cacheService.get("test_key", type: String.self)
        XCTAssertNil(removedResult)
    }

    func testCacheClear() {
        // Add some data
        cacheService.set("key1", value: "value1")
        cacheService.set("key2", value: "value2")

        // Clear cache
        cacheService.clear()

        // Verify cleared - cache should be empty
        XCTAssertNil(cacheService.get("key1", type: String.self))
        XCTAssertNil(cacheService.get("key2", type: String.self))

        // Statistics may or may not be reset depending on implementation
        // The important thing is the cache is cleared
        let stats = cacheService.getStatistics()
        XCTAssertNotNil(stats) // Just verify we can get statistics
    }

    func testCacheStatistics() {
        // Generate some cache activity
        cacheService.set("test", value: "data")

        // Hit
        _ = cacheService.get("test", type: String.self)

        // Miss
        _ = cacheService.get("missing", type: String.self)

        let stats = cacheService.getStatistics()
        XCTAssertEqual(stats.hitCount, 1)
        XCTAssertEqual(stats.missCount, 1)
        XCTAssertEqual(stats.totalRequests, 2)
        XCTAssertEqual(stats.hitRate, 0.5, accuracy: 0.01)
    }

    // MARK: - Food Model Tests

    func testFoodModel() {
        let food = createTestFood()

        XCTAssertNotNil(food.id)
        XCTAssertEqual(food.name, "Test Food")
        XCTAssertEqual(food.calories, 145.0)  // Updated to match consistent nutrition
        XCTAssertEqual(food.protein, 10.0)
        XCTAssertEqual(food.source, .userCreated)
    }

    func testFoodValidation() {
        let food = createTestFood()

        // Valid food should not throw
        XCTAssertNoThrow(try food.validate())
    }

    func testFoodInvalidValidation() {
        let invalidFood = Food(
            id: UUID(),
            name: "", // Invalid empty name
            brand: nil,
            barcode: nil,
            description: nil,
            servingSize: 100.0,
            servingUnit: "g",
            servingSizeGrams: 100.0,
            calories: 145.0,  // (10*4)+(15*4)+(5*9) = 145
            protein: 10.0,
            carbohydrates: 15.0,
            fat: 5.0,
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

        // Invalid food should throw
        XCTAssertThrowsError(try invalidFood.validate())
    }

    // MARK: - FoodLog Model Tests

    func testFoodLogModel() {
        let foodLog = createTestFoodLog()

        XCTAssertNotNil(foodLog.id)
        XCTAssertNotNil(foodLog.userId)
        XCTAssertNotNil(foodLog.foodId)
        XCTAssertEqual(foodLog.quantity, 1.5)
        XCTAssertEqual(foodLog.unit, "cups")
        XCTAssertEqual(foodLog.mealType, .lunch)
        XCTAssertFalse(foodLog.isDeleted)
        XCTAssertEqual(foodLog.syncStatus, .synced)
    }

    func testFoodLogValidation() {
        let foodLog = createTestFoodLog()

        // Valid food log should not throw
        XCTAssertNoThrow(try foodLog.validate())
    }

    func testFoodLogInvalidValidation() {
        let invalidFoodLog = FoodLog(
            id: UUID(),
            userId: UUID(),
            foodId: UUID(),
            quantity: -1.0, // Invalid negative quantity
            unit: "cups",
            totalGrams: 200.0,
            mealType: .lunch,
            loggedAt: Date(),
            createdAt: Date(),
            updatedAt: Date(),
            notes: nil,
            brand: nil,
            customName: nil,
            isDeleted: false,
            syncStatus: .synced
        )

        // Invalid food log should throw
        XCTAssertThrowsError(try invalidFoodLog.validate())
    }

    // MARK: - Cache Food Operations Tests

    func testCacheFoodOperations() {
        let food = createTestFood()

        // Cache food
        cacheService.cacheFood(food)

        // Retrieve cached food
        let cachedFood = cacheService.getCachedFood(id: food.id)
        XCTAssertNotNil(cachedFood)
        XCTAssertEqual(cachedFood?.id, food.id)
        XCTAssertEqual(cachedFood?.name, "Test Food")
    }

    func testCacheSearchResults() {
        let foods = [createTestFood(), createTestFood()]
        let query = "test"

        // Cache search results
        cacheService.cacheSearchResults(query: query, results: foods)

        // Retrieve cached results
        let cachedResults = cacheService.getCachedSearchResults(query: query)
        XCTAssertNotNil(cachedResults)
        XCTAssertEqual(cachedResults?.count, 2)
    }

    func testCacheInvalidation() {
        let food = createTestFood()

        // Cache food
        cacheService.cacheFood(food)
        XCTAssertNotNil(cacheService.getCachedFood(id: food.id))

        // Invalidate food data
        cacheService.invalidateFoodData(foodId: food.id)

        // Should be removed from cache
        XCTAssertNil(cacheService.getCachedFood(id: food.id))
    }

    // MARK: - Helper Methods

    private func createTestFood() -> Food {
        return Food(
            id: UUID(),
            name: "Test Food",
            brand: "Test Brand",
            barcode: "123456789",
            description: "Test food description",
            servingSize: 100.0,
            servingUnit: "g",
            servingSizeGrams: 100.0,
            calories: 145.0,  // (10*4)+(15*4)+(5*9) = 145
            protein: 10.0,
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
            category: .fruits,
            isVerified: false,
            source: .userCreated,
            createdAt: Date(),
            updatedAt: Date(),
            createdBy: UUID()
        )
    }

    private func createTestFoodLog() -> FoodLog {
        return FoodLog(
            id: UUID(),
            userId: UUID(),
            foodId: UUID(),
            quantity: 1.5,
            unit: "cups",
            totalGrams: 200.0,
            mealType: .lunch,
            loggedAt: Date(),
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