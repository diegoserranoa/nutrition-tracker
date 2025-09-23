//
//  FoodLogService.swift
//  NutritionTrackerV2
//
//  Food logging service layer for date-based CRUD operations with Supabase backend
//

import Foundation
import Supabase
import OSLog
import Combine

// MARK: - FoodLog Search Parameters

struct FoodLogSearchParameters {
    let userId: UUID?
    let date: Date?
    let startDate: Date?
    let endDate: Date?
    let mealType: MealType?
    let limit: Int
    let offset: Int

    init(
        userId: UUID? = nil,
        date: Date? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        mealType: MealType? = nil,
        limit: Int = 100,
        offset: Int = 0
    ) {
        self.userId = userId
        self.date = date
        self.startDate = startDate
        self.endDate = endDate
        self.mealType = mealType
        self.limit = limit
        self.offset = offset
    }
}

// MARK: - FoodLog Service Protocol

protocol FoodLogServiceProtocol {
    func createFoodLog(_ foodLog: FoodLog) async throws -> FoodLog
    func updateFoodLog(_ foodLog: FoodLog) async throws -> FoodLog
    func deleteFoodLog(id: UUID) async throws
    func getFoodLogById(_ id: UUID) async throws -> FoodLog?
    func getFoodLogsForDate(_ date: Date, userId: UUID) async throws -> [FoodLog]
    func getFoodLogsInDateRange(startDate: Date, endDate: Date, userId: UUID) async throws -> [FoodLog]
    func getFoodLogsByMealType(_ mealType: MealType, date: Date, userId: UUID) async throws -> [FoodLog]
    func searchFoodLogs(parameters: FoodLogSearchParameters) async throws -> [FoodLog]
    func getDailyNutritionSummary(for date: Date, userId: UUID) async throws -> DailyNutritionSummary
}

// MARK: - FoodLog Service Implementation

@MainActor
class FoodLogService: ObservableObject, FoodLogServiceProtocol {

    // MARK: - Properties

    private let supabaseManager: SupabaseManager
    private let foodService: FoodService
    private let cacheService: CacheService
    private let logger = Logger(subsystem: "com.nutritiontracker.foodlogservice", category: "FoodLogService")
    private let tableName = "food_logs"

    // Published properties for UI updates
    @Published var isLoading = false
    @Published var currentError: DataServiceError?

    // Real-time subscriptions
    @Published var realtimeFoodLogs: [FoodLog] = []
    private var cancellables = Set<AnyCancellable>()
    private var realtimeSubscription: RealtimeChannel?

    // MARK: - Initialization

    init(supabaseManager: SupabaseManager? = nil, foodService: FoodService? = nil, cacheService: CacheService? = nil) {
        self.supabaseManager = supabaseManager ?? SupabaseManager.shared
        self.cacheService = cacheService ?? CacheService.shared
        self.foodService = foodService ?? FoodService(supabaseManager: supabaseManager, cacheService: self.cacheService)
    }

    // MARK: - CRUD Operations

    func createFoodLog(_ foodLog: FoodLog) async throws -> FoodLog {
        logger.info("Creating food log for food ID: \\(foodLog.foodId)")

        // Validate the food log using the existing validation system
        do {
            try foodLog.validate()
        } catch let error as DataServiceError {
            throw error
        } catch {
            throw DataServiceError.validationFailed([ValidationError(field: "foodLog", code: .invalid, message: error.localizedDescription)])
        }

        isLoading = true
        currentError = nil
        defer { isLoading = false }

        do {
            // Convert FoodLog to AnyJSON dictionary for Supabase
            let foodLogDict = try foodLogToAnyJSONDictionary(foodLog)

            let response: [FoodLog] = try await supabaseManager
                .from(tableName)
                .insert(foodLogDict)
                .select()
                .execute()
                .value

            guard let createdFoodLog = response.first else {
                throw DataServiceError.missingResponseData
            }

            logger.info("Successfully created food log with ID: \\(createdFoodLog.id)")
            return createdFoodLog

        } catch let error as DataServiceError {
            currentError = error
            throw error
        } catch {
            let dataServiceError = DataServiceErrorFactory.fromSupabaseError(error)
            currentError = dataServiceError
            throw dataServiceError
        }
    }

    func updateFoodLog(_ foodLog: FoodLog) async throws -> FoodLog {
        logger.info("Updating food log: \\(foodLog.id)")

        // Validate the food log
        do {
            try foodLog.validate()
        } catch let error as DataServiceError {
            throw error
        } catch {
            throw DataServiceError.validationFailed([ValidationError(field: "foodLog", code: .invalid, message: error.localizedDescription)])
        }

        isLoading = true
        currentError = nil
        defer { isLoading = false }

        do {
            // Convert FoodLog to AnyJSON dictionary for Supabase
            let foodLogDict = try foodLogToAnyJSONDictionary(foodLog)

            let response: [FoodLog] = try await supabaseManager
                .from(tableName)
                .update(foodLogDict)
                .eq("id", value: foodLog.id.uuidString)
                .select()
                .execute()
                .value

            guard let updatedFoodLog = response.first else {
                throw DataServiceError.notFound("FoodLog with ID \\(foodLog.id)")
            }

            logger.info("Successfully updated food log with ID: \\(updatedFoodLog.id)")
            return updatedFoodLog

        } catch let error as DataServiceError {
            currentError = error
            throw error
        } catch {
            let dataServiceError = DataServiceErrorFactory.fromSupabaseError(error)
            currentError = dataServiceError
            throw dataServiceError
        }
    }

    func deleteFoodLog(id: UUID) async throws {
        logger.info("Deleting food log: \\(id)")

        isLoading = true
        currentError = nil
        defer { isLoading = false }

        do {
            try await supabaseManager
                .from(tableName)
                .delete()
                .eq("id", value: id.uuidString)
                .execute()

            logger.info("Successfully deleted food log with ID: \\(id)")

        } catch let error as DataServiceError {
            currentError = error
            throw error
        } catch {
            let dataServiceError = DataServiceErrorFactory.fromSupabaseError(error)
            currentError = dataServiceError
            throw dataServiceError
        }
    }

    func getFoodLogById(_ id: UUID) async throws -> FoodLog? {
        logger.info("Fetching food log by ID: \\(id)")

        isLoading = true
        currentError = nil
        defer { isLoading = false }

        do {
            let response: [FoodLog] = try await supabaseManager
                .from(tableName)
                .select()
                .eq("id", value: id.uuidString)
                .execute()
                .value

            let result = response.first
            logger.info("Successfully fetched food log: \\(result != nil ? \"found\" : \"not found\")")
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

    // MARK: - Date-Based Queries

    func getFoodLogsForDate(_ date: Date, userId: UUID) async throws -> [FoodLog] {
        logger.info("Fetching food logs for date: \\(date) and user: \\(userId)")

        let (startOfDay, endOfDay) = dayBounds(for: date)

        isLoading = true
        currentError = nil
        defer { isLoading = false }

        do {
            let response: [FoodLog] = try await supabaseManager
                .from(tableName)
                .select()
                .eq("user_id", value: userId.uuidString)
                .gte("logged_at", value: formatDateForSupabase(startOfDay))
                .lt("logged_at", value: formatDateForSupabase(endOfDay))
                .order("logged_at", ascending: true)
                .execute()
                .value

            logger.info("Successfully found \\(response.count) food logs for date")
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

    func getFoodLogsInDateRange(startDate: Date, endDate: Date, userId: UUID) async throws -> [FoodLog] {
        logger.info("Fetching food logs from \\(startDate) to \\(endDate) for user: \\(userId)")

        let (startOfStartDate, _) = dayBounds(for: startDate)
        let (_, endOfEndDate) = dayBounds(for: endDate)

        isLoading = true
        currentError = nil
        defer { isLoading = false }

        do {
            let response: [FoodLog] = try await supabaseManager
                .from(tableName)
                .select()
                .eq("user_id", value: userId.uuidString)
                .gte("logged_at", value: formatDateForSupabase(startOfStartDate))
                .lt("logged_at", value: formatDateForSupabase(endOfEndDate))
                .order("logged_at", ascending: true)
                .execute()
                .value

            logger.info("Successfully found \\(response.count) food logs in date range")
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

    func getFoodLogsByMealType(_ mealType: MealType, date: Date, userId: UUID) async throws -> [FoodLog] {
        logger.info("Fetching food logs for meal type: \\(mealType) on date: \\(date)")

        let (startOfDay, endOfDay) = dayBounds(for: date)

        isLoading = true
        currentError = nil
        defer { isLoading = false }

        do {
            let response: [FoodLog] = try await supabaseManager
                .from(tableName)
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("meal_type", value: mealType.rawValue)
                .gte("logged_at", value: formatDateForSupabase(startOfDay))
                .lt("logged_at", value: formatDateForSupabase(endOfDay))
                .order("logged_at", ascending: true)
                .execute()
                .value

            logger.info("Successfully found \\(response.count) food logs for meal type")
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

    func searchFoodLogs(parameters: FoodLogSearchParameters) async throws -> [FoodLog] {
        logger.info("Searching food logs with parameters")

        isLoading = true
        currentError = nil
        defer { isLoading = false }

        do {
            var query = supabaseManager.from(tableName).select()

            // Apply user filter if provided
            if let userId = parameters.userId {
                query = query.eq("user_id", value: userId.uuidString)
            }

            // Apply date filters
            if let date = parameters.date {
                let (startOfDay, endOfDay) = dayBounds(for: date)
                query = query
                    .gte("logged_at", value: formatDateForSupabase(startOfDay))
                    .lt("logged_at", value: formatDateForSupabase(endOfDay))
            } else {
                if let startDate = parameters.startDate {
                    query = query.gte("logged_at", value: formatDateForSupabase(startDate))
                }
                if let endDate = parameters.endDate {
                    query = query.lt("logged_at", value: formatDateForSupabase(endDate))
                }
            }

            // Apply meal type filter if provided
            if let mealType = parameters.mealType {
                query = query.eq("meal_type", value: mealType.rawValue)
            }

            // Apply pagination
            let finalQuery = query
                .order("logged_at", ascending: true)
                .range(from: parameters.offset, to: parameters.offset + parameters.limit - 1)

            let response: [FoodLog] = try await finalQuery.execute().value

            logger.info("Successfully found \\(response.count) food logs")
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

    // MARK: - Daily Aggregation

    func getDailyNutritionSummary(for date: Date, userId: UUID) async throws -> DailyNutritionSummary {
        logger.info("Calculating daily nutrition summary for date: \\(date)")

        // Check cache first
        if let cachedSummary = cacheService.getCachedDailyNutritionSummary(for: date, userId: userId) {
            logger.debug("Retrieved daily nutrition summary from cache")
            return cachedSummary
        }

        // Get all food logs for the day
        let foodLogs = try await getFoodLogsForDate(date, userId: userId)

        // Load associated food data for each log
        var logsWithFood: [FoodLog] = []
        for var log in foodLogs {
            if let food = try await foodService.getFoodById(log.foodId) {
                log.food = food
                logsWithFood.append(log)
            }
        }

        // Calculate the summary
        let summary = DailyNutritionSummary.from(logs: logsWithFood, for: date)
        logger.info("Successfully calculated daily summary with \\(summary.totalCalories) calories")

        // Cache the summary
        cacheService.cacheDailyNutritionSummary(summary, for: date, userId: userId)

        return summary
    }

    // MARK: - Helper Methods

    private func doubleToAnyJSON(_ value: Double?) throws -> AnyJSON {
        guard let value = value else { return AnyJSON.null }
        return try AnyJSON(value)
    }

    private func foodLogToAnyJSONDictionary(_ foodLog: FoodLog) throws -> [String: AnyJSON] {
        let formatter = ISO8601DateFormatter()

        return [
            "id": AnyJSON.string(foodLog.id.uuidString),
            "user_id": AnyJSON.string(foodLog.userId.uuidString),
            "food_id": AnyJSON.string(foodLog.foodId.uuidString),
            "quantity": try AnyJSON(foodLog.quantity),
            "unit": AnyJSON.string(foodLog.unit),
            "total_grams": try doubleToAnyJSON(foodLog.totalGrams),
            "meal_type": AnyJSON.string(foodLog.mealType.rawValue),
            "logged_at": AnyJSON.string(formatter.string(from: foodLog.loggedAt)),
            "created_at": AnyJSON.string(formatter.string(from: foodLog.createdAt)),
            "updated_at": AnyJSON.string(formatter.string(from: foodLog.updatedAt)),
            "notes": foodLog.notes.map(AnyJSON.string) ?? AnyJSON.null,
            "brand": foodLog.brand.map(AnyJSON.string) ?? AnyJSON.null,
            "custom_name": foodLog.customName.map(AnyJSON.string) ?? AnyJSON.null,
            "is_deleted": AnyJSON.bool(foodLog.isDeleted),
            "sync_status": AnyJSON.string(foodLog.syncStatus.rawValue)
        ]
    }

    // MARK: - Timezone Handling

    private func dayBounds(for date: Date) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay

        return (start: startOfDay, end: endOfDay)
    }

    private func formatDateForSupabase(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: date)
    }

    // MARK: - Serving Size Calculations

    /// Calculate total grams from quantity and serving information
    /// - Parameters:
    ///   - quantity: The quantity consumed
    ///   - unit: The unit of measurement
    ///   - food: The food item with serving size information
    /// - Returns: Calculated total grams, or nil if cannot be calculated
    func calculateTotalGrams(quantity: Double, unit: String, food: Food) -> Double? {
        // If the unit matches the food's serving unit, we can calculate directly
        if unit.lowercased() == food.servingUnit.lowercased() {
            let multiplier = quantity / food.servingSize
            return food.servingSizeGrams.map { $0 * multiplier }
        }

        // For common unit conversions (this could be expanded with a unit conversion system)
        if unit.lowercased() == "grams" || unit.lowercased() == "g" {
            return quantity
        }

        // If we can't calculate, return nil
        return nil
    }

    /// Scale nutritional values based on actual consumption
    /// - Parameters:
    ///   - food: The base food item
    ///   - quantity: The quantity consumed
    ///   - unit: The unit of measurement
    ///   - totalGrams: Optional override for total grams
    /// - Returns: Food object with scaled nutritional values
    func scaleNutrition(food: Food, quantity: Double, unit: String, totalGrams: Double? = nil) -> Food {
        let actualGrams = totalGrams ?? calculateTotalGrams(quantity: quantity, unit: unit, food: food)

        if let grams = actualGrams, let servingGrams = food.servingSizeGrams {
            let multiplier = grams / servingGrams
            return food.scaled(by: multiplier)
        } else {
            // Fallback to quantity-based scaling
            let multiplier = quantity / food.servingSize
            return food.scaled(by: multiplier)
        }
    }

    // MARK: - Real-time Subscriptions

    /// Subscribe to real-time updates for food logs for a specific user
    /// - Parameter userId: The user ID to subscribe to
    func subscribeToFoodLogs(for userId: UUID) {
        logger.info("Setting up real-time subscription for user: \\(userId)")

        // Clean up existing subscription
        unsubscribeFromFoodLogs()

        // Note: Real-time subscriptions will be implemented when the Supabase realtime API is properly configured
        // For now, this is a placeholder that sets up the structure for future implementation
        logger.info("Real-time subscriptions not yet implemented - placeholder method")

        // TODO: Implement real-time subscriptions with proper Supabase configuration
        // This would typically involve:
        // 1. Setting up a realtime channel for the food_logs table
        // 2. Filtering by user_id
        // 3. Handling INSERT, UPDATE, DELETE events
        // 4. Updating the realtimeFoodLogs array accordingly
    }

    /// Unsubscribe from real-time updates
    func unsubscribeFromFoodLogs() {
        logger.info("Unsubscribing from real-time food log updates")

        realtimeSubscription?.unsubscribe()
        realtimeSubscription = nil
        cancellables.removeAll()
    }

    // MARK: - Real-time Event Handlers (Placeholder for future implementation)

    // TODO: Implement real-time event handlers when Supabase realtime is properly configured
    // These would handle INSERT, UPDATE, DELETE events from the food_logs table

    /// Load initial food logs and set up real-time subscription
    /// - Parameters:
    ///   - date: The date to load logs for
    ///   - userId: The user ID
    func loadAndSubscribeToFoodLogs(for date: Date, userId: UUID) async {
        do {
            // Load initial data
            let initialLogs = try await getFoodLogsForDate(date, userId: userId)
            await MainActor.run {
                realtimeFoodLogs = initialLogs
            }

            // Set up real-time subscription
            subscribeToFoodLogs(for: userId)

        } catch {
            logger.error("Failed to load initial food logs: \\(error.localizedDescription)")
            currentError = error as? DataServiceError ?? DataServiceErrorFactory.fromSupabaseError(error)
        }
    }

    deinit {
        // Clean up subscriptions synchronously
        realtimeSubscription?.unsubscribe()
        realtimeSubscription = nil
    }
}