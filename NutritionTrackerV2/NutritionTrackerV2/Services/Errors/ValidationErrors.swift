//
//  ValidationErrors.swift
//  NutritionTrackerV2
//
//  Comprehensive validation system for data models
//

import Foundation

// MARK: - Validation Protocol

protocol Validatable {
    func validate() throws
    var validationErrors: [ValidationError] { get }
}

// MARK: - Validator

struct Validator {

    // MARK: - String Validations

    static func validateRequired(_ value: String?, field: String) throws {
        guard let value = value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DataServiceError.validationFailed([
                ValidationError(field: field, code: .required, message: "This field is required")
            ])
        }
    }

    static func validateEmail(_ email: String?, field: String = "email") throws {
        guard let email = email else {
            throw DataServiceError.validationFailed([
                ValidationError(field: field, code: .required, message: "Email is required")
            ])
        }

        let emailRegex = "^[\\w\\.-]+@([\\w\\-]+\\.)+[A-Z]{1,4}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES[c] %@", emailRegex)

        guard emailPredicate.evaluate(with: email) else {
            throw DataServiceError.validationFailed([
                ValidationError(field: field, code: .invalidFormat, message: "Please enter a valid email address", value: email)
            ])
        }
    }

    static func validateMinLength(_ value: String?, minLength: Int, field: String) throws {
        guard let value = value else {
            throw DataServiceError.validationFailed([
                ValidationError(field: field, code: .required, message: "This field is required")
            ])
        }

        guard value.count >= minLength else {
            throw DataServiceError.validationFailed([
                ValidationError(field: field, code: .tooShort, message: "Must be at least \(minLength) characters long", value: value)
            ])
        }
    }

    static func validateMaxLength(_ value: String?, maxLength: Int, field: String) throws {
        guard let value = value else { return }

        guard value.count <= maxLength else {
            throw DataServiceError.validationFailed([
                ValidationError(field: field, code: .tooLong, message: "Must be no more than \(maxLength) characters long", value: value)
            ])
        }
    }

    static func validateUsername(_ username: String?, field: String = "username") throws {
        guard let username = username else {
            throw DataServiceError.validationFailed([
                ValidationError(field: field, code: .required, message: "Username is required")
            ])
        }

        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmed.count >= 3 else {
            throw DataServiceError.validationFailed([
                ValidationError(field: field, code: .tooShort, message: "Username must be at least 3 characters long", value: username)
            ])
        }

        guard trimmed.count <= 30 else {
            throw DataServiceError.validationFailed([
                ValidationError(field: field, code: .tooLong, message: "Username must be no more than 30 characters long", value: username)
            ])
        }

        let usernameRegex = "^[a-zA-Z0-9_-]+$"
        let usernamePredicate = NSPredicate(format: "SELF MATCHES %@", usernameRegex)

        guard usernamePredicate.evaluate(with: trimmed) else {
            throw DataServiceError.validationFailed([
                ValidationError(field: field, code: .invalidFormat, message: "Username can only contain letters, numbers, hyphens, and underscores", value: username)
            ])
        }
    }

    static func validatePassword(_ password: String?, field: String = "password") throws {
        guard let password = password else {
            throw DataServiceError.validationFailed([
                ValidationError(field: field, code: .required, message: "Password is required")
            ])
        }

        var errors: [ValidationError] = []

        if password.count < 8 {
            errors.append(ValidationError(field: field, code: .tooShort, message: "Password must be at least 8 characters long"))
        }

        if password.range(of: ".*[A-Za-z]+.*", options: .regularExpression) == nil {
            errors.append(ValidationError(field: field, code: .invalidFormat, message: "Password must contain at least one letter"))
        }

        if password.range(of: ".*[0-9]+.*", options: .regularExpression) == nil {
            errors.append(ValidationError(field: field, code: .invalidFormat, message: "Password must contain at least one number"))
        }

        if !errors.isEmpty {
            throw DataServiceError.validationFailed(errors)
        }
    }

    // MARK: - Numeric Validations

    static func validateRange<T: Comparable>(_ value: T?, min: T?, max: T?, field: String) throws {
        guard let value = value else {
            throw DataServiceError.validationFailed([
                ValidationError(field: field, code: .required, message: "This field is required")
            ])
        }

        if let min = min, value < min {
            throw DataServiceError.validationFailed([
                ValidationError(field: field, code: .tooSmall, message: "Value must be at least \(min)", value: "\(value)")
            ])
        }

        if let max = max, value > max {
            throw DataServiceError.validationFailed([
                ValidationError(field: field, code: .tooLarge, message: "Value must be at most \(max)", value: "\(value)")
            ])
        }
    }

    static func validatePositive(_ value: Double?, field: String) throws {
        guard let value = value else {
            throw DataServiceError.validationFailed([
                ValidationError(field: field, code: .required, message: "This field is required")
            ])
        }

        guard value > 0 else {
            throw DataServiceError.validationFailed([
                ValidationError(field: field, code: .tooSmall, message: "Value must be positive", value: "\(value)")
            ])
        }
    }

    static func validateNonNegative(_ value: Double?, field: String) throws {
        guard let value = value else {
            throw DataServiceError.validationFailed([
                ValidationError(field: field, code: .required, message: "This field is required")
            ])
        }

        guard value >= 0 else {
            throw DataServiceError.validationFailed([
                ValidationError(field: field, code: .tooSmall, message: "Value cannot be negative", value: "\(value)")
            ])
        }
    }

    // MARK: - Date Validations

    static func validateDateRange(_ date: Date?, min: Date?, max: Date?, field: String) throws {
        guard let date = date else {
            throw DataServiceError.validationFailed([
                ValidationError(field: field, code: .required, message: "Date is required")
            ])
        }

        if let min = min, date < min {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            throw DataServiceError.validationFailed([
                ValidationError(field: field, code: .tooSmall, message: "Date must be after \(formatter.string(from: min))")
            ])
        }

        if let max = max, date > max {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            throw DataServiceError.validationFailed([
                ValidationError(field: field, code: .tooLarge, message: "Date must be before \(formatter.string(from: max))")
            ])
        }
    }

    static func validateAge(_ birthDate: Date?, minAge: Int = 13, maxAge: Int = 120, field: String = "dateOfBirth") throws {
        guard let birthDate = birthDate else {
            throw DataServiceError.validationFailed([
                ValidationError(field: field, code: .required, message: "Date of birth is required")
            ])
        }

        let calendar = Calendar.current
        let now = Date()
        let ageComponents = calendar.dateComponents([.year], from: birthDate, to: now)

        guard let age = ageComponents.year else {
            throw DataServiceError.validationFailed([
                ValidationError(field: field, code: .invalid, message: "Invalid date of birth")
            ])
        }

        guard age >= minAge else {
            throw DataServiceError.validationFailed([
                ValidationError(field: field, code: .tooSmall, message: "Must be at least \(minAge) years old")
            ])
        }

        guard age <= maxAge else {
            throw DataServiceError.validationFailed([
                ValidationError(field: field, code: .tooLarge, message: "Age cannot exceed \(maxAge) years")
            ])
        }
    }

    // MARK: - Collection Validations

    static func validateNotEmpty<T>(_ collection: [T]?, field: String) throws {
        guard let collection = collection, !collection.isEmpty else {
            throw DataServiceError.validationFailed([
                ValidationError(field: field, code: .required, message: "At least one item is required")
            ])
        }
    }

    static func validateMaxCount<T>(_ collection: [T]?, maxCount: Int, field: String) throws {
        guard let collection = collection else { return }

        guard collection.count <= maxCount else {
            throw DataServiceError.validationFailed([
                ValidationError(field: field, code: .tooLarge, message: "Cannot have more than \(maxCount) items")
            ])
        }
    }

    // MARK: - Combined Validations

    static func validateMultiple(_ validations: [() throws -> Void]) throws {
        var allErrors: [ValidationError] = []

        for validation in validations {
            do {
                try validation()
            } catch let error as DataServiceError {
                if case .validationFailed(let errors) = error {
                    allErrors.append(contentsOf: errors)
                }
            }
        }

        if !allErrors.isEmpty {
            throw DataServiceError.validationFailed(allErrors)
        }
    }
}

// MARK: - Model Validations

extension Food: Validatable {
    func validate() throws {
        try Validator.validateMultiple([
            { try Validator.validateRequired(self.name, field: "name") },
            { try Validator.validateMaxLength(self.name, maxLength: 100, field: "name") },
            { try Validator.validateNonNegative(self.calories, field: "calories") },
            { try Validator.validateNonNegative(self.protein, field: "protein") },
            { try Validator.validateNonNegative(self.carbohydrates, field: "carbohydrates") },
            { try Validator.validateNonNegative(self.fat, field: "fat") },
            { try Validator.validatePositive(self.servingSize, field: "servingSize") },
            { try Validator.validateRequired(self.servingUnit, field: "servingUnit") }
        ])

        // Validate nutritional consistency
        if !hasConsistentMacronutrients {
            throw DataServiceError.validationFailed([
                ValidationError(field: "macronutrients", code: .invalid, message: "Macronutrient calories don't match total calories")
            ])
        }

        // Validate optional micronutrients are non-negative
        if let sodium = sodium, sodium < 0 {
            throw DataServiceError.validationFailed([
                ValidationError(field: "sodium", code: .tooSmall, message: "Sodium cannot be negative")
            ])
        }

        if let fiber = fiber, fiber < 0 {
            throw DataServiceError.validationFailed([
                ValidationError(field: "fiber", code: .tooSmall, message: "Fiber cannot be negative")
            ])
        }
    }

    var validationErrors: [ValidationError] {
        do {
            try validate()
            return []
        } catch let error as DataServiceError {
            if case .validationFailed(let errors) = error {
                return errors
            }
            return []
        } catch {
            return []
        }
    }
}

extension FoodLog: Validatable {
    func validate() throws {
        try Validator.validateMultiple([
            { try Validator.validatePositive(self.quantity, field: "quantity") },
            { try Validator.validateRequired(self.unit, field: "unit") },
            { try Validator.validateMaxLength(self.unit, maxLength: 50, field: "unit") }
        ])

        // Validate UUID fields are not empty
        if userId.uuidString.isEmpty {
            throw DataServiceError.validationFailed([
                ValidationError(field: "userId", code: .required, message: "User ID is required")
            ])
        }

        if foodId.uuidString.isEmpty {
            throw DataServiceError.validationFailed([
                ValidationError(field: "foodId", code: .required, message: "Food ID is required")
            ])
        }

        // Validate optional total grams
        if let totalGrams = totalGrams, totalGrams <= 0 {
            throw DataServiceError.validationFailed([
                ValidationError(field: "totalGrams", code: .tooSmall, message: "Total grams must be positive")
            ])
        }

        // Validate dates
        if loggedAt > Date() {
            throw DataServiceError.validationFailed([
                ValidationError(field: "loggedAt", code: .invalid, message: "Cannot log food in the future")
            ])
        }

        // Validate logged date is not too far in the past (e.g., more than 1 year)
        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        if loggedAt < oneYearAgo {
            throw DataServiceError.validationFailed([
                ValidationError(field: "loggedAt", code: .tooSmall, message: "Cannot log food more than 1 year in the past")
            ])
        }
    }

    var validationErrors: [ValidationError] {
        do {
            try validate()
            return []
        } catch let error as DataServiceError {
            if case .validationFailed(let errors) = error {
                return errors
            }
            return []
        } catch {
            return []
        }
    }
}

extension Profile: Validatable {
    func validate() throws {
        try Validator.validateMultiple([
            { try Validator.validateUsername(self.username, field: "username") },
            { if let email = self.email { try Validator.validateEmail(email, field: "email") } },
            { if let firstName = self.firstName { try Validator.validateMaxLength(firstName, maxLength: 50, field: "firstName") } },
            { if let lastName = self.lastName { try Validator.validateMaxLength(lastName, maxLength: 50, field: "lastName") } }
        ])

        // Validate physical characteristics
        if let height = height {
            try Validator.validateRange(height, min: 50.0, max: 300.0, field: "height") // cm
        }

        if let weight = weight {
            try Validator.validateRange(weight, min: 1.0, max: 1000.0, field: "weight") // kg
        }

        // Validate age if date of birth is provided
        if let dateOfBirth = dateOfBirth {
            try Validator.validateAge(dateOfBirth, field: "dateOfBirth")
        }

        // Validate nutrition goals
        if let calorieGoal = dailyCalorieGoal {
            try Validator.validateRange(calorieGoal, min: 500.0, max: 10000.0, field: "dailyCalorieGoal")
        }

        if let proteinGoal = dailyProteinGoal {
            try Validator.validateRange(proteinGoal, min: 10.0, max: 500.0, field: "dailyProteinGoal")
        }

        if let carbGoal = dailyCarbGoal {
            try Validator.validateNonNegative(carbGoal, field: "dailyCarbGoal")
        }

        if let fatGoal = dailyFatGoal {
            try Validator.validateNonNegative(fatGoal, field: "dailyFatGoal")
        }

        // Validate arrays
        try Validator.validateMaxCount(dietaryRestrictions, maxCount: 10, field: "dietaryRestrictions")
        try Validator.validateMaxCount(allergies, maxCount: 20, field: "allergies")
    }

    var validationErrors: [ValidationError] {
        do {
            try validate()
            return []
        } catch let error as DataServiceError {
            if case .validationFailed(let errors) = error {
                return errors
            }
            return []
        } catch {
            return []
        }
    }
}

// MARK: - Validation Utilities

struct ValidationUtilities {

    /// Check if a model is valid without throwing
    static func isValid<T: Validatable>(_ model: T) -> Bool {
        return model.validationErrors.isEmpty
    }

    /// Get all validation errors for multiple models
    static func getAllErrors<T: Validatable>(_ models: [T]) -> [ValidationError] {
        return models.flatMap { $0.validationErrors }
    }

    /// Validate multiple models and throw if any are invalid
    static func validateAll<T: Validatable>(_ models: [T]) throws {
        let allErrors = getAllErrors(models)
        if !allErrors.isEmpty {
            throw DataServiceError.validationFailed(allErrors)
        }
    }

    /// Create a validation summary for UI display
    static func createValidationSummary<T: Validatable>(_ model: T) -> ValidationSummary {
        let errors = model.validationErrors
        return ValidationSummary(
            isValid: errors.isEmpty,
            errorCount: errors.count,
            errors: errors,
            summary: errors.isEmpty ? "Valid" : "\(errors.count) validation error(s)"
        )
    }
}

// MARK: - Validation Summary

struct ValidationSummary {
    let isValid: Bool
    let errorCount: Int
    let errors: [ValidationError]
    let summary: String

    var errorsByField: [String: [ValidationError]] {
        return Dictionary(grouping: errors, by: { $0.field })
    }

    var fieldNames: [String] {
        return Array(errorsByField.keys).sorted()
    }
}