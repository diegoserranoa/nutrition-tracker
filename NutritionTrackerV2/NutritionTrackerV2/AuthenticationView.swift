//
//  AuthenticationView.swift
//  NutritionTrackerV2
//
//  Professional login view following iOS design patterns
//

import SwiftUI
import Supabase

struct AuthenticationView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var email = ""
    @State private var password = ""
    @State private var showSignUp = false
    @State private var showForgotPassword = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = "Authentication"
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case email, password
    }

    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.white]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        Spacer(minLength: 60)

                        // App branding
                        VStack(spacing: 16) {
                            Image(systemName: "leaf.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.green)

                            Text("NutritionTracker")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)

                            Text("Track your nutrition journey")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        // Login form
                        VStack(spacing: 24) {
                            VStack(spacing: 16) {
                                // Email field
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Email")
                                        .font(.headline)
                                        .foregroundColor(.primary)

                                    HStack {
                                        Image(systemName: "envelope")
                                            .foregroundColor(.secondary)

                                        TextField("Enter your email", text: $email)
                                            .textFieldStyle(PlainTextFieldStyle())
                                            .autocapitalization(.none)
                                            .keyboardType(.emailAddress)
                                            .textContentType(.emailAddress)
                                            .focused($focusedField, equals: .email)
                                            .submitLabel(.next)
                                            .onSubmit {
                                                focusedField = .password
                                            }
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(focusedField == .email ? Color.blue : Color.clear, lineWidth: 2)
                                    )
                                }

                                // Password field
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Password")
                                        .font(.headline)
                                        .foregroundColor(.primary)

                                    HStack {
                                        Image(systemName: "lock")
                                            .foregroundColor(.secondary)

                                        SecureField("Enter your password", text: $password)
                                            .textFieldStyle(PlainTextFieldStyle())
                                            .textContentType(.password)
                                            .focused($focusedField, equals: .password)
                                            .submitLabel(.go)
                                            .onSubmit {
                                                Task {
                                                    await signIn()
                                                }
                                            }
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(focusedField == .password ? Color.blue : Color.clear, lineWidth: 2)
                                    )
                                }
                            }

                            // Forgot password link
                            HStack {
                                Spacer()
                                Button("Forgot Password?") {
                                    showForgotPassword = true
                                }
                                .font(.subheadline)
                                .foregroundColor(.blue)
                            }

                            // Sign in button
                            Button(action: {
                                Task {
                                    await signIn()
                                }
                            }) {
                                HStack {
                                    if authManager.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    }

                                    Text(authManager.isLoading ? "Signing In..." : "Sign In")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(isFormValid ? Color.blue : Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(!isFormValid || authManager.isLoading)

                            // Sign up navigation
                            HStack {
                                Text("Don't have an account?")
                                    .foregroundColor(.secondary)

                                Button("Sign Up") {
                                    showSignUp = true
                                }
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                            }
                            .font(.subheadline)
                        }
                        .padding(.horizontal, 32)

                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showSignUp) {
            SignUpView()
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .onTapGesture {
            focusedField = nil
        }
    }

    // MARK: - Computed Properties

    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && isValidEmail(email)
    }

    // MARK: - Actions

    private func signIn() async {
        focusedField = nil

        do {
            try await authManager.signIn(email: email, password: password)
            // Navigation to main app will be handled by the parent view based on auth state
        } catch {
            await MainActor.run {
                alertTitle = "Sign In Failed"
                alertMessage = getErrorMessage(from: error)
                showAlert = true
            }
        }
    }

    private func getErrorMessage(from error: Error) -> String {
        if let authError = error as? AuthManagerError {
            switch authError {
            case .invalidCredentials:
                return "Invalid email or password. Please check your credentials and try again."
            case .invalidEmail:
                return "Please enter a valid email address."
            case .emptyPassword:
                return "Please enter your password."
            case .networkError:
                return "Network connection error. Please check your internet connection and try again."
            case .sessionExpired:
                return "Your session has expired. Please sign in again."
            case .userNotAuthenticated:
                return "Authentication failed. Please try again."
            default:
                return authError.localizedDescription
            }
        } else {
            // Handle other types of errors
            let errorDescription = error.localizedDescription.lowercased()
            if errorDescription.contains("invalid") && (errorDescription.contains("credential") || errorDescription.contains("password") || errorDescription.contains("email")) {
                return "Invalid email or password. Please check your credentials and try again."
            } else if errorDescription.contains("network") || errorDescription.contains("connection") {
                return "Network connection error. Please check your internet connection and try again."
            } else if errorDescription.contains("not confirmed") || errorDescription.contains("email not verified") {
                return "Please check your email and click the verification link before signing in."
            } else {
                return "Sign in failed: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Helper Methods

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "^[\\w\\.-]+@([\\w\\-]+\\.)+[A-Z]{1,4}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES[c] %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
}

#Preview {
    AuthenticationView()
}