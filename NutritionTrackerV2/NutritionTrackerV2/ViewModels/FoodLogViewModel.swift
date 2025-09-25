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

    // MARK: - Private Properties

    private let foodLogService: FoodLogService
    private let logger = Logger(subsystem: "com.nutritiontracker.foodlog", category: "FoodLogViewModel")
    private var cancellables = Set<AnyCancellable>()

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

    init(foodLogService: FoodLogService? = nil) {
        self.foodLogService = foodLogService ?? FoodLogService()
        setupObservers()
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

    /// Change the selected date and load logs for that date
    /// - Parameter date: The new date to select
    func selectDate(_ date: Date) {
        selectedDate = date
        Task {
            await fetchFoodLogs(for: date)
        }
    }

    /// Add a food log entry
    /// - Parameters:
    ///   - food: The food item to log
    ///   - quantity: The quantity consumed
    ///   - unit: The unit of measurement
    ///   - mealType: The meal type
    ///   - loggedAt: Optional specific time (defaults to now)
    func addFoodLog(food: Food, quantity: Double, unit: String, mealType: MealType, loggedAt: Date? = nil) async {
        do {
            logger.info("Adding food log: \(food.name) - \(quantity) \(unit)")

            let logTime = loggedAt ?? selectedDate
            let foodLog = FoodLog.create(
                userId: UUID(), // TODO: Replace with actual user ID when auth is implemented
                food: food,
                quantity: quantity,
                unit: unit,
                mealType: mealType,
                loggedAt: logTime
            )

            let createdLog = try await foodLogService.createFoodLog(foodLog)

            // Update local state
            foodLogs.append(createdLog)
            updateDailySummary()

            logger.info("Successfully added food log: \(food.name)")

        } catch {
            logger.error("Failed to add food log: \(error.localizedDescription)")
            self.error = error
        }
    }

    /// Delete a food log entry
    /// - Parameter log: The food log to delete
    func deleteFoodLog(_ log: FoodLog) async {
        do {
            logger.info("Deleting food log: \(log.displayName)")

            try await foodLogService.deleteFoodLog(id: log.id)

            // Remove from local array
            foodLogs.removeAll { $0.id == log.id }
            updateDailySummary()

            logger.info("Successfully deleted food log: \(log.displayName)")

        } catch {
            logger.error("Failed to delete food log: \(error.localizedDescription)")
            self.error = error
        }
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

    private func fetchFoodLogs(for date: Date, forceRefresh: Bool = false) async {
        isLoading = true
        error = nil

        do {
            logger.info("Fetching food logs for date: \(date)")

            // Create date range for the entire day
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date

            let logs = try await foodLogService.getFoodLogsInDateRange(
                startDate: startOfDay,
                endDate: endOfDay,
                userId: UUID() // TODO: Replace with actual user ID when auth is implemented
            )

            // Update UI on main thread
            foodLogs = logs.sorted { $0.loggedAt < $1.loggedAt }
            updateDailySummary()

            logger.info("Successfully loaded \(self.foodLogs.count) food logs for \(date)")

        } catch {
            logger.error("Failed to fetch food logs: \(error.localizedDescription)")
            self.error = error
        }

        isLoading = false
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
        let calendar = Calendar.current
        guard let monthStart = calendar.dateInterval(of: .month, for: date)?.start,
              let monthEnd = calendar.dateInterval(of: .month, for: date)?.end else {
            return
        }

        do {
            let logs = try await foodLogService.getFoodLogsInDateRange(
                startDate: monthStart,
                endDate: monthEnd,
                userId: UUID() // TODO: Replace with actual user ID when auth is implemented
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