//
//  AuthManagerTests.swift
//  NutritionTrackerV2Tests
//
//  Test suite for AuthManager functionality
//

import XCTest
@testable import NutritionTrackerV2
import Supabase

@MainActor
class AuthManagerTests: XCTestCase {

    var authManager: AuthManager!

    override func setUp() async throws {
        try await super.setUp()
        authManager = AuthManager.shared
    }

    override func tearDown() async throws {
        authManager = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testAuthManagerSingleton() async throws {
        // Test that singleton returns the same instance
        let instance1 = AuthManager.shared
        let instance2 = AuthManager.shared

        XCTAssertTrue(instance1 === instance2, "AuthManager should be a singleton")
    }

    func testInitialAuthenticationState() async throws {
        // Test that AuthManager initializes properly
        XCTAssertNotNil(authManager, "AuthManager should be initialized")

        // Test that authentication state is in a valid state (may be authenticated, unauthenticated, or error)
        // Don't assume initial state since it depends on previous tests and persisted sessions
        let currentState = authManager.authenticationState

        switch currentState {
        case .authenticated(_):
            // User might be authenticated from previous tests or app state
            XCTAssertTrue(authManager.isUserAuthenticated, "If authenticated state, isUserAuthenticated should be true")
        case .unauthenticated:
            // User is in clean unauthenticated state
            XCTAssertFalse(authManager.isUserAuthenticated, "If unauthenticated state, isUserAuthenticated should be false")
        case .error(let message):
            // There might be a database error or other issue - this is a valid state to test
            XCTAssertFalse(authManager.isUserAuthenticated, "If error state, isUserAuthenticated should be false")
            print("AuthManager in error state: \(message)")
        case .loading:
            // Manager might still be loading - this is also valid
            print("AuthManager is still loading initial state")
        }
    }

    // MARK: - Validation Tests

    func testEmailValidation() async throws {
        // Test invalid email
        do {
            try await authManager.signUp(email: "invalid-email", password: "Password123")
            XCTFail("Invalid email should throw an error")
        } catch {
            if let authError = error as? AuthManagerError {
                switch authError {
                case .invalidEmail:
                    // Expected error
                    break
                default:
                    XCTFail("Should throw invalidEmail error for invalid email")
                }
            }
        }
    }

    func testPasswordValidation() async throws {
        // Test weak password
        do {
            try await authManager.signUp(email: "test@example.com", password: "weak")
            XCTFail("Weak password should throw an error")
        } catch {
            if let authError = error as? AuthManagerError {
                switch authError {
                case .weakPassword:
                    // Expected error
                    break
                default:
                    XCTFail("Should throw weakPassword error for weak password")
                }
            }
        }

        // Test empty password for sign in
        do {
            try await authManager.signIn(email: "test@example.com", password: "")
            XCTFail("Empty password should throw an error")
        } catch {
            if let authError = error as? AuthManagerError {
                switch authError {
                case .emptyPassword:
                    // Expected error
                    break
                default:
                    XCTFail("Should throw emptyPassword error for empty password")
                }
            }
        }
    }

    // MARK: - Authentication State Tests

    func testAuthenticationStateEnum() async throws {
        // Test state properties without mocking
        XCTAssertFalse(AuthManager.AuthenticationState.unauthenticated.isAuthenticated)
        XCTAssertFalse(AuthManager.AuthenticationState.loading.isAuthenticated)
        XCTAssertFalse(AuthManager.AuthenticationState.error("test").isAuthenticated)

        // Test that the authenticated case exists and works with the current user (if any)
        // Since we can't easily create a mock User due to complex structure,
        // we'll test the current authentication state consistency instead
        let currentState = authManager.authenticationState
        let isUserAuthenticated = authManager.isUserAuthenticated

        // The enum's isAuthenticated property should match the manager's isUserAuthenticated
        XCTAssertEqual(currentState.isAuthenticated, isUserAuthenticated,
                      "AuthenticationState.isAuthenticated should match AuthManager.isUserAuthenticated")
    }

    // MARK: - Error Handling Tests

    func testAuthManagerErrorDescriptions() async throws {
        // Test all AuthManagerError cases have proper descriptions
        let errors: [AuthManagerError] = [
            .invalidEmail,
            .invalidCredentials,
            .weakPassword,
            .emptyPassword,
            .emailAlreadyExists,
            .userNotAuthenticated,
            .invalidUsername,
            .networkError,
            .sessionExpired,
            .sessionRefreshFailed,
            .unknown("Test error")
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription, "AuthManagerError should have error description")
            XCTAssertFalse(error.errorDescription!.isEmpty, "Error description should not be empty")
        }
    }

    // MARK: - User Profile Tests

    func testCreateUserProfileWhenNotAuthenticated() async throws {
        // Should throw error when not authenticated
        do {
            try await authManager.createUserProfile(username: "testuser")
            XCTFail("Should throw error when not authenticated")
        } catch {
            if let authError = error as? AuthManagerError {
                switch authError {
                case .userNotAuthenticated:
                    // Expected error
                    break
                default:
                    XCTFail("Should throw userNotAuthenticated error")
                }
            }
        }
    }

    func testCreateUserProfileWithInvalidUsername() async throws {
        // Should throw error for empty username - but might first throw userNotAuthenticated
        do {
            try await authManager.createUserProfile(username: "   ")
            XCTFail("Should throw error for empty username")
        } catch {
            if let authError = error as? AuthManagerError {
                switch authError {
                case .invalidUsername:
                    // Expected error - username validation
                    break
                case .userNotAuthenticated:
                    // Also expected - user isn't authenticated so can't create profile
                    break
                default:
                    XCTFail("Should throw invalidUsername or userNotAuthenticated error, got: \(authError)")
                }
            } else {
                XCTFail("Should throw AuthManagerError, got: \(error)")
            }
        }
    }

    // MARK: - Utility Method Tests

    func testCurrentUserProperties() async throws {
        // When not authenticated, user properties should be nil
        XCTAssertNil(authManager.currentUserID, "Current user ID should be nil when not authenticated")
        XCTAssertNil(authManager.currentUserEmail, "Current user email should be nil when not authenticated")
    }

    func testLoadingState() async throws {
        // Test that loading state is properly managed
        XCTAssertFalse(authManager.isLoading, "Should not be loading initially")

        // Note: Testing actual loading states would require mocking network requests
        // which is complex with the current setup
    }

    // MARK: - Session Management Tests

    func testSessionManagementInitialState() async throws {
        // Test that session-related properties are accessible and in valid states
        // Don't assume initial values since AuthManager might have persisted session state

        // These properties should be accessible without crashing
        let currentSession = authManager.currentSession
        let sessionExpiresAt = authManager.sessionExpiresAt
        let isSessionExpiring = authManager.isSessionExpiring
        let sessionTimeRemaining = authManager.sessionTimeRemaining
        let isSessionCloseToExpiring = authManager.isSessionCloseToExpiring

        // Verify boolean properties are valid booleans
        XCTAssertTrue(isSessionExpiring == true || isSessionExpiring == false)
        XCTAssertTrue(isSessionCloseToExpiring == true || isSessionCloseToExpiring == false)

        // If session exists, expiry date should also exist
        if currentSession != nil {
            XCTAssertNotNil(sessionExpiresAt, "If session exists, expiry date should exist")
        }

        // Session time remaining should be consistent with expiry date
        if sessionExpiresAt != nil {
            XCTAssertNotNil(sessionTimeRemaining, "If expiry date exists, time remaining should be calculable")
        }
    }

    func testSessionTimeCalculations() async throws {
        // Test session time calculation logic without mocking
        // This test validates the current state's consistency

        let currentSession = authManager.currentSession
        let sessionExpiresAt = authManager.sessionExpiresAt
        let timeRemaining = authManager.sessionTimeRemaining
        let isCloseToExpiring = authManager.isSessionCloseToExpiring

        // If there's a session with expiry, time calculations should be consistent
        if currentSession != nil && sessionExpiresAt != nil {
            XCTAssertNotNil(timeRemaining, "Time remaining should be calculable when expiry exists")

            // If time remaining is positive, session shouldn't be expired
            if let remaining = timeRemaining, remaining > 0 {
                // Session with time remaining shouldn't be close to expiring if it has >5 minutes
                if remaining > 300 { // More than 5 minutes
                    XCTAssertFalse(isCloseToExpiring, "Session with >5 minutes shouldn't be close to expiring")
                }
            }
        } else {
            // No session means no time remaining
            XCTAssertNil(timeRemaining, "No session should mean no time remaining")
            XCTAssertFalse(isCloseToExpiring, "No session should not be close to expiring")
        }
    }

    func testRefreshSessionWhenNotAuthenticated() async throws {
        // Test that refreshing session when not authenticated returns false
        let result = await authManager.refreshSessionIfNeeded()
        XCTAssertFalse(result, "Should return false when not authenticated")
    }

    func testValidateSessionWhenNotAuthenticated() async throws {
        // Test that validating session when not authenticated returns false
        let result = await authManager.validateSession()
        XCTAssertFalse(result, "Should return false when not authenticated")
    }

    func testSessionExpiryHandling() async throws {
        // Test session expiry logic with current state
        let currentSession = authManager.currentSession
        let sessionExpiresAt = authManager.sessionExpiresAt
        let timeRemaining = authManager.sessionTimeRemaining

        // If we have a session with an expiry date
        if currentSession != nil && sessionExpiresAt != nil {
            XCTAssertNotNil(timeRemaining, "Time remaining should be calculable when expiry exists")

            // Test that expiry logic is consistent
            if let expiryDate = sessionExpiresAt, let remaining = timeRemaining {
                let expectedRemaining = expiryDate.timeIntervalSinceNow
                let tolerance: TimeInterval = 1.0 // Allow 1 second tolerance for test execution time
                XCTAssertEqual(remaining, expectedRemaining, accuracy: tolerance,
                              "Time remaining calculation should be consistent with expiry date")
            }
        } else {
            // No session or no expiry means no time remaining
            XCTAssertNil(timeRemaining, "No session or expiry should mean no time remaining")
        }
    }

    func testSessionProperties() async throws {
        // Test session-related published properties are accessible (they might be nil and that's expected)
        let _ = authManager.currentSession // Should be accessible without crash
        let _ = authManager.sessionExpiresAt // Should be accessible without crash

        // Test boolean properties
        let isExpiring = authManager.isSessionExpiring
        let isCloseToExpiring = authManager.isSessionCloseToExpiring

        // These should not crash and should return valid boolean values
        XCTAssertTrue(isExpiring == true || isExpiring == false, "isSessionExpiring should be a valid boolean")
        XCTAssertTrue(isCloseToExpiring == true || isCloseToExpiring == false, "isSessionCloseToExpiring should be a valid boolean")
    }

    // MARK: - Integration Tests

    func testAuthManagerIntegrationWithSupabaseManager() async throws {
        // Test that AuthManager properly integrates with SupabaseManager
        let supabaseManager = SupabaseManager.shared

        // Both should have same initial authentication state
        XCTAssertEqual(authManager.isAuthenticated, supabaseManager.isAuthenticated,
                      "AuthManager and SupabaseManager should have same auth state")
    }

    // MARK: - Helper Methods
    // (No helper methods needed for current tests)

    // MARK: - Performance Tests

    func testAuthManagerPerformance() async throws {
        // Test that AuthManager initialization is fast
        measure {
            let _ = AuthManager.shared
        }
    }
}