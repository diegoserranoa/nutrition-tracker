//
//  AuthTestView.swift
//  NutritionTrackerV2
//
//  Test view to demonstrate AuthManager functionality
//

import SwiftUI
import Supabase

struct AuthTestView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isSignUpMode = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Authentication Test")
                    .font(.title)
                    .bold()

                // Authentication State Display
                AuthenticationStateView(state: authManager.authenticationState)

                if !authManager.isUserAuthenticated {
                    // Sign In/Sign Up Form
                    VStack(spacing: 16) {
                        Picker("Mode", selection: $isSignUpMode) {
                            Text("Sign In").tag(false)
                            Text("Sign Up").tag(true)
                        }
                        .pickerStyle(SegmentedPickerStyle())

                        TextField("Email", text: $email)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)

                        SecureField("Password", text: $password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())

                        if isSignUpMode {
                            TextField("Username", text: $username)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                        }

                        Button(isSignUpMode ? "Sign Up" : "Sign In") {
                            Task {
                                await handleAuthentication()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(email.isEmpty || password.isEmpty || authManager.isLoading)

                        if !isSignUpMode {
                            Button("Reset Password") {
                                Task {
                                    await resetPassword()
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(email.isEmpty || authManager.isLoading)
                        }
                    }
                } else {
                    // Authenticated User Interface
                    VStack(spacing: 16) {
                        Text("✅ Successfully Authenticated!")
                            .foregroundColor(.green)
                            .bold()

                        if let user = authManager.currentUser {
                            UserInfoView(user: user)
                        }

                        HStack(spacing: 12) {
                            Button("Create Profile") {
                                Task {
                                    await createProfile()
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(username.isEmpty || authManager.isLoading)

                            Button("Get Profile") {
                                Task {
                                    await getProfile()
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(authManager.isLoading)
                        }

                        TextField("Username for Profile", text: $username)
                            .textFieldStyle(RoundedBorderTextFieldStyle())

                        Button("Sign Out") {
                            Task {
                                await signOut()
                            }
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                        .disabled(authManager.isLoading)
                    }
                }

                if authManager.isLoading {
                    ProgressView("Loading...")
                        .padding()
                }

                // Error Display
                if let errorMessage = authManager.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding()
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Auth Manager Test")
        }
        .alert("Result", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - Actions

    private func handleAuthentication() async {
        do {
            if isSignUpMode {
                try await authManager.signUp(email: email, password: password)
                alertMessage = "Sign up successful! Check your email for verification."
            } else {
                try await authManager.signIn(email: email, password: password)
                alertMessage = "Sign in successful!"
            }
            showAlert = true
        } catch {
            alertMessage = "Authentication failed: \(error.localizedDescription)"
            showAlert = true
        }
    }

    private func resetPassword() async {
        do {
            try await authManager.resetPassword(email: email)
            alertMessage = "Password reset email sent! Check your inbox."
            showAlert = true
        } catch {
            alertMessage = "Password reset failed: \(error.localizedDescription)"
            showAlert = true
        }
    }

    private func createProfile() async {
        do {
            try await authManager.createUserProfile(username: username)
            alertMessage = "Profile created successfully!"
            showAlert = true
        } catch {
            alertMessage = "Profile creation failed: \(error.localizedDescription)"
            showAlert = true
        }
    }

    private func getProfile() async {
        do {
            if let profile = try await authManager.getUserProfile() {
                alertMessage = "Profile found: \(profile.username ?? "No username")"
            } else {
                alertMessage = "No profile found. Create one first!"
            }
            showAlert = true
        } catch {
            alertMessage = "Failed to get profile: \(error.localizedDescription)"
            showAlert = true
        }
    }

    private func signOut() async {
        do {
            try await authManager.signOut()
            email = ""
            password = ""
            username = ""
            alertMessage = "Signed out successfully"
            showAlert = true
        } catch {
            alertMessage = "Sign out failed: \(error.localizedDescription)"
            showAlert = true
        }
    }
}

// MARK: - Supporting Views

struct AuthenticationStateView: View {
    let state: AuthManager.AuthenticationState

    var body: some View {
        HStack {
            Circle()
                .fill(stateColor)
                .frame(width: 12, height: 12)
            Text(stateText)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(stateColor.opacity(0.1))
        .cornerRadius(16)
    }

    private var stateColor: Color {
        switch state {
        case .authenticated:
            return .green
        case .unauthenticated:
            return .orange
        case .loading:
            return .blue
        case .error:
            return .red
        }
    }

    private var stateText: String {
        switch state {
        case .authenticated(let user):
            return "Authenticated as \(user.email ?? "Unknown")"
        case .unauthenticated:
            return "Not Authenticated"
        case .loading:
            return "Loading..."
        case .error(let message):
            return "Error: \(message)"
        }
    }
}

struct UserInfoView: View {
    let user: User

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let email = user.email {
                HStack {
                    Text("Email:")
                        .fontWeight(.medium)
                    Text(email)
                        .foregroundColor(.secondary)
                }
            }

            HStack {
                Text("User ID:")
                    .fontWeight(.medium)
                Text(user.id.uuidString.prefix(8) + "...")
                    .foregroundColor(.secondary)
                    .font(.system(.caption, design: .monospaced))
            }

            HStack {
                Text("Created:")
                    .fontWeight(.medium)
                Text(user.createdAt, style: .date)
                    .foregroundColor(.secondary)
            }
        }
        .font(.caption)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    AuthTestView()
}