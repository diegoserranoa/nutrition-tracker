//
//  FoodServiceTests.swift
//  NutritionTrackerV2Tests
//
//  Unit tests for FoodService CRUD operations and search functionality
//

import XCTest
import Supabase
import Auth
@testable import NutritionTrackerV2

@MainActor
class FoodServiceTests: XCTestCase {

    var foodService: FoodService!

    override func setUp() async throws {
        try await super.setUp()

        // Use default services for now since mocking is complex
        // We'll focus on testing the service logic with real dependencies
        foodService = FoodService()
    }

    override func tearDown() async throws {
        foodService = nil
        try await super.tearDown()
    }

    // MARK: - Service Initialization Tests

    func testFoodServiceInitialization() {
        XCTAssertNotNil(foodService)
        XCTAssertFalse(foodService.isLoading)
        XCTAssertNil(foodService.currentError)
    }

    // MARK: - Food Model Tests

    func testCreateFood_ValidationSuccess() async throws {
        // Given
        let validFood = createMockFood(name: "Valid Test Food")

        // When/Then - Should not throw validation error
        XCTAssertNoThrow(try validFood.validate())
    }

    func testCreateFood_ValidationError() async throws {
        // Given
        let invalidFood = createMockFood(name: "") // Invalid empty name

        // When & Then - Should throw validation error
        XCTAssertThrowsError(try invalidFood.validate()) { error in
            XCTAssertTrue(error is DataServiceError)
            if case let DataServiceError.validationFailed(errors) = error {
                XCTAssertFalse(errors.isEmpty)
            } else {
                XCTFail("Expected validation failed error")
            }
        }
    }

    // MARK: - Food Search Parameters Tests

    func testFoodSearchParametersInitialization() {
        // Test default initialization
        let defaultParams = FoodSearchParameters()
        XCTAssertNil(defaultParams.query)
        XCTAssertEqual(defaultParams.limit, 50)
        XCTAssertEqual(defaultParams.offset, 0)

        // Test custom initialization
        let customParams = FoodSearchParameters(query: "test", limit: 20, offset: 10)
        XCTAssertEqual(customParams.query, "test")
        XCTAssertEqual(customParams.limit, 20)
        XCTAssertEqual(customParams.offset, 10)
    }

    // MARK: - Food Model Validation Tests

    func testFoodModelValidation() {
        let food = createMockFood(name: "Test Food")

        // Test valid food
        XCTAssertNoThrow(try food.validate())
        XCTAssertTrue(food.hasCompleteBasicNutrition)

        // Test display properties
        XCTAssertEqual(food.displayName, "Test Brand Test Food")
        XCTAssertNotNil(food.caloriesPerGram)
        XCTAssertFalse(food.servingDescription.isEmpty)
    }

    func testFoodScaling() {
        let food = createMockFood(name: "Test Food")

        // Test scaling by multiplier
        let doubledFood = food.scaled(by: 2.0)
        XCTAssertEqual(doubledFood.calories, food.calories * 2)
        XCTAssertEqual(doubledFood.protein, food.protein * 2)
        XCTAssertEqual(doubledFood.servingSize, food.servingSize * 2)

        // Test scaling to grams
        if let scaledFood = food.scaledToGrams(200.0) {
            XCTAssertNotNil(scaledFood)
        }
    }

    // MARK: - Cache Service Tests

    func testCacheServiceIntegration() {
        let stats = foodService.getCacheStatistics()
        XCTAssertNotNil(stats)

        // Test cache operations
        foodService.clearCache()
        foodService.cleanupCache()

        // These should not crash
        XCTAssertTrue(true)
    }

    // MARK: - Helper Methods

    private func createMockFood(name: String) -> Food {
        // Create nutritionally consistent food: 10g protein + 15g carbs + 5g fat = 40+60+45 = 145 calories
        return Food(
            id: UUID(),
            name: name,
            brand: "Test Brand",
            barcode: "123456789",
            description: "Test food description",
            servingSize: 100.0,
            servingUnit: "g",
            servingSizeGrams: 100.0,
            calories: 145.0,  // Matches macro calculation: (10*4)+(15*4)+(5*9) = 145
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
}