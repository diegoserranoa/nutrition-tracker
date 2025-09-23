//
//  SupabaseManagerTests.swift
//  NutritionTrackerV2Tests
//
//  Test suite for SupabaseManager connectivity and initialization
//

import XCTest
@testable import NutritionTrackerV2
import Supabase

@MainActor
class SupabaseManagerTests: XCTestCase {

    var supabaseManager: SupabaseManager!

    override func setUp() async throws {
        try await super.setUp()
        supabaseManager = SupabaseManager.shared
    }

    override func tearDown() async throws {
        supabaseManager = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testSupabaseManagerSingleton() async throws {
        // Test that singleton returns the same instance
        let instance1 = SupabaseManager.shared
        let instance2 = SupabaseManager.shared

        XCTAssertTrue(instance1 === instance2, "SupabaseManager should be a singleton")
    }

    func testSupabaseClientInitialization() async throws {
        // Test that the Supabase client is properly initialized
        XCTAssertNotNil(supabaseManager.client, "Supabase client should be initialized")
        XCTAssertNotNil(supabaseManager.auth, "Auth client should be accessible")
        XCTAssertNotNil(supabaseManager.storage, "Storage client should be accessible")
    }

    func testInitialConnectionStatus() async throws {
        // Allow some time for initialization
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

        // Check that connection status is not disconnected after initialization
        XCTAssertNotEqual(supabaseManager.connectionStatus, .disconnected,
                         "Connection status should not remain disconnected after initialization")
    }

    // MARK: - Connection Tests

    func testConnectionValidation() async throws {
        // Test connection validation
        let isConnected = await supabaseManager.validateConnection()

        // We expect this to succeed since our Supabase instance should be available
        XCTAssertTrue(isConnected, "Connection validation should succeed")
        XCTAssertEqual(supabaseManager.connectionStatus, .connected,
                      "Connection status should be connected after successful validation")
    }

    func testHealthCheck() async throws {
        // Test comprehensive health check
        let healthResult = await supabaseManager.healthCheck()

        // Database should be connected
        XCTAssertTrue(healthResult.databaseConnected, "Database should be connected")
        XCTAssertNil(healthResult.databaseError, "Database should not have errors")

        // Check overall health
        print("Health check result: \(healthResult.statusMessage)")
    }

    // MARK: - Database Query Tests

    func testDatabaseQueryCapability() async throws {
        // Test that we can create a query builder
        let queryBuilder = supabaseManager.from("profiles")
        XCTAssertNotNil(queryBuilder, "Should be able to create query builder for profiles table")
    }

    // MARK: - Configuration Tests

    func testConfigurationValues() async throws {
        // Test that configuration is properly loaded
        let client = supabaseManager.client

        // We can't directly access the URL and key, but we can verify the client exists
        XCTAssertNotNil(client, "Client should be initialized with configuration")
    }

    // MARK: - Error Handling Tests

    func testCustomErrorTypes() async throws {
        // Test custom error enum
        let authError = SupabaseError.userNotAuthenticated
        XCTAssertEqual(authError.errorDescription, "User is not authenticated")

        let configError = SupabaseError.invalidConfiguration
        XCTAssertEqual(configError.errorDescription, "Invalid Supabase configuration")

        let networkError = SupabaseError.networkError("Test error")
        XCTAssertEqual(networkError.errorDescription, "Network error: Test error")
    }

    // MARK: - Health Check Result Tests

    func testHealthCheckResultLogic() async throws {
        // Test HealthCheckResult logic
        var healthResult = HealthCheckResult()

        // Initially should not be healthy
        XCTAssertFalse(healthResult.overallHealthy, "Should not be healthy initially")

        // Set database as connected
        healthResult.databaseConnected = true
        XCTAssertTrue(healthResult.overallHealthy, "Should be healthy when database connected and no storage error")

        // Add storage error
        healthResult.storageError = "Storage unavailable"
        XCTAssertFalse(healthResult.overallHealthy, "Should not be healthy when storage has error")

        // Test status messages
        XCTAssertTrue(healthResult.statusMessage.contains("Storage"), "Status message should mention storage issue")
    }

    // MARK: - Performance Tests

    func testConnectionPerformance() async throws {
        // Test that connection validation completes within reasonable time
        let startTime = Date()

        let _ = await supabaseManager.validateConnection()

        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)

        XCTAssertLessThan(duration, 10.0, "Connection validation should complete within 10 seconds")
    }
}