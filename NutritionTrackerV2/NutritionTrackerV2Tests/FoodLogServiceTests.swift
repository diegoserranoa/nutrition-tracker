//
//  FoodLogServiceTests.swift
//  NutritionTrackerV2Tests
//
//  Unit tests for FoodLogService date-based operations and daily aggregation
//

import XCTest
import Supabase
import Auth
@testable import NutritionTrackerV2

@MainActor
class FoodLogServiceTests: XCTestCase {

    var foodLogService: FoodLogService!
    var testUserId: UUID!
    var testFoodId: UUID!

    override func setUp() async throws {
        try await super.setUp()

        // Use default services for simplified testing
        foodLogService = FoodLogService()

        testUserId = UUID()
        testFoodId = UUID()
    }

    override func tearDown() async throws {
        foodLogService = nil
        testUserId = nil
        testFoodId = nil
        try await super.tearDown()
    }

    // MARK: - Service Initialization Tests

    func testFoodLogServiceInitialization() {
        XCTAssertNotNil(foodLogService)
        XCTAssertFalse(foodLogService.isLoading)
        XCTAssertNil(foodLogService.currentError)
    }

    // MARK: - FoodLog Model Tests

    func testCreateFoodLog_ValidationSuccess() async throws {
        // Given
        let validFoodLog = createMockFoodLog(userId: testUserId, foodId: testFoodId)

        // When/Then - Should not throw validation error
        XCTAssertNoThrow(try validFoodLog.validate())
    }

    func testCreateFoodLog_ValidationError() async throws {
        // Given
        let invalidFoodLog = createMockFoodLog(userId: testUserId, foodId: testFoodId, quantity: -1.0) // Invalid negative quantity

        // When & Then - Should throw validation error
        XCTAssertThrowsError(try invalidFoodLog.validate()) { error in
            XCTAssertTrue(error is DataServiceError)
            if case let DataServiceError.validationFailed(errors) = error {
                XCTAssertFalse(errors.isEmpty)
            } else {
                XCTFail("Expected validation failed error")
            }
        }
    }

    // MARK: - FoodLog Search Parameters Tests

    func testFoodLogSearchParametersInitialization() {
        // Test default initialization
        let defaultParams = FoodLogSearchParameters()
        XCTAssertNil(defaultParams.userId)
        XCTAssertNil(defaultParams.date)
        XCTAssertEqual(defaultParams.limit, 100)
        XCTAssertEqual(defaultParams.offset, 0)

        // Test custom initialization
        let customParams = FoodLogSearchParameters(
            userId: testUserId,
            date: Date(),
            mealType: .breakfast,
            limit: 50,
            offset: 10
        )
        XCTAssertEqual(customParams.userId, testUserId)
        XCTAssertNotNil(customParams.date)
        XCTAssertEqual(customParams.mealType, .breakfast)
        XCTAssertEqual(customParams.limit, 50)
        XCTAssertEqual(customParams.offset, 10)
    }

    // MARK: - FoodLog Model Validation Tests

    func testFoodLogModelValidation() {
        let foodLog = createMockFoodLog(userId: testUserId, foodId: testFoodId)

        // Test valid food log
        XCTAssertNoThrow(try foodLog.validate())

        // Test display properties
        XCTAssertFalse(foodLog.displayName.isEmpty)
        XCTAssertFalse(foodLog.quantityDescription.isEmpty)
        XCTAssertNotNil(foodLog.gramsDescription)
    }

    // MARK: - DailyNutritionSummary Tests

    func testDailyNutritionSummaryCreation() {
        let summary = createMockDailyNutritionSummary()

        XCTAssertNotNil(summary.date)
        XCTAssertGreaterThan(summary.totalCalories, 0)
        XCTAssertGreaterThan(summary.totalProtein, 0)
        XCTAssertGreaterThan(summary.logCount, 0)
    }

    func testDailyNutritionSummaryFromLogs() {
        // Given
        let testDate = Date()
        let foodLogs = [
            createMockFoodLog(userId: testUserId, foodId: testFoodId, date: testDate)
        ]

        // When
        let summary = DailyNutritionSummary.from(logs: foodLogs, for: testDate)

        // Then
        XCTAssertEqual(summary.date, testDate)
        XCTAssertEqual(summary.logCount, 1)
        XCTAssertNotNil(summary.mealBreakdown)
    }

    // MARK: - Helper Methods

    private func createMockFoodLog(
        userId: UUID,
        foodId: UUID,
        date: Date = Date(),
        quantity: Double = 1.5
    ) -> FoodLog {
        return FoodLog(
            id: UUID(),
            userId: userId,
            foodId: foodId,
            quantity: quantity,
            unit: "cups",
            totalGrams: 200.0,
            mealType: .lunch,
            loggedAt: date,
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
        calories: Double = 100.0,
        protein: Double = 10.0,
        carbs: Double = 15.0,
        fat: Double = 5.0
    ) -> Food {
        return Food(
            id: UUID(),
            name: name,
            brand: "Test Brand",
            barcode: "123456789",
            description: "Test food description",
            servingSize: 100.0,
            servingUnit: "g",
            servingSizeGrams: 100.0,
            calories: calories,
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

    private func createMockDailyNutritionSummary() -> DailyNutritionSummary {
        return DailyNutritionSummary(
            date: Date(),
            totalCalories: 500.0,
            totalProtein: 25.0,
            totalCarbohydrates: 60.0,
            totalFat: 20.0,
            totalFiber: 10.0,
            totalSodium: 100.0,
            mealBreakdown: [:],
            logCount: 1
        )
    }
}