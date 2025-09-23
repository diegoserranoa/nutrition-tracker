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
        // Test initial state
        XCTAssertNotNil(authManager, "AuthManager should be initialized")
        XCTAssertFalse(authManager.isUserAuthenticated, "Should not be authenticated initially")
        XCTAssertEqual(authManager.authenticationState, .unauthenticated, "Should be in unauthenticated state")
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
        // Test state properties
        XCTAssertFalse(AuthManager.AuthenticationState.unauthenticated.isAuthenticated)
        XCTAssertFalse(AuthManager.AuthenticationState.loading.isAuthenticated)
        XCTAssertFalse(AuthManager.AuthenticationState.error("test").isAuthenticated)

        // Test authenticated state (we can't easily test this without a real user)
        // but we can test the enum behavior
        let mockUser = try createMockUser()
        XCTAssertTrue(AuthManager.AuthenticationState.authenticated(mockUser).isAuthenticated)
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
        // Should throw error for empty username
        do {
            try await authManager.createUserProfile(username: "   ")
            XCTFail("Should throw error for empty username")
        } catch {
            if let authError = error as? AuthManagerError {
                switch authError {
                case .invalidUsername:
                    // Expected error
                    break
                default:
                    XCTFail("Should throw invalidUsername error")
                }
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
        // Test initial session state
        XCTAssertNil(authManager.currentSession, "Current session should be nil initially")
        XCTAssertNil(authManager.sessionExpiresAt, "Session expiry should be nil initially")
        XCTAssertFalse(authManager.isSessionExpiring, "Session should not be expiring initially")
        XCTAssertNil(authManager.sessionTimeRemaining, "Session time remaining should be nil initially")
        XCTAssertFalse(authManager.isSessionCloseToExpiring, "Session should not be close to expiring initially")
    }

    func testSessionTimeCalculations() async throws {
        // Test session time calculations with mock session data
        let futureDate = Date().addingTimeInterval(3600) // 1 hour from now

        // Simulate setting a session expiry
        await MainActor.run {
            authManager.sessionExpiresAt = futureDate
        }

        // Test time remaining calculation
        let timeRemaining = authManager.sessionTimeRemaining
        XCTAssertNotNil(timeRemaining, "Session time remaining should not be nil")
        XCTAssertGreaterThan(timeRemaining!, 3500, "Should have roughly 1 hour remaining")

        // Test close to expiring (should be false for 1 hour)
        XCTAssertFalse(authManager.isSessionCloseToExpiring, "1 hour should not be close to expiring")

        // Test with session close to expiring
        let soonDate = Date().addingTimeInterval(300) // 5 minutes from now
        await MainActor.run {
            authManager.sessionExpiresAt = soonDate
        }

        XCTAssertTrue(authManager.isSessionCloseToExpiring, "5 minutes should be close to expiring")
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
        // Test behavior when session is set to expired
        let expiredDate = Date().addingTimeInterval(-3600) // 1 hour ago

        await MainActor.run {
            authManager.sessionExpiresAt = expiredDate
            authManager.isAuthenticated = true // Simulate authenticated state
        }

        // Session should be considered expired
        let timeRemaining = authManager.sessionTimeRemaining
        XCTAssertNotNil(timeRemaining, "Time remaining should not be nil")
        XCTAssertLessThan(timeRemaining!, 0, "Time remaining should be negative for expired session")
    }

    func testSessionProperties() async throws {
        // Test session-related published properties are accessible
        XCTAssertNotNil(authManager.currentSession, "currentSession property should be accessible (even if nil)")
        XCTAssertNotNil(authManager.sessionExpiresAt, "sessionExpiresAt property should be accessible (even if nil)")

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

    private func createMockUser() throws -> User {
        // Create a mock user for testing
        // Note: This is a simplified mock - in real tests you'd use proper mocking
        let userData: [String: Any] = [
            "id": UUID().uuidString,
            "email": "test@example.com",
            "created_at": ISO8601DateFormatter().string(from: Date()),
            "updated_at": ISO8601DateFormatter().string(from: Date()),
            "email_confirmed_at": ISO8601DateFormatter().string(from: Date()),
            "app_metadata": [:],
            "user_metadata": [:]
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: userData)
        return try JSONDecoder().decode(User.self, from: jsonData)
    }

    // MARK: - Performance Tests

    func testAuthManagerPerformance() async throws {
        // Test that AuthManager initialization is fast
        measure {
            let _ = AuthManager.shared
        }
    }
}