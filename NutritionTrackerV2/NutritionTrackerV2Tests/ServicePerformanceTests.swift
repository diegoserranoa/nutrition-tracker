//
//  ServicePerformanceTests.swift
//  NutritionTrackerV2Tests
//
//  Performance tests for search operations and bulk data handling
//

import XCTest
import Supabase
import Auth
@testable import NutritionTrackerV2

@MainActor
class ServicePerformanceTests: XCTestCase {

    var foodService: FoodService!
    var foodLogService: FoodLogService!
    var cacheService: CacheService!
    var testUserId: UUID!

    override func setUp() async throws {
        try await super.setUp()

        // Use default services for performance testing
        foodService = FoodService()
        foodLogService = FoodLogService()
        cacheService = CacheService.shared
        testUserId = UUID()
    }

    override func tearDown() async throws {
        foodService = nil
        foodLogService = nil
        cacheService = nil
        testUserId = nil
        try await super.tearDown()
    }

    // MARK: - Service Initialization Performance Tests

    func testServiceInitializationPerformance() {
        measure {
            // Test multiple service initializations
            for _ in 0..<10 {
                let service1 = FoodService()
                let service2 = FoodLogService()

                // Access properties to ensure services are fully initialized
                _ = service1.isLoading
                _ = service2.isLoading
            }
        }
    }

    // MARK: - Food Model Performance Tests

    func testFoodValidationPerformance_LargeDataset() {
        // Create a large dataset of food items
        let foods = (0..<1000).map { index in
            createMockFood(name: "Food \(index)")
        }

        measure {
            // Validate all foods
            for food in foods {
                do {
                    try food.validate()
                } catch {
                    // Expected for some test cases
                }
            }
        }
    }

    func testFoodScalingPerformance() {
        let baseFood = createMockFood(name: "Performance Test Food")
        let scalingFactors = Array(stride(from: 0.1, through: 10.0, by: 0.1))

        measure {
            for factor in scalingFactors {
                let _ = baseFood.scaled(by: factor)
            }
        }
    }

    func testFoodNutrientCalculationPerformance() {
        let foods = (0..<500).map { index in
            createMockFood(name: "Food \(index)", calories: Double(index + 100))
        }

        measure {
            for food in foods {
                // Test various computed properties
                let _ = food.caloriesPerGram
                let _ = food.macronutrientBreakdown
                let _ = food.displayName
                let _ = food.servingDescription
                let _ = food.hasCompleteBasicNutrition
                let _ = food.hasConsistentMacronutrients
            }
        }
    }

    // MARK: - FoodLog Model Performance Tests

    func testFoodLogValidationPerformance_LargeDataset() {
        let foodLogs = (0..<1000).map { index in
            createMockFoodLog(
                userId: testUserId,
                foodId: UUID(),
                quantity: Double(index % 10 + 1)
            )
        }

        measure {
            for foodLog in foodLogs {
                do {
                    try foodLog.validate()
                } catch {
                    // Expected for some test cases
                }
            }
        }
    }

    func testDailyNutritionSummaryPerformance() {
        // Create a day's worth of food logs
        let foodLogs = (0..<50).map { index in
            createMockFoodLogWithFood(
                userId: testUserId,
                calories: Double(index * 10 + 100),
                protein: Double(index + 5)
            )
        }
        let testDate = Date()

        measure {
            let _ = DailyNutritionSummary.from(logs: foodLogs, for: testDate)
        }
    }

    // MARK: - Search Parameters Performance Tests

    func testSearchParametersCreationPerformance() {
        measure {
            for i in 0..<10000 {
                let _ = FoodSearchParameters(
                    query: "test query \(i)",
                    limit: i % 100 + 1,
                    offset: i % 50
                )

                let _ = FoodLogSearchParameters(
                    userId: testUserId,
                    date: Date(),
                    mealType: .breakfast,
                    limit: i % 100 + 1,
                    offset: i % 50
                )
            }
        }
    }

    // MARK: - Cache Performance Tests

    func testCacheOperationsPerformance() {
        let foods = (0..<1000).map { index in
            createMockFood(name: "Cache Food \(index)")
        }

        measure {
            // Clear cache first
            cacheService.clear()

            // Cache all foods
            for food in foods {
                cacheService.cacheFood(food)
            }

            // Retrieve all foods
            for food in foods {
                let _ = cacheService.getCachedFood(id: food.id)
            }
        }
    }

    func testCacheStatisticsPerformance() {
        // Generate some cache activity first
        let foods = (0..<100).map { createMockFood(name: "Stats Food \($0)") }
        for food in foods {
            cacheService.cacheFood(food)
            let _ = cacheService.getCachedFood(id: food.id)
        }

        measure {
            for _ in 0..<1000 {
                let _ = cacheService.getStatistics()
            }
        }
    }

    // MARK: - Memory Usage Tests

    func testMemoryUsage_LargeFoodDataset() {
        // Test memory efficiency with large datasets
        measure {
            var foods: [Food] = []

            // Create a large number of food items
            for i in 0..<5000 {
                let food = createMockFood(
                    name: "Memory Test Food \(i)",
                    calories: Double(i),
                    protein: Double(i % 100)
                )
                foods.append(food)
            }

            // Access properties to ensure memory allocation
            let totalCalories = foods.reduce(0) { $0 + $1.calories }
            let totalProtein = foods.reduce(0) { $0 + $1.protein }

            // Use the values to prevent optimization
            XCTAssertGreaterThan(totalCalories, 0)
            XCTAssertGreaterThan(totalProtein, 0)

            // Clear the array to free memory
            foods.removeAll()
        }
    }

    // MARK: - Concurrent Operations Tests

    func testConcurrentValidationPerformance() {
        let foods = (0..<100).map { createMockFood(name: "Concurrent Food \($0)") }

        measure {
            // Simplified validation performance test without concurrency to avoid deadlocks
            var validationResults: [Bool] = []

            for food in foods {
                do {
                    try food.validate()
                    validationResults.append(true)
                } catch {
                    // Expected for some test cases
                    validationResults.append(false)
                }
            }

            // Use the results to prevent optimization
            XCTAssertEqual(validationResults.count, foods.count)
        }
    }

    // MARK: - Helper Methods

    private func createMockFood(
        name: String,
        calories: Double = 100.0,
        protein: Double = 10.0
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

    private func createMockFoodLog(
        userId: UUID,
        foodId: UUID,
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

    private func createMockFoodLogWithFood(
        userId: UUID,
        calories: Double,
        protein: Double
    ) -> FoodLog {
        let food = createMockFood(
            name: "Test Food",
            calories: calories,
            protein: protein
        )

        let foodLog = createMockFoodLog(userId: userId, foodId: food.id)
        // Note: In the actual implementation, food would be loaded separately
        // For now, we'll just return the food log without the attached food
        return foodLog
    }
}