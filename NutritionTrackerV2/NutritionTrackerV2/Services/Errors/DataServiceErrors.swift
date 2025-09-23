//
//  DataServiceErrors.swift
//  NutritionTrackerV2
//
//  Comprehensive error handling system for data service operations
//

import Foundation
import Supabase

// MARK: - Main Data Service Error

/// Primary error type for all data service operations
enum DataServiceError: Error, LocalizedError, CustomStringConvertible {

    // MARK: - Network Errors
    case networkUnavailable
    case networkTimeout
    case networkConnectionLost
    case serverUnavailable
    case badRequest(String)
    case unauthorized
    case forbidden
    case notFound(String)
    case conflict(String)
    case internalServerError
    case serviceUnavailable
    case requestRateLimit

    // MARK: - Data Validation Errors
    case validationFailed([ValidationError])
    case invalidData(String)
    case missingRequiredField(String)
    case invalidFormat(field: String, expected: String)
    case valueTooLarge(field: String, max: Double)
    case valueTooSmall(field: String, min: Double)
    case duplicateEntry(String)
    case foreignKeyViolation(String)

    // MARK: - Authentication & Authorization Errors
    case authenticationRequired
    case authenticationFailed(String)
    case sessionExpired
    case insufficientPermissions
    case accountSuspended
    case emailNotVerified

    // MARK: - Parsing & Serialization Errors
    case jsonDecodingFailed(String)
    case jsonEncodingFailed(String)
    case dataCorrupted(String)
    case unexpectedDataFormat
    case missingResponseData

    // MARK: - Business Logic Errors
    case quotaExceeded(String)
    case featureNotAvailable
    case operationNotSupported
    case resourceLocked(String)
    case preconditionFailed(String)
    case businessRuleViolation(String)

    // MARK: - Sync & Offline Errors
    case syncConflict(String)
    case offlineModeUnavailable
    case dataOutOfSync
    case mergeConflict
    case checksumMismatch

    // MARK: - System Errors
    case memoryPressure
    case diskSpaceFull
    case databaseCorruption
    case configurationError(String)
    case unexpectedNil(String)
    case unknown(Error)

    // MARK: - LocalizedError Implementation

    var errorDescription: String? {
        switch self {
        // Network Errors
        case .networkUnavailable:
            return "Network is not available. Please check your connection."
        case .networkTimeout:
            return "Request timed out. Please try again."
        case .networkConnectionLost:
            return "Network connection was lost. Please check your connection."
        case .serverUnavailable:
            return "Server is temporarily unavailable. Please try again later."
        case .badRequest(let message):
            return "Invalid request: \(message)"
        case .unauthorized:
            return "Authentication required. Please sign in."
        case .forbidden:
            return "You don't have permission to perform this action."
        case .notFound(let resource):
            return "\(resource) was not found."
        case .conflict(let message):
            return "Conflict occurred: \(message)"
        case .internalServerError:
            return "Internal server error. Please try again later."
        case .serviceUnavailable:
            return "Service is temporarily unavailable."
        case .requestRateLimit:
            return "Too many requests. Please wait before trying again."

        // Data Validation Errors
        case .validationFailed(let errors):
            return "Validation failed: \(errors.map { $0.localizedDescription }.joined(separator: ", "))"
        case .invalidData(let details):
            return "Invalid data: \(details)"
        case .missingRequiredField(let field):
            return "Required field '\(field)' is missing."
        case .invalidFormat(let field, let expected):
            return "Field '\(field)' has invalid format. Expected: \(expected)"
        case .valueTooLarge(let field, let max):
            return "Value for '\(field)' is too large. Maximum: \(max)"
        case .valueTooSmall(let field, let min):
            return "Value for '\(field)' is too small. Minimum: \(min)"
        case .duplicateEntry(let details):
            return "Duplicate entry: \(details)"
        case .foreignKeyViolation(let details):
            return "Related data constraint violation: \(details)"

        // Authentication & Authorization Errors
        case .authenticationRequired:
            return "Authentication is required for this operation."
        case .authenticationFailed(let reason):
            return "Authentication failed: \(reason)"
        case .sessionExpired:
            return "Your session has expired. Please sign in again."
        case .insufficientPermissions:
            return "Insufficient permissions for this operation."
        case .accountSuspended:
            return "Your account has been suspended."
        case .emailNotVerified:
            return "Please verify your email address to continue."

        // Parsing & Serialization Errors
        case .jsonDecodingFailed(let details):
            return "Failed to decode data: \(details)"
        case .jsonEncodingFailed(let details):
            return "Failed to encode data: \(details)"
        case .dataCorrupted(let details):
            return "Data is corrupted: \(details)"
        case .unexpectedDataFormat:
            return "Unexpected data format received."
        case .missingResponseData:
            return "No data received from server."

        // Business Logic Errors
        case .quotaExceeded(let details):
            return "Quota exceeded: \(details)"
        case .featureNotAvailable:
            return "This feature is not available."
        case .operationNotSupported:
            return "Operation is not supported."
        case .resourceLocked(let resource):
            return "\(resource) is currently locked by another operation."
        case .preconditionFailed(let condition):
            return "Precondition failed: \(condition)"
        case .businessRuleViolation(let rule):
            return "Business rule violation: \(rule)"

        // Sync & Offline Errors
        case .syncConflict(let details):
            return "Sync conflict: \(details)"
        case .offlineModeUnavailable:
            return "Offline mode is not available for this operation."
        case .dataOutOfSync:
            return "Local data is out of sync. Please refresh."
        case .mergeConflict:
            return "Merge conflict detected. Manual resolution required."
        case .checksumMismatch:
            return "Data integrity check failed."

        // System Errors
        case .memoryPressure:
            return "Insufficient memory available."
        case .diskSpaceFull:
            return "Insufficient storage space."
        case .databaseCorruption:
            return "Database corruption detected."
        case .configurationError(let details):
            return "Configuration error: \(details)"
        case .unexpectedNil(let context):
            return "Unexpected nil value in \(context)"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }

    var failureReason: String? {
        switch self {
        case .networkUnavailable, .networkTimeout, .networkConnectionLost:
            return "Network connectivity issue"
        case .unauthorized, .authenticationRequired, .authenticationFailed:
            return "Authentication issue"
        case .validationFailed, .invalidData, .missingRequiredField:
            return "Data validation issue"
        case .jsonDecodingFailed, .jsonEncodingFailed, .dataCorrupted:
            return "Data parsing issue"
        case .serverUnavailable, .internalServerError:
            return "Server issue"
        default:
            return "Operation failed"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .networkUnavailable, .networkConnectionLost:
            return "Check your internet connection and try again."
        case .networkTimeout:
            return "The request took too long. Try again or check your connection."
        case .unauthorized, .authenticationRequired:
            return "Please sign in to continue."
        case .sessionExpired:
            return "Your session has expired. Please sign in again."
        case .requestRateLimit:
            return "Wait a few moments before trying again."
        case .serverUnavailable, .serviceUnavailable:
            return "The service is temporarily unavailable. Please try again later."
        case .validationFailed:
            return "Please correct the highlighted errors and try again."
        case .quotaExceeded:
            return "You have reached your usage limit. Consider upgrading your plan."
        case .dataOutOfSync:
            return "Pull to refresh the data and try again."
        case .memoryPressure:
            return "Close other apps to free up memory."
        case .diskSpaceFull:
            return "Free up storage space on your device."
        default:
            return "Please try again. If the problem persists, contact support."
        }
    }

    // MARK: - CustomStringConvertible Implementation

    var description: String {
        return errorDescription ?? "Unknown error"
    }

    // MARK: - Error Classification

    /// Whether this error suggests retrying the operation might succeed
    var isRetryable: Bool {
        switch self {
        case .networkTimeout, .networkConnectionLost, .serverUnavailable,
             .internalServerError, .serviceUnavailable, .requestRateLimit:
            return true
        case .unauthorized, .forbidden, .notFound, .validationFailed,
             .authenticationFailed, .duplicateEntry:
            return false
        default:
            return false
        }
    }

    /// Whether this error indicates a client-side issue
    var isClientError: Bool {
        switch self {
        case .validationFailed, .invalidData, .missingRequiredField,
             .invalidFormat, .valueTooLarge, .valueTooSmall,
             .jsonEncodingFailed, .badRequest:
            return true
        default:
            return false
        }
    }

    /// Whether this error indicates a server-side issue
    var isServerError: Bool {
        switch self {
        case .serverUnavailable, .internalServerError, .serviceUnavailable,
             .databaseCorruption, .configurationError:
            return true
        default:
            return false
        }
    }

    /// Whether this error indicates a network issue
    var isNetworkError: Bool {
        switch self {
        case .networkUnavailable, .networkTimeout, .networkConnectionLost:
            return true
        default:
            return false
        }
    }

    /// Error severity level
    var severity: ErrorSeverity {
        switch self {
        case .databaseCorruption, .memoryPressure, .diskSpaceFull:
            return .critical
        case .authenticationFailed, .sessionExpired, .dataCorrupted:
            return .high
        case .validationFailed, .networkTimeout, .syncConflict:
            return .medium
        case .requestRateLimit, .featureNotAvailable:
            return .low
        default:
            return .medium
        }
    }
}

// MARK: - Error Severity

enum ErrorSeverity: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
}

// MARK: - Validation Error

struct ValidationError: Error, LocalizedError, Hashable {
    let field: String
    let code: ValidationErrorCode
    let message: String
    let value: String?

    var errorDescription: String? {
        return "\(field): \(message)"
    }

    init(field: String, code: ValidationErrorCode, message: String, value: String? = nil) {
        self.field = field
        self.code = code
        self.message = message
        self.value = value
    }
}

enum ValidationErrorCode: String, CaseIterable {
    case required = "required"
    case invalidFormat = "invalid_format"
    case tooShort = "too_short"
    case tooLong = "too_long"
    case tooSmall = "too_small"
    case tooLarge = "too_large"
    case invalid = "invalid"
    case duplicate = "duplicate"
    case notFound = "not_found"
}

// MARK: - Error Factory

struct DataServiceErrorFactory {

    /// Create error from HTTP status code
    static func fromHTTPStatusCode(_ statusCode: Int, message: String = "") -> DataServiceError {
        switch statusCode {
        case 400:
            return .badRequest(message)
        case 401:
            return .unauthorized
        case 403:
            return .forbidden
        case 404:
            return .notFound(message.isEmpty ? "Resource" : message)
        case 409:
            return .conflict(message)
        case 429:
            return .requestRateLimit
        case 500:
            return .internalServerError
        case 503:
            return .serviceUnavailable
        default:
            return .unknown(NSError(domain: "HTTPError", code: statusCode, userInfo: [NSLocalizedDescriptionKey: message]))
        }
    }

    /// Create error from Supabase error
    static func fromSupabaseError(_ error: Error) -> DataServiceError {
        let errorDescription = error.localizedDescription.lowercased()

        // Network-related errors
        if errorDescription.contains("network") || errorDescription.contains("connection") {
            if errorDescription.contains("timeout") {
                return .networkTimeout
            } else if errorDescription.contains("lost") || errorDescription.contains("disconnected") {
                return .networkConnectionLost
            } else {
                return .networkUnavailable
            }
        }

        // Authentication errors
        if errorDescription.contains("unauthorized") || errorDescription.contains("authentication") {
            return .authenticationFailed(error.localizedDescription)
        }

        if errorDescription.contains("expired") && errorDescription.contains("session") {
            return .sessionExpired
        }

        // Validation errors
        if errorDescription.contains("validation") || errorDescription.contains("constraint") {
            return .validationFailed([ValidationError(field: "unknown", code: .invalid, message: error.localizedDescription)])
        }

        // Parsing errors
        if errorDescription.contains("json") || errorDescription.contains("decode") {
            return .jsonDecodingFailed(error.localizedDescription)
        }

        // Rate limiting
        if errorDescription.contains("rate") && errorDescription.contains("limit") {
            return .requestRateLimit
        }

        // Default to unknown
        return .unknown(error)
    }

    /// Create validation error for specific scenarios
    static func validationError(field: String, code: ValidationErrorCode, message: String, value: String? = nil) -> DataServiceError {
        let validationError = ValidationError(field: field, code: code, message: message, value: value)
        return .validationFailed([validationError])
    }

    /// Create multiple validation errors
    static func validationErrors(_ errors: [ValidationError]) -> DataServiceError {
        return .validationFailed(errors)
    }
}