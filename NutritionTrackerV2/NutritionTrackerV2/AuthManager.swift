//
//  AuthManager.swift
//  NutritionTrackerV2
//
//  Authentication manager for handling user authentication with Supabase
//

import Foundation
import Supabase
import Combine

@MainActor
class AuthManager: ObservableObject {

    // MARK: - Singleton
    static let shared = AuthManager()

    // MARK: - Properties
    private let supabaseManager = SupabaseManager.shared
    private var cancellables = Set<AnyCancellable>()

    // Published properties for UI binding
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var authenticationState: AuthenticationState = .unauthenticated

    // MARK: - Authentication State
    enum AuthenticationState: Equatable {
        case loading
        case authenticated(User)
        case unauthenticated
        case error(String)

        var isAuthenticated: Bool {
            switch self {
            case .authenticated:
                return true
            default:
                return false
            }
        }

        static func == (lhs: AuthenticationState, rhs: AuthenticationState) -> Bool {
            switch (lhs, rhs) {
            case (.loading, .loading):
                return true
            case (.unauthenticated, .unauthenticated):
                return true
            case (.authenticated(let user1), .authenticated(let user2)):
                return user1.id == user2.id
            case (.error(let message1), .error(let message2)):
                return message1 == message2
            default:
                return false
            }
        }
    }

    // MARK: - Initialization
    private init() {
        setupAuthStateObserver()
        checkInitialAuthState()
    }

    // MARK: - Public Authentication Methods

    /// Sign up a new user with email and password
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    /// - Throws: AuthManagerError if signup fails
    func signUp(email: String, password: String) async throws {
        guard isValidEmail(email) else {
            throw AuthManagerError.invalidEmail
        }

        guard isValidPassword(password) else {
            throw AuthManagerError.weakPassword
        }

        setLoading(true)
        clearError()

        do {
            try await supabaseManager.signUp(email: email, password: password)
            // Note: User won't be authenticated until email is verified
        } catch {
            let authError = mapSupabaseError(error)
            setError(authError.localizedDescription)
            throw authError
        }

        setLoading(false)
    }

    /// Sign in an existing user with email and password
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    /// - Throws: AuthError if signin fails
    func signIn(email: String, password: String) async throws {
        guard isValidEmail(email) else {
            throw AuthManagerError.invalidEmail
        }

        guard !password.isEmpty else {
            throw AuthManagerError.emptyPassword
        }

        setLoading(true)
        clearError()

        do {
            try await supabaseManager.signIn(email: email, password: password)
        } catch {
            let authError = mapSupabaseError(error)
            setError(authError.localizedDescription)
            throw authError
        }

        setLoading(false)
    }

    /// Sign out the current user
    /// - Throws: AuthError if signout fails
    func signOut() async throws {
        setLoading(true)
        clearError()

        do {
            try await supabaseManager.signOut()
        } catch {
            let authError = mapSupabaseError(error)
            setError(authError.localizedDescription)
            throw authError
        }

        setLoading(false)
    }

    /// Reset password for the given email
    /// - Parameter email: User's email address
    /// - Throws: AuthError if reset fails
    func resetPassword(email: String) async throws {
        guard isValidEmail(email) else {
            throw AuthManagerError.invalidEmail
        }

        setLoading(true)
        clearError()

        do {
            try await supabaseManager.auth.resetPasswordForEmail(email)
        } catch {
            let authError = mapSupabaseError(error)
            setError(authError.localizedDescription)
            throw authError
        }

        setLoading(false)
    }

    /// Update the current user's password
    /// - Parameter newPassword: The new password
    /// - Throws: AuthError if update fails
    func updatePassword(newPassword: String) async throws {
        guard isAuthenticated else {
            throw AuthManagerError.userNotAuthenticated
        }

        guard isValidPassword(newPassword) else {
            throw AuthManagerError.weakPassword
        }

        setLoading(true)
        clearError()

        do {
            try await supabaseManager.auth.update(user: UserAttributes(password: newPassword))
        } catch {
            let authError = mapSupabaseError(error)
            setError(authError.localizedDescription)
            throw authError
        }

        setLoading(false)
    }

    /// Update the current user's email
    /// - Parameter newEmail: The new email address
    /// - Throws: AuthError if update fails
    func updateEmail(newEmail: String) async throws {
        guard isAuthenticated else {
            throw AuthManagerError.userNotAuthenticated
        }

        guard isValidEmail(newEmail) else {
            throw AuthManagerError.invalidEmail
        }

        setLoading(true)
        clearError()

        do {
            try await supabaseManager.auth.update(user: UserAttributes(email: newEmail))
        } catch {
            let authError = mapSupabaseError(error)
            setError(authError.localizedDescription)
            throw authError
        }

        setLoading(false)
    }

    /// Get the current session
    /// - Returns: Current session if available
    func getCurrentSession() async throws -> Session? {
        do {
            return try await supabaseManager.auth.session
        } catch {
            throw mapSupabaseError(error)
        }
    }

    /// Refresh the current session
    /// - Throws: AuthError if refresh fails
    func refreshSession() async throws {
        setLoading(true)
        clearError()

        do {
            _ = try await supabaseManager.auth.refreshSession()
        } catch {
            let authError = mapSupabaseError(error)
            setError(authError.localizedDescription)
            throw authError
        }

        setLoading(false)
    }

    // MARK: - User Profile Methods

    /// Create a user profile after successful authentication
    /// - Parameters:
    ///   - username: User's display name
    ///   - customKey: Optional custom identifier
    /// - Throws: AuthError if profile creation fails
    func createUserProfile(username: String, customKey: String? = nil) async throws {
        guard isAuthenticated else {
            throw AuthManagerError.userNotAuthenticated
        }

        guard !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AuthManagerError.invalidUsername
        }

        setLoading(true)
        clearError()

        do {
            try await supabaseManager.createUserProfile(username: username, customKey: customKey)
        } catch {
            let authError = mapSupabaseError(error)
            setError(authError.localizedDescription)
            throw authError
        }

        setLoading(false)
    }

    /// Get the current user's profile
    /// - Returns: UserProfile if available
    func getUserProfile() async throws -> UserProfile? {
        guard isAuthenticated else {
            throw AuthManagerError.userNotAuthenticated
        }

        do {
            return try await supabaseManager.getUserProfile()
        } catch {
            throw mapSupabaseError(error)
        }
    }

    // MARK: - Utility Methods

    /// Check if the current user is authenticated
    var isUserAuthenticated: Bool {
        return authenticationState.isAuthenticated
    }

    /// Get the current user's ID
    var currentUserID: String? {
        return currentUser?.id.uuidString
    }

    /// Get the current user's email
    var currentUserEmail: String? {
        return currentUser?.email
    }

    // MARK: - Private Methods

    private func setupAuthStateObserver() {
        // Observe changes from SupabaseManager
        supabaseManager.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuth in
                self?.isAuthenticated = isAuth
                self?.updateAuthenticationState()
            }
            .store(in: &cancellables)

        supabaseManager.$currentUser
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                self?.currentUser = user
                self?.updateAuthenticationState()
            }
            .store(in: &cancellables)
    }

    private func updateAuthenticationState() {
        if let user = currentUser, isAuthenticated {
            authenticationState = .authenticated(user)
        } else if let error = errorMessage {
            authenticationState = .error(error)
        } else if isLoading {
            authenticationState = .loading
        } else {
            authenticationState = .unauthenticated
        }
    }

    private func checkInitialAuthState() {
        Task {
            await MainActor.run {
                self.isAuthenticated = supabaseManager.isAuthenticated
                self.currentUser = supabaseManager.currentUser
                self.updateAuthenticationState()
            }
        }
    }

    private func setLoading(_ loading: Bool) {
        isLoading = loading
        if loading {
            authenticationState = .loading
        }
    }

    private func clearError() {
        errorMessage = nil
    }

    private func setError(_ message: String) {
        errorMessage = message
        authenticationState = .error(message)
    }

    // MARK: - Validation Methods

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "^[\\w\\.-]+@([\\w\\-]+\\.)+[A-Z]{1,4}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES[c] %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    private func isValidPassword(_ password: String) -> Bool {
        // Minimum 8 characters, at least one letter and one number
        return password.count >= 8 &&
               password.range(of: ".*[A-Za-z]+.*", options: .regularExpression) != nil &&
               password.range(of: ".*[0-9]+.*", options: .regularExpression) != nil
    }

    // MARK: - Error Mapping

    private func mapSupabaseError(_ error: Error) -> AuthManagerError {
        // Map Supabase errors to our custom AuthManagerError enum
        let errorDescription = error.localizedDescription.lowercased()

        if errorDescription.contains("invalid login credentials") ||
           errorDescription.contains("email not confirmed") {
            return .invalidCredentials
        } else if errorDescription.contains("email") && errorDescription.contains("already") {
            return .emailAlreadyExists
        } else if errorDescription.contains("weak password") {
            return .weakPassword
        } else if errorDescription.contains("network") || errorDescription.contains("connection") {
            return .networkError
        } else if errorDescription.contains("invalid email") {
            return .invalidEmail
        } else {
            return .unknown(error.localizedDescription)
        }
    }
}

// MARK: - Custom Auth Errors

enum AuthManagerError: Error, LocalizedError {
    case invalidEmail
    case invalidCredentials
    case weakPassword
    case emptyPassword
    case emailAlreadyExists
    case userNotAuthenticated
    case invalidUsername
    case networkError
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "Please enter a valid email address."
        case .invalidCredentials:
            return "Invalid email or password. Please try again."
        case .weakPassword:
            return "Password must be at least 8 characters with letters and numbers."
        case .emptyPassword:
            return "Password cannot be empty."
        case .emailAlreadyExists:
            return "An account with this email already exists."
        case .userNotAuthenticated:
            return "You must be signed in to perform this action."
        case .invalidUsername:
            return "Please enter a valid username."
        case .networkError:
            return "Network error. Please check your connection and try again."
        case .unknown(let message):
            return message
        }
    }
}