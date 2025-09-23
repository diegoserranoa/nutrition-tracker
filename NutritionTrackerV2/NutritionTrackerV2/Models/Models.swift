//
//  Models.swift
//  NutritionTrackerV2
//
//  Shared model types, utilities, and protocol definitions
//

import Foundation

// MARK: - Protocol Definitions

/// Protocol for models that can be synced with remote storage
protocol Syncable {
    var id: UUID { get }
    var syncStatus: SyncStatus { get }
    var updatedAt: Date { get }
}

/// Protocol for models that can be soft-deleted
protocol SoftDeletable {
    var isDeleted: Bool { get }
    func markDeleted() -> Self
}

/// Protocol for models with timestamps
protocol Timestamped {
    var createdAt: Date { get }
    var updatedAt: Date { get }
}

// MARK: - Shared Types

/// Represents the status of data synchronization
enum SyncStatus: String, Codable, CaseIterable {
    case synced = "synced"
    case pending = "pending"
    case error = "error"
    case conflict = "conflict"

    var displayName: String {
        switch self {
        case .synced: return "Synced"
        case .pending: return "Pending Sync"
        case .error: return "Sync Error"
        case .conflict: return "Sync Conflict"
        }
    }

    var needsSync: Bool {
        return self == .pending || self == .error
    }
}

/// Represents different meal types throughout the day
enum MealType: String, Codable, CaseIterable {
    case breakfast = "breakfast"
    case lunch = "lunch"
    case dinner = "dinner"
    case snack = "snack"
    case preworkout = "pre_workout"
    case postworkout = "post_workout"
    case latenight = "late_night"
    case other = "other"

    var displayName: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch: return "Lunch"
        case .dinner: return "Dinner"
        case .snack: return "Snack"
        case .preworkout: return "Pre-Workout"
        case .postworkout: return "Post-Workout"
        case .latenight: return "Late Night"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "sunset.fill"
        case .snack: return "leaf.fill"
        case .preworkout: return "figure.run"
        case .postworkout: return "figure.cooldown"
        case .latenight: return "moon.fill"
        case .other: return "circle.fill"
        }
    }

    var color: String {
        switch self {
        case .breakfast: return "orange"
        case .lunch: return "yellow"
        case .dinner: return "purple"
        case .snack: return "green"
        case .preworkout: return "red"
        case .postworkout: return "blue"
        case .latenight: return "indigo"
        case .other: return "gray"
        }
    }

    /// Typical times for each meal type
    var typicalTime: (hour: Int, minute: Int) {
        switch self {
        case .breakfast: return (7, 0)
        case .lunch: return (12, 0)
        case .dinner: return (18, 0)
        case .snack: return (15, 0)
        case .preworkout: return (17, 0)
        case .postworkout: return (19, 30)
        case .latenight: return (21, 0)
        case .other: return (12, 0)
        }
    }
}

// MARK: - Error Types

/// Common errors that can occur in data operations
enum DataError: Error, LocalizedError {
    case notFound
    case invalidData
    case networkError
    case syncError
    case permissionDenied
    case quotaExceeded
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Requested data was not found"
        case .invalidData:
            return "The data provided is invalid"
        case .networkError:
            return "Network connection error"
        case .syncError:
            return "Failed to sync data"
        case .permissionDenied:
            return "Permission denied"
        case .quotaExceeded:
            return "Storage quota exceeded"
        case .unknown(let message):
            return message
        }
    }
}

// MARK: - Data Transfer Objects

/// Basic response wrapper for API calls
struct APIResponse<T: Codable>: Codable {
    let data: T?
    let message: String?
    let success: Bool
    let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case data
        case message
        case success
        case timestamp
    }
}

/// Pagination information for list responses
struct PaginationInfo: Codable {
    let page: Int
    let pageSize: Int
    let totalCount: Int
    let totalPages: Int
    let hasNext: Bool
    let hasPrevious: Bool

    enum CodingKeys: String, CodingKey {
        case page
        case pageSize = "page_size"
        case totalCount = "total_count"
        case totalPages = "total_pages"
        case hasNext = "has_next"
        case hasPrevious = "has_previous"
    }
}

/// Paginated list response
struct PaginatedResponse<T: Codable>: Codable {
    let items: [T]
    let pagination: PaginationInfo

    enum CodingKeys: String, CodingKey {
        case items
        case pagination
    }
}

// MARK: - Nutritional Data Types

/// Macronutrient breakdown
struct MacronutrientProfile: Codable, Hashable {
    let protein: Double
    let carbohydrates: Double
    let fat: Double
    let calories: Double

    /// Percentages of total calories
    var percentages: (protein: Double, carbs: Double, fat: Double) {
        let totalCalories = max(calories, 1) // Avoid division by zero
        let proteinCalories = protein * 4
        let carbCalories = carbohydrates * 4
        let fatCalories = fat * 9

        return (
            protein: (proteinCalories / totalCalories) * 100,
            carbs: (carbCalories / totalCalories) * 100,
            fat: (fatCalories / totalCalories) * 100
        )
    }

    /// Total calculated calories from macronutrients
    var calculatedCalories: Double {
        return (protein * 4) + (carbohydrates * 4) + (fat * 9)
    }
}

/// Micronutrient profile
struct MicronutrientProfile: Codable, Hashable {
    // Minerals (mg unless specified)
    let sodium: Double?
    let potassium: Double?
    let calcium: Double?
    let iron: Double?
    let magnesium: Double?
    let phosphorus: Double?
    let zinc: Double?

    // Vitamins
    let vitaminA: Double? // mcg
    let vitaminC: Double? // mg
    let vitaminD: Double? // mcg
    let vitaminE: Double? // mg
    let vitaminK: Double? // mcg
    let vitaminB1: Double? // mg (thiamin)
    let vitaminB2: Double? // mg (riboflavin)
    let vitaminB3: Double? // mg (niacin)
    let vitaminB6: Double? // mg
    let vitaminB12: Double? // mcg
    let folate: Double? // mcg

    enum CodingKeys: String, CodingKey {
        case sodium, potassium, calcium, iron, magnesium, phosphorus, zinc
        case vitaminA = "vitamin_a"
        case vitaminC = "vitamin_c"
        case vitaminD = "vitamin_d"
        case vitaminE = "vitamin_e"
        case vitaminK = "vitamin_k"
        case vitaminB1 = "vitamin_b1"
        case vitaminB2 = "vitamin_b2"
        case vitaminB3 = "vitamin_b3"
        case vitaminB6 = "vitamin_b6"
        case vitaminB12 = "vitamin_b12"
        case folate
    }
}

// MARK: - Utility Extensions

extension Date {
    /// Get the start of the day for this date
    var startOfDay: Date {
        return Calendar.current.startOfDay(for: self)
    }

    /// Get the end of the day for this date
    var endOfDay: Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay) ?? self
    }

    /// Check if this date is today
    var isToday: Bool {
        return Calendar.current.isDateInToday(self)
    }

    /// Check if this date is yesterday
    var isYesterday: Bool {
        return Calendar.current.isDateInYesterday(self)
    }

    /// Get a human-readable relative description
    var relativeDescription: String {
        if isToday {
            return "Today"
        } else if isYesterday {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: self)
        }
    }
}

extension UUID {
    /// Check if this UUID is nil/empty
    var isEmpty: Bool {
        return self.uuidString.isEmpty
    }
}

extension Double {
    /// Format as calories
    var formattedCalories: String {
        return "\(Int(rounded())) cal"
    }

    /// Format as grams
    var formattedGrams: String {
        if self < 1 {
            return String(format: "%.1fg", self)
        } else {
            return String(format: "%.0fg", self)
        }
    }

    /// Format as milligrams
    var formattedMilligrams: String {
        if self < 1 {
            return String(format: "%.1fmg", self)
        } else {
            return String(format: "%.0fmg", self)
        }
    }

    /// Format as micrograms
    var formattedMicrograms: String {
        if self < 1 {
            return String(format: "%.1fμg", self)
        } else {
            return String(format: "%.0fμg", self)
        }
    }
}

// MARK: - Collection Extensions

extension Array where Element: Identifiable {
    /// Find an element by its ID
    func first(withId id: Element.ID) -> Element? {
        return first { $0.id == id }
    }

    /// Remove an element by its ID
    mutating func removeFirst(withId id: Element.ID) {
        if let index = firstIndex(where: { $0.id == id }) {
            remove(at: index)
        }
    }
}

extension Array where Element: Syncable {
    /// Filter elements that need synchronization
    var needingSync: [Element] {
        return filter { $0.syncStatus.needsSync }
    }

    /// Filter elements that are successfully synced
    var synced: [Element] {
        return filter { $0.syncStatus == .synced }
    }
}

extension Array where Element: SoftDeletable {
    /// Filter out soft-deleted elements
    var active: [Element] {
        return filter { !$0.isDeleted }
    }

    /// Filter only soft-deleted elements
    var deleted: [Element] {
        return filter { $0.isDeleted }
    }
}

// MARK: - Result Extensions

extension Result {
    /// Check if the result is a success
    var isSuccess: Bool {
        switch self {
        case .success:
            return true
        case .failure:
            return false
        }
    }

    /// Check if the result is a failure
    var isFailure: Bool {
        return !isSuccess
    }

    /// Get the success value, if any
    var successValue: Success? {
        switch self {
        case .success(let value):
            return value
        case .failure:
            return nil
        }
    }

    /// Get the failure error, if any
    var failureError: Failure? {
        switch self {
        case .success:
            return nil
        case .failure(let error):
            return error
        }
    }
}