//
//  FoodLogViewModel.swift
//  NutritionTrackerV2
//
//  ViewModel for daily food logging and consumption tracking
//

import Foundation
import Combine
import SwiftUI
import OSLog

@MainActor
class FoodLogViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var selectedDate = Date()
    @Published var foodLogs: [FoodLog] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var dailySummary: DailyNutritionSummary?
    @Published var datesWithLogs: Set<String> = []

    // UI State
    @Published var showingFoodPicker = false
    @Published var selectedMealType: MealType = .breakfast

    // Real-time update state
    @Published var isUpdating = false
    @Published var lastUpdateTime: Date?
    @Published var operationFeedback: OperationFeedback?

    // MARK: - Private Properties

    private let foodLogService: FoodLogService
    private let realtimeManager: RealtimeManager
    private let supabaseManager: SupabaseManager
    private let logger = Logger(subsystem: "com.nutritiontracker.foodlog", category: "FoodLogViewModel")
    private var cancellables = Set<AnyCancellable>()
    private var updateTimer: AnyCancellable?

    // MARK: - Computed Properties

    /// Food logs grouped by meal type for the selected date
    var logsByMealType: [MealType: [FoodLog]] {
        Dictionary(grouping: foodLogs) { $0.mealType }
    }

    /// All meal types that should be displayed (even if empty)
    var displayedMealTypes: [MealType] {
        [.breakfast, .lunch, .dinner, .snack]
    }

    /// Whether there are any logs for the selected date
    var hasLogsForDate: Bool {
        !foodLogs.isEmpty
    }

    /// Formatted date string for display
    var selectedDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: selectedDate)
    }

    /// Whether the selected date is today
    var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    /// Check if a date has logged foods
    func hasLogsForDate(_ date: Date) -> Bool {
        let dateString = dateStringForTracking(date)
        return datesWithLogs.contains(dateString)
    }

    // MARK: - Initialization

    init(foodLogService: FoodLogService? = nil, realtimeManager: RealtimeManager? = nil, supabaseManager: SupabaseManager? = nil) {
        self.foodLogService = foodLogService ?? FoodLogService()
        self.realtimeManager = realtimeManager ?? RealtimeManager.shared
        self.supabaseManager = supabaseManager ?? SupabaseManager.shared
        setupObservers()
        setupRealtimeSubscriptions()
        loadFoodLogs()
    }

    // MARK: - Public Methods

    /// Load food logs for the selected date
    func loadFoodLogs() {
        Task {
            await fetchFoodLogs(for: selectedDate)
        }
    }

    /// Refresh food logs for the current date
    func refreshFoodLogs() {
        Task {
            await fetchFoodLogs(for: selectedDate, forceRefresh: true)
        }
    }

    /// Quietly refresh food logs without showing loading indicator (for real-time updates)
    private func refreshFoodLogsQuiet() async {
        await fetchFoodLogs(for: selectedDate, forceRefresh: true, showLoading: false)
    }

    /// Change the selected date and load logs for that date
    /// - Parameter date: The new date to select
    func selectDate(_ date: Date) {
        selectedDate = date
        Task {
            await fetchFoodLogs(for: date)
        }
    }

    /// Add a food log entry with optimistic updates
    /// - Parameters:
    ///   - food: The food item to log
    ///   - quantity: The quantity consumed
    ///   - unit: The unit of measurement
    ///   - mealType: The meal type
    ///   - loggedAt: Optional specific time (defaults to now)
    func addFoodLog(food: Food, quantity: Double, unit: String, mealType: MealType, loggedAt: Date? = nil) async {
        // Get the current authenticated user
        guard let currentUser = await supabaseManager.currentUser else {
            logger.error("Cannot add food log: No authenticated user")
            showOperationFeedback(.error("Please log in to add food logs"))
            return
        }

        let logTime = loggedAt ?? selectedDate

        // Create temporary food log for optimistic update
        let tempFoodLog = FoodLog.create(
            userId: currentUser.id,
            food: food,
            quantity: quantity,
            unit: unit,
            mealType: mealType,
            loggedAt: logTime
        )

        // Optimistic update - add immediately to UI
        isUpdating = true
        foodLogs.append(tempFoodLog)
        updateDailySummary()
        showOperationFeedback(.adding(food.name))

        do {
            logger.info("Adding food log: \(food.name) - \(quantity) \(unit)")

            let createdLog = try await foodLogService.createFoodLog(tempFoodLog)

            // Replace optimistic entry with real one, but preserve the food object
            if let index = foodLogs.firstIndex(where: { $0.id == tempFoodLog.id }) {
                var updatedLog = createdLog
                updatedLog.food = food // Preserve the food object from the original
                foodLogs[index] = updatedLog
            }

            updateDailySummary()
            lastUpdateTime = Date()
            showOperationFeedback(.success("Added \(food.name)"))

            logger.info("Successfully added food log: \(food.name)")

        } catch {
            logger.error("Failed to add food log: \(error.localizedDescription)")

            // Remove optimistic entry on failure
            foodLogs.removeAll { $0.id == tempFoodLog.id }
            updateDailySummary()
            showOperationFeedback(.error("Failed to add \(food.name)"))
            self.error = error
        }

        isUpdating = false
    }

    /// Delete a food log entry with optimistic updates
    /// - Parameter log: The food log to delete
    func deleteFoodLog(_ log: FoodLog) async {
        // Store original for rollback
        let originalLogs = foodLogs

        // Optimistic update - remove immediately from UI
        isUpdating = true
        foodLogs.removeAll { $0.id == log.id }
        updateDailySummary()
        showOperationFeedback(.deleting(log.displayName))

        do {
            logger.info("Deleting food log: \(log.displayName)")

            try await foodLogService.deleteFoodLog(id: log.id)

            lastUpdateTime = Date()
            showOperationFeedback(.success("Removed \(log.displayName)"))

            logger.info("Successfully deleted food log: \(log.displayName)")

        } catch {
            logger.error("Failed to delete food log: \(error.localizedDescription)")

            // Rollback on failure
            foodLogs = originalLogs
            updateDailySummary()
            showOperationFeedback(.error("Failed to remove \(log.displayName)"))
            self.error = error
        }

        isUpdating = false
    }

    /// Update an existing food log entry
    /// - Parameters:
    ///   - log: The food log to update
    ///   - quantity: New quantity
    ///   - unit: New unit
    ///   - mealType: New meal type
    func updateFoodLog(_ log: FoodLog, quantity: Double?, unit: String?, mealType: MealType?) async {
        do {
            logger.info("Updating food log: \(log.displayName)")

            let updatedLog = log.updated(
                quantity: quantity,
                unit: unit,
                mealType: mealType
            )

            let result = try await foodLogService.updateFoodLog(updatedLog)

            // Update local array
            if let index = foodLogs.firstIndex(where: { $0.id == result.id }) {
                foodLogs[index] = result
                updateDailySummary()
            }

            logger.info("Successfully updated food log: \(log.displayName)")

        } catch {
            logger.error("Failed to update food log: \(error.localizedDescription)")
            self.error = error
        }
    }

    /// Clear the current error
    func clearError() {
        error = nil
    }

    /// Show operation feedback to user
    /// - Parameter feedback: The feedback to show
    func showOperationFeedback(_ feedback: OperationFeedback) {
        operationFeedback = feedback

        // Auto-clear success/info feedback after a delay
        switch feedback {
        case .success, .adding, .deleting:
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                if self.operationFeedback == feedback {
                    self.operationFeedback = nil
                }
            }
        case .error:
            // Error feedback clears after longer delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                if self.operationFeedback == feedback {
                    self.operationFeedback = nil
                }
            }
        }
    }

    /// Clear operation feedback
    func clearOperationFeedback() {
        operationFeedback = nil
    }

    // MARK: - Private Methods

    private func setupObservers() {
        // Observe date changes
        $selectedDate
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor in
                    await self.fetchFoodLogs(for: self.selectedDate)
                }
            }
            .store(in: &cancellables)
    }

    private func setupRealtimeSubscriptions() {
        // Subscribe to food_logs events for real-time updates
        realtimeManager.foodLogEvents
            .sink { [weak self] eventData in
                Task { @MainActor in
                    await self?.handleFoodLogRealtimeEvent(eventData)
                }
            }
            .store(in: &cancellables)

        logger.info("Set up real-time subscriptions for food log events")
    }

    private func handleFoodLogRealtimeEvent(_ eventData: RealtimeEventData<FoodLog>) async {
        logger.info("Received real-time food log event: \(eventData.eventType.rawValue) for table \(eventData.tableName)")

        switch eventData.eventType {
        case .insert:
            // New food log added - refresh data for current date
            await refreshFoodLogsQuiet()

        case .update:
            // Food log updated - refresh data for current date
            await refreshFoodLogsQuiet()

        case .delete:
            // Food log deleted - refresh data for current date
            await refreshFoodLogsQuiet()
        }
    }

    private func fetchFoodLogs(for date: Date, forceRefresh: Bool = false, showLoading: Bool = true) async {
        if showLoading {
            isLoading = true
        }
        error = nil

        // Get the current authenticated user
        guard let currentUser = await supabaseManager.currentUser else {
            logger.error("Cannot fetch food logs: No authenticated user")
            isLoading = false
            error = SupabaseError.userNotAuthenticated
            return
        }

        do {
            logger.info("Fetching food logs for date: \(date)")

            // Create date range for the entire day
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date

            let logs = try await foodLogService.getFoodLogsInDateRange(
                startDate: startOfDay,
                endDate: endOfDay,
                userId: currentUser.id
            )

            // Update UI on main thread
            foodLogs = logs.sorted { $0.loggedAt < $1.loggedAt }
            updateDailySummary()

            logger.info("Successfully loaded \(self.foodLogs.count) food logs for \(date)")

        } catch {
            logger.error("Failed to fetch food logs: \(error.localizedDescription)")
            self.error = error
        }

        if showLoading {
            isLoading = false
        }
    }

    private func updateDailySummary() {
        dailySummary = DailyNutritionSummary.from(logs: self.foodLogs, for: self.selectedDate)
        updateDatesWithLogs()
    }

    private func updateDatesWithLogs() {
        // Update the tracking set when food logs change
        let dateString = dateStringForTracking(selectedDate)
        if foodLogs.isEmpty {
            datesWithLogs.remove(dateString)
        } else {
            datesWithLogs.insert(dateString)
        }
    }

    private func dateStringForTracking(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    /// Load dates with food logs for the current month (for calendar indicators)
    func loadDatesWithLogsForMonth(_ date: Date = Date()) async {
        // Get the current authenticated user
        guard let currentUser = await supabaseManager.currentUser else {
            logger.error("Cannot load month data: No authenticated user")
            return
        }

        let calendar = Calendar.current
        guard let monthStart = calendar.dateInterval(of: .month, for: date)?.start,
              let monthEnd = calendar.dateInterval(of: .month, for: date)?.end else {
            return
        }

        do {
            let logs = try await foodLogService.getFoodLogsInDateRange(
                startDate: monthStart,
                endDate: monthEnd,
                userId: currentUser.id
            )

            // Extract unique dates from the logs
            let uniqueDates = Set(logs.map { dateStringForTracking($0.loggedAt) })

            await MainActor.run {
                datesWithLogs.formUnion(uniqueDates)
            }
        } catch {
            logger.error("Failed to load dates with logs: \(error.localizedDescription)")
        }
    }

    // MARK: - Real-time Management

    func startRealtimeUpdates() {
        Task {
            await realtimeManager.start()
        }
    }

    func stopRealtimeUpdates() {
        realtimeManager.stop()
    }
}

// MARK: - Meal Type Extensions

extension MealType {

    /// System image name for the meal type
    var systemImage: String {
        switch self {
        case .breakfast:
            return "sunrise.fill"
        case .lunch:
            return "sun.max.fill"
        case .dinner:
            return "sunset.fill"
        case .snack:
            return "leaf.fill"
        case .preworkout:
            return "dumbbell.fill"
        case .postworkout:
            return "figure.run"
        case .latenight:
            return "moon.fill"
        case .other:
            return "fork.knife"
        }
    }

    /// SwiftUI Color for the meal type
    var uiColor: Color {
        switch self {
        case .breakfast:
            return .orange
        case .lunch:
            return .yellow
        case .dinner:
            return .blue
        case .snack:
            return .green
        case .preworkout:
            return .red
        case .postworkout:
            return .purple
        case .latenight:
            return .indigo
        case .other:
            return .gray
        }
    }
}

// MARK: - Operation Feedback

/// Enum representing different types of operation feedback
enum OperationFeedback: Equatable {
    case adding(String)     // "Adding Chicken Breast..."
    case deleting(String)   // "Removing Chicken Breast..."
    case success(String)    // "Added Chicken Breast"
    case error(String)      // "Failed to add Chicken Breast"

    var message: String {
        switch self {
        case .adding(let item):
            return "Adding \(item)..."
        case .deleting(let item):
            return "Removing \(item)..."
        case .success(let message):
            return message
        case .error(let message):
            return message
        }
    }

    var isError: Bool {
        if case .error = self {
            return true
        }
        return false
    }

    var isLoading: Bool {
        switch self {
        case .adding, .deleting:
            return true
        case .success, .error:
            return false
        }
    }
}