//
//  FoodService.swift
//  NutritionTrackerV2
//
//  Food service layer for CRUD operations with Supabase backend
//

import Foundation
import Supabase
import OSLog

// MARK: - Food Search Parameters

struct FoodSearchParameters {
    let query: String?
    let limit: Int
    let offset: Int

    init(query: String? = nil, limit: Int = 50, offset: Int = 0) {
        self.query = query
        self.limit = limit
        self.offset = offset
    }
}

// MARK: - Food Service Protocol

protocol FoodServiceProtocol {
    func createFood(_ food: Food) async throws -> Food
    func updateFood(_ food: Food) async throws -> Food
    func deleteFood(id: UUID) async throws
    func getFoodById(_ id: UUID) async throws -> Food?
    func searchFoods(parameters: FoodSearchParameters) async throws -> [Food]
}

// MARK: - Food Service Implementation

@MainActor
class FoodService: ObservableObject, FoodServiceProtocol {

    // MARK: - Properties

    private let supabaseManager: SupabaseManager
    private let logger = Logger(subsystem: "com.nutritiontracker.foodservice", category: "FoodService")
    private let tableName = "foods"

    // Published properties for UI updates
    @Published var isLoading = false
    @Published var currentError: DataServiceError?

    // MARK: - Initialization

    init(supabaseManager: SupabaseManager? = nil) {
        self.supabaseManager = supabaseManager ?? SupabaseManager.shared
    }

    // MARK: - CRUD Operations

    func createFood(_ food: Food) async throws -> Food {
        logger.info("Creating food: \(food.name)")

        // Validate the food using the existing validation system
        do {
            try food.validate()
        } catch let error as DataServiceError {
            throw error
        } catch {
            throw DataServiceError.validationFailed([ValidationError(field: "food", code: .invalid, message: error.localizedDescription)])
        }

        isLoading = true
        currentError = nil
        defer { isLoading = false }

        do {
            // Convert Food to AnyJSON dictionary for Supabase
            let foodDict = try foodToAnyJSONDictionary(food)

            let response: [Food] = try await supabaseManager
                .from(tableName)
                .insert(foodDict)
                .select()
                .execute()
                .value

            guard let createdFood = response.first else {
                throw DataServiceError.missingResponseData
            }

            logger.info("Successfully created food with ID: \(createdFood.id)")
            return createdFood

        } catch let error as DataServiceError {
            currentError = error
            throw error
        } catch {
            let dataServiceError = DataServiceErrorFactory.fromSupabaseError(error)
            currentError = dataServiceError
            throw dataServiceError
        }
    }

    func updateFood(_ food: Food) async throws -> Food {
        logger.info("Updating food: \(food.id)")

        // Validate the food
        do {
            try food.validate()
        } catch let error as DataServiceError {
            throw error
        } catch {
            throw DataServiceError.validationFailed([ValidationError(field: "food", code: .invalid, message: error.localizedDescription)])
        }

        isLoading = true
        currentError = nil
        defer { isLoading = false }

        do {
            // Convert Food to AnyJSON dictionary for Supabase
            let foodDict = try foodToAnyJSONDictionary(food)

            let response: [Food] = try await supabaseManager
                .from(tableName)
                .update(foodDict)
                .eq("id", value: food.id.uuidString)
                .select()
                .execute()
                .value

            guard let updatedFood = response.first else {
                throw DataServiceError.notFound("Food with ID \(food.id)")
            }

            logger.info("Successfully updated food with ID: \(updatedFood.id)")
            return updatedFood

        } catch let error as DataServiceError {
            currentError = error
            throw error
        } catch {
            let dataServiceError = DataServiceErrorFactory.fromSupabaseError(error)
            currentError = dataServiceError
            throw dataServiceError
        }
    }

    func deleteFood(id: UUID) async throws {
        logger.info("Deleting food: \(id)")

        isLoading = true
        currentError = nil
        defer { isLoading = false }

        do {
            try await supabaseManager
                .from(tableName)
                .delete()
                .eq("id", value: id.uuidString)
                .execute()

            logger.info("Successfully deleted food with ID: \(id)")

        } catch let error as DataServiceError {
            currentError = error
            throw error
        } catch {
            let dataServiceError = DataServiceErrorFactory.fromSupabaseError(error)
            currentError = dataServiceError
            throw dataServiceError
        }
    }

    func getFoodById(_ id: UUID) async throws -> Food? {
        logger.info("Fetching food by ID: \(id)")

        isLoading = true
        currentError = nil
        defer { isLoading = false }

        do {
            let response: [Food] = try await supabaseManager
                .from(tableName)
                .select()
                .eq("id", value: id.uuidString)
                .execute()
                .value

            let result = response.first
            logger.info("Successfully fetched food: \(result != nil ? "found" : "not found")")
            return result

        } catch let error as DataServiceError {
            currentError = error
            throw error
        } catch {
            let dataServiceError = DataServiceErrorFactory.fromSupabaseError(error)
            currentError = dataServiceError
            throw dataServiceError
        }
    }

    func searchFoods(parameters: FoodSearchParameters) async throws -> [Food] {
        logger.info("Searching foods with parameters")

        isLoading = true
        currentError = nil
        defer { isLoading = false }

        do {
            var query = supabaseManager.from(tableName).select()

            // Apply text search filter if provided
            if let searchQuery = parameters.query, !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                query = query.textSearch("name", query: searchQuery)
            }

            // Apply pagination
            let finalQuery = query.range(from: parameters.offset, to: parameters.offset + parameters.limit - 1)

            let response: [Food] = try await finalQuery.execute().value

            logger.info("Successfully found \(response.count) foods")
            return response

        } catch let error as DataServiceError {
            currentError = error
            throw error
        } catch {
            let dataServiceError = DataServiceErrorFactory.fromSupabaseError(error)
            currentError = dataServiceError
            throw dataServiceError
        }
    }

    // MARK: - Helper Methods

    private func doubleToAnyJSON(_ value: Double?) throws -> AnyJSON {
        guard let value = value else { return AnyJSON.null }
        return try AnyJSON(value)
    }

    private func foodToAnyJSONDictionary(_ food: Food) throws -> [String: AnyJSON] {
        let now = Date()
        let formatter = ISO8601DateFormatter()

        return [
            "id": AnyJSON.string(food.id.uuidString),
            "name": AnyJSON.string(food.name),
            "brand": food.brand.map(AnyJSON.string) ?? AnyJSON.null,
            "barcode": food.barcode.map(AnyJSON.string) ?? AnyJSON.null,
            "description": food.description.map(AnyJSON.string) ?? AnyJSON.null,
            "serving_size": try AnyJSON(food.servingSize),
            "serving_unit": AnyJSON.string(food.servingUnit),
            "serving_size_grams": try doubleToAnyJSON(food.servingSizeGrams),
            "calories": try AnyJSON(food.calories),
            "protein": try AnyJSON(food.protein),
            "carbohydrates": try AnyJSON(food.carbohydrates),
            "fat": try AnyJSON(food.fat),
            "fiber": try doubleToAnyJSON(food.fiber),
            "sugar": try doubleToAnyJSON(food.sugar),
            "saturated_fat": try doubleToAnyJSON(food.saturatedFat),
            "unsaturated_fat": try doubleToAnyJSON(food.unsaturatedFat),
            "trans_fat": try doubleToAnyJSON(food.transFat),
            "sodium": try doubleToAnyJSON(food.sodium),
            "potassium": try doubleToAnyJSON(food.potassium),
            "calcium": try doubleToAnyJSON(food.calcium),
            "iron": try doubleToAnyJSON(food.iron),
            "vitamin_a": try doubleToAnyJSON(food.vitaminA),
            "vitamin_c": try doubleToAnyJSON(food.vitaminC),
            "vitamin_d": try doubleToAnyJSON(food.vitaminD),
            "vitamin_e": try doubleToAnyJSON(food.vitaminE),
            "vitamin_k": try doubleToAnyJSON(food.vitaminK),
            "vitamin_b1": try doubleToAnyJSON(food.vitaminB1),
            "vitamin_b2": try doubleToAnyJSON(food.vitaminB2),
            "vitamin_b3": try doubleToAnyJSON(food.vitaminB3),
            "vitamin_b6": try doubleToAnyJSON(food.vitaminB6),
            "vitamin_b12": try doubleToAnyJSON(food.vitaminB12),
            "folate": try doubleToAnyJSON(food.folate),
            "magnesium": try doubleToAnyJSON(food.magnesium),
            "phosphorus": try doubleToAnyJSON(food.phosphorus),
            "zinc": try doubleToAnyJSON(food.zinc),
            "category": food.category.map { AnyJSON.string($0.rawValue) } ?? AnyJSON.null,
            "is_verified": AnyJSON.bool(food.isVerified),
            "source": AnyJSON.string(food.source.rawValue),
            "created_at": AnyJSON.string(formatter.string(from: food.createdAt)),
            "updated_at": AnyJSON.string(formatter.string(from: now)),
            "created_by": food.createdBy.map { AnyJSON.string($0.uuidString) } ?? AnyJSON.null
        ]
    }
}