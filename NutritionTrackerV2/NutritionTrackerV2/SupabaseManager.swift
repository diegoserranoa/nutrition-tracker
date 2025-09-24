//
//  SupabaseManager.swift
//  NutritionTrackerV2
//
//  Created for NutritionTrackerV2 Supabase integration
//

import Foundation
import Supabase

@MainActor
class SupabaseManager: ObservableObject, SupabaseManagerProtocol {
    nonisolated static let shared = SupabaseManager()

    // MARK: - Configuration
    private struct Config {
        static let url = "https://hcskwwdqmgilvasqeqxh.supabase.co"
        static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhjc2t3d2RxbWdpbHZhc3FlcXhoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg1ODUyMzUsImV4cCI6MjA3NDE2MTIzNX0.ENCHvALhZE5iG-mBuJjLrzULe6yOPMY31qBjJDloWVM"

        // Configuration options
        static let enableRealtime = true
        static let enableLogging = true
        static let connectionTimeout: TimeInterval = 30.0
    }

    // MARK: - Properties
    private let supabaseClient: SupabaseClient

    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var connectionStatus: ConnectionStatus = .disconnected

    enum ConnectionStatus: Equatable {
        case connected
        case disconnected
        case connecting
        case error(String)
    }

    // MARK: - Initialization
    nonisolated private init() {
        // Load configuration
        guard let supabaseURL = URL(string: Config.url) else {
            fatalError("Invalid Supabase URL")
        }

        // Initialize Supabase client
        self.supabaseClient = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: Config.anonKey
        )

        // Set up authentication state listener
        setupAuthListener()

        // Check initial auth state and validate connection
        Task { @MainActor in
            await checkAuthState()
            let _ = await validateConnection()
        }
    }

    // MARK: - Public API
    var client: SupabaseClient {
        return supabaseClient
    }

    var auth: AuthClient {
        return supabaseClient.auth
    }

    func from(_ table: String) -> PostgrestQueryBuilder {
        return supabaseClient.from(table)
    }

    var storage: SupabaseStorageClient {
        return supabaseClient.storage
    }

    var realtime: RealtimeClient {
        return supabaseClient.realtime
    }

    // MARK: - Authentication Methods
    func signUp(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil

        do {
            try await auth.signUp(email: email, password: password)
            await checkAuthState()
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }

        isLoading = false
    }

    func signIn(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil

        do {
            try await auth.signIn(email: email, password: password)
            await checkAuthState()
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }

        isLoading = false
    }

    func signOut() async throws {
        isLoading = true
        errorMessage = nil

        do {
            try await auth.signOut()
            currentUser = nil
            isAuthenticated = false
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }

        isLoading = false
    }

    // MARK: - User Profile Methods
    func createUserProfile(username: String, customKey: String? = nil) async throws {
        guard let user = currentUser else {
            throw SupabaseError.userNotAuthenticated
        }

        let profile: [String: AnyJSON] = [
            "id": AnyJSON.string(user.id.uuidString),
            "username": AnyJSON.string(username),
            "custom_key": customKey.map(AnyJSON.string) ?? AnyJSON.null
        ]

        try await from("profiles")
            .insert(profile)
            .execute()
    }

    func getUserProfile() async throws -> UserProfile? {
        guard let user = currentUser else {
            throw SupabaseError.userNotAuthenticated
        }

        let response: [UserProfile] = try await from("profiles")
            .select()
            .eq("id", value: user.id.uuidString)
            .execute()
            .value

        return response.first
    }

    // MARK: - Database Helper Methods
    func executeQuery<T: Codable>(_ query: PostgrestQueryBuilder) async throws -> [T] {
        return try await query.execute().value
    }

    func executeInsert<T: Codable>(_ query: PostgrestQueryBuilder, returning type: T.Type) async throws -> [T] {
        return try await query.execute().value
    }

    // MARK: - Storage Helper Methods
    func uploadFile(bucket: String, path: String, data: Data, contentType: String) async throws -> String {
        try await storage
            .from(bucket)
            .upload(path, data: data, options: FileOptions(contentType: contentType))

        return try storage
            .from(bucket)
            .getPublicURL(path: path)
            .absoluteString
    }

    func getPublicURL(bucket: String, path: String) throws -> String {
        return try storage
            .from(bucket)
            .getPublicURL(path: path)
            .absoluteString
    }

    func deleteFile(bucket: String, fileName: String) async throws {
        try await storage
            .from(bucket)
            .remove(paths: [fileName])
    }

    // MARK: - Connection & Health Checks
    func validateConnection() async -> Bool {
        connectionStatus = .connecting

        do {
            // Test basic database connectivity with a simple query
            let _: [AnyJSON] = try await from("profiles")
                .select("id")
                .limit(1)
                .execute()
                .value

            connectionStatus = .connected
            return true
        } catch {
            connectionStatus = .error(error.localizedDescription)
            return false
        }
    }

    func healthCheck() async -> HealthCheckResult {
        var results = HealthCheckResult()

        // Test database connection
        do {
            let _: [AnyJSON] = try await from("profiles")
                .select("id")
                .limit(1)
                .execute()
                .value
            results.databaseConnected = true
        } catch {
            results.databaseError = error.localizedDescription
        }

        // Test authentication status
        results.authenticationWorking = isAuthenticated

        // Test storage (if authenticated)
        if isAuthenticated {
            do {
                let _ = try storage.from("test").getPublicURL(path: "test.txt")
                results.storageConnected = true
            } catch {
                results.storageError = error.localizedDescription
            }
        }

        return results
    }

    // MARK: - Real-time Subscriptions
    // TODO: Implement real-time subscriptions with RealtimeV2 API

    // MARK: - Private Methods
    nonisolated private func setupAuthListener() {
        Task { @MainActor in
            for await (event, session) in auth.authStateChanges {
                await handleAuthStateChange(event: event, session: session)
            }
        }
    }

    private func handleAuthStateChange(event: AuthChangeEvent, session: Session?) async {
        switch event {
        case .signedIn:
            currentUser = session?.user
            isAuthenticated = true
        case .signedOut:
            currentUser = nil
            isAuthenticated = false
        case .tokenRefreshed:
            currentUser = session?.user
        default:
            break
        }
    }

    private func checkAuthState() async {
        do {
            currentUser = try await auth.user()
            isAuthenticated = currentUser != nil
        } catch {
            currentUser = nil
            isAuthenticated = false
        }
    }
}

// MARK: - Custom Errors
enum SupabaseError: Error, LocalizedError {
    case userNotAuthenticated
    case invalidConfiguration
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User is not authenticated"
        case .invalidConfiguration:
            return "Invalid Supabase configuration"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}

// MARK: - User Profile Model
struct UserProfile: Codable, Identifiable {
    let id: String
    let username: String?
    let customKey: String?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case customKey = "custom_key"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Health Check Result
struct HealthCheckResult {
    var databaseConnected = false
    var databaseError: String?
    var authenticationWorking = false
    var storageConnected = false
    var storageError: String?

    var overallHealthy: Bool {
        return databaseConnected && (storageError == nil)
    }

    var statusMessage: String {
        if overallHealthy {
            return "All systems operational"
        } else {
            var issues: [String] = []
            if !databaseConnected {
                issues.append("Database: \(databaseError ?? "Connection failed")")
            }
            if let storageError = storageError {
                issues.append("Storage: \(storageError)")
            }
            return "Issues: \(issues.joined(separator: ", "))"
        }
    }
}