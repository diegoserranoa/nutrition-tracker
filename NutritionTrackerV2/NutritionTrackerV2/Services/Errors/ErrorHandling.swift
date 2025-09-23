//
//  ErrorHandling.swift
//  NutritionTrackerV2
//
//  Error handling protocols and utilities for data service operations
//

import Foundation
import Combine
import OSLog
import UIKit

// MARK: - Error Handling Protocols

/// Protocol for types that can handle errors gracefully
protocol ErrorHandleable {
    func handleError(_ error: DataServiceError) -> ErrorHandlingAction
}

/// Protocol for types that can retry failed operations
protocol Retryable {
    var maxRetryAttempts: Int { get }
    var retryDelay: TimeInterval { get }
    func shouldRetry(error: DataServiceError, attempt: Int) -> Bool
}

/// Protocol for types that can report errors for analytics/debugging
protocol ErrorReportable {
    func reportError(_ error: DataServiceError, context: ErrorContext)
}

// MARK: - Error Handling Action

enum ErrorHandlingAction {
    case retry(after: TimeInterval)
    case retryWithBackoff(multiplier: Double)
    case showUserMessage(String)
    case showUserAlert(title: String, message: String)
    case redirectToLogin
    case fallbackToOffline
    case ignore
    case propagate
}

// MARK: - Error Context

struct ErrorContext: Codable {
    let operation: String
    let userId: String?
    let timestamp: Date
    let metadata: [String: String]

    init(operation: String, userId: String? = nil, metadata: [String: String] = [:]) {
        self.operation = operation
        self.userId = userId
        self.timestamp = Date()
        self.metadata = metadata
    }
}

// MARK: - Error Handler

@MainActor
class ErrorHandler: ObservableObject, ErrorHandleable, ErrorReportable, @unchecked Sendable {

    // MARK: - Published Properties
    @Published var currentError: DataServiceError?
    @Published var isShowingError: Bool = false
    @Published var errorMessage: String = ""
    @Published var errorTitle: String = ""

    // MARK: - Private Properties
    private let logger = Logger(subsystem: "com.nutritiontracker.dataservice", category: "ErrorHandler")
    private var errorReportingEnabled: Bool = true

    // MARK: - Singleton
    nonisolated static let shared = ErrorHandler()

    nonisolated private init() {}

    // MARK: - Error Handling

    nonisolated func handleError(_ error: DataServiceError) -> ErrorHandlingAction {
        logger.error("Handling error: \(error.description)")

        // Report error for analytics
        let context = ErrorContext(operation: "data_service_operation")
        reportError(error, context: context)

        // Update UI state on main actor
        Task { @MainActor in
            currentError = error
            errorTitle = error.failureReason ?? "Error"
            errorMessage = error.errorDescription ?? "An unknown error occurred"
        }

        // Determine handling action based on error type
        let title = error.failureReason ?? "Error"
        let message = error.errorDescription ?? "An unknown error occurred"

        switch error {
        case .networkUnavailable, .networkConnectionLost:
            return .showUserMessage("Check your internet connection")

        case .networkTimeout:
            if error.isRetryable {
                return .retry(after: 2.0)
            }
            return .showUserMessage("Request timed out")

        case .unauthorized, .authenticationRequired, .sessionExpired:
            return .redirectToLogin

        case .requestRateLimit:
            return .retry(after: 5.0)

        case .validationFailed:
            return .showUserAlert(title: "Validation Error", message: error.errorDescription ?? "Please check your input")

        case .serverUnavailable, .serviceUnavailable:
            return .fallbackToOffline

        case .quotaExceeded:
            return .showUserAlert(title: "Quota Exceeded", message: error.errorDescription ?? "Usage limit reached")

        case .featureNotAvailable:
            return .showUserMessage("Feature not available")

        default:
            if error.isRetryable {
                return .retryWithBackoff(multiplier: 1.5)
            }
            return .showUserAlert(title: title, message: message)
        }
    }

    nonisolated func reportError(_ error: DataServiceError, context: ErrorContext) {
        logger.error("Error reported - Operation: \(context.operation), Error: \(error.description)")

        // In a production app, this would send to analytics service
        let errorReport = ErrorReport(
            error: error,
            context: context,
            severity: error.severity,
            deviceInfo: DeviceInfo.current
        )

        // Store for local debugging on main actor
        Task { @MainActor in
            guard errorReportingEnabled else { return }
            storeErrorReport(errorReport)
        }
    }

    // MARK: - UI Helper Methods

    func showError(_ error: DataServiceError) {
        currentError = error
        errorTitle = error.failureReason ?? "Error"
        errorMessage = error.errorDescription ?? "An unknown error occurred"
        isShowingError = true
    }

    func clearError() {
        currentError = nil
        isShowingError = false
        errorMessage = ""
        errorTitle = ""
    }

    func toggleErrorReporting(_ enabled: Bool) {
        errorReportingEnabled = enabled
    }

    // MARK: - Private Methods

    private func storeErrorReport(_ report: ErrorReport) {
        // Store error report locally for debugging
        // In production, this might send to a crash reporting service
        logger.debug("Stored error report: \(report.id)")
    }
}

// MARK: - Retry Handler

class RetryHandler: Retryable {
    let maxRetryAttempts: Int
    let retryDelay: TimeInterval
    private let backoffMultiplier: Double

    init(maxRetryAttempts: Int = 3, retryDelay: TimeInterval = 1.0, backoffMultiplier: Double = 2.0) {
        self.maxRetryAttempts = maxRetryAttempts
        self.retryDelay = retryDelay
        self.backoffMultiplier = backoffMultiplier
    }

    func shouldRetry(error: DataServiceError, attempt: Int) -> Bool {
        guard attempt < maxRetryAttempts else { return false }
        return error.isRetryable
    }

    func calculateDelay(for attempt: Int) -> TimeInterval {
        return retryDelay * pow(backoffMultiplier, Double(attempt))
    }

    /// Retry an async operation with exponential backoff
    func retry<T>(
        operation: @escaping () async throws -> T,
        errorHandler: ErrorHandler? = nil
    ) async throws -> T {
        var lastError: DataServiceError?

        for attempt in 0..<maxRetryAttempts {
            do {
                return try await operation()
            } catch let error as DataServiceError {
                lastError = error

                guard shouldRetry(error: error, attempt: attempt) else {
                    throw error
                }

                if attempt < maxRetryAttempts - 1 {
                    let delay = calculateDelay(for: attempt)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            } catch {
                // Convert non-DataServiceError to DataServiceError
                let dataServiceError = DataServiceErrorFactory.fromSupabaseError(error)
                lastError = dataServiceError

                guard shouldRetry(error: dataServiceError, attempt: attempt) else {
                    throw dataServiceError
                }

                if attempt < maxRetryAttempts - 1 {
                    let delay = calculateDelay(for: attempt)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        throw lastError ?? DataServiceError.unknown(NSError(domain: "RetryHandler", code: -1, userInfo: nil))
    }
}

// MARK: - Error Report

struct ErrorReport: Identifiable {
    let id: UUID
    let error: DataServiceError
    let context: ErrorContext
    let severity: ErrorSeverity
    let deviceInfo: DeviceInfo
    let timestamp: Date

    init(error: DataServiceError, context: ErrorContext, severity: ErrorSeverity, deviceInfo: DeviceInfo) {
        self.id = UUID()
        self.error = error
        self.context = context
        self.severity = severity
        self.deviceInfo = deviceInfo
        self.timestamp = Date()
    }
}

// MARK: - Device Info

struct DeviceInfo: Codable {
    let deviceModel: String
    let osVersion: String
    let appVersion: String
    let locale: String

    static var current: DeviceInfo {
        DeviceInfo(
            deviceModel: UIDevice.current.model,
            osVersion: UIDevice.current.systemVersion,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            locale: Locale.current.identifier
        )
    }
}

// MARK: - Result Extensions for Error Handling

extension Result {
    /// Handle errors using the error handler
    func handleError(with handler: ErrorHandler? = nil) -> Success? {
        switch self {
        case .success(let value):
            return value
        case .failure(let error):
            let errorHandler = handler ?? ErrorHandler.shared
            if let dataServiceError = error as? DataServiceError {
                _ = errorHandler.handleError(dataServiceError)
            } else {
                let dataServiceError = DataServiceErrorFactory.fromSupabaseError(error)
                _ = errorHandler.handleError(dataServiceError)
            }
            return nil
        }
    }

    /// Convert errors to DataServiceError
    func mapToDataServiceError() -> Result<Success, DataServiceError> {
        switch self {
        case .success(let value):
            return .success(value)
        case .failure(let error):
            if let dataServiceError = error as? DataServiceError {
                return .failure(dataServiceError)
            } else {
                return .failure(DataServiceErrorFactory.fromSupabaseError(error))
            }
        }
    }
}

// MARK: - Async Extensions

extension Task where Failure == Error {
    /// Create a task with built-in error handling
    static func withErrorHandling<T>(
        priority: TaskPriority? = nil,
        errorHandler: ErrorHandler? = nil,
        operation: @escaping () async throws -> T
    ) -> Task<T?, Never> {
        return Task<T?, Never>(priority: priority) {
            let handler = errorHandler ?? ErrorHandler.shared
            do {
                return try await operation()
            } catch let error as DataServiceError {
                _ = handler.handleError(error)
                return nil
            } catch {
                let dataServiceError = DataServiceErrorFactory.fromSupabaseError(error)
                _ = handler.handleError(dataServiceError)
                return nil
            }
        }
    }
}

// MARK: - Publisher Extensions

extension Publisher {
    /// Handle errors in a Combine pipeline
    func handleErrors(with handler: ErrorHandler? = nil) -> AnyPublisher<Output?, Never> {
        return self
            .map { Optional($0) }
            .catch { error -> Just<Output?> in
                let dataServiceError: DataServiceError
                if let dsError = error as? DataServiceError {
                    dataServiceError = dsError
                } else {
                    dataServiceError = DataServiceErrorFactory.fromSupabaseError(error)
                }

                let errorHandler = handler ?? ErrorHandler.shared
                _ = errorHandler.handleError(dataServiceError)
                return Just(nil)
            }
            .eraseToAnyPublisher()
    }

    /// Retry with exponential backoff
    func retryWithBackoff(
        maxAttempts: Int = 3,
        delay: TimeInterval = 1.0,
        multiplier: Double = 2.0
    ) -> AnyPublisher<Output, Failure> {
        return self.catch { error -> AnyPublisher<Output, Failure> in
            let dataServiceError: DataServiceError
            if let dsError = error as? DataServiceError {
                dataServiceError = dsError
            } else {
                dataServiceError = DataServiceErrorFactory.fromSupabaseError(error)
            }

            guard dataServiceError.isRetryable && maxAttempts > 0 else {
                return Fail(error: error).eraseToAnyPublisher()
            }

            return self
                .delay(for: .seconds(delay), scheduler: DispatchQueue.global())
                .retryWithBackoff(maxAttempts: maxAttempts - 1, delay: delay * multiplier, multiplier: multiplier)
                .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }
}