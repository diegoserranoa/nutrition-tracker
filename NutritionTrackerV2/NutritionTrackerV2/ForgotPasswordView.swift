//
//  ForgotPasswordView.swift
//  NutritionTrackerV2
//
//  Password reset view following iOS design patterns
//

import SwiftUI

struct ForgotPasswordView: View {
    @StateObject private var authManager = AuthManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = "Password Reset"
    @State private var isSuccess = false
    @FocusState private var isEmailFocused: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                Spacer()

                // Header
                VStack(spacing: 16) {
                    Image(systemName: "key.horizontal")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)

                    Text("Reset Password")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    Text("Enter your email address and we'll send you a link to reset your password.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                // Email input
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
                            .focused($isEmailFocused)
                            .submitLabel(.send)
                            .onSubmit {
                                if isValidEmail {
                                    Task {
                                        await sendResetEmail()
                                    }
                                }
                            }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isEmailFocused ? Color.blue : Color.clear, lineWidth: 2)
                    )

                    if !email.isEmpty && !isValidEmail {
                        Text("Please enter a valid email address")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal, 32)

                // Send reset email button
                Button(action: {
                    Task {
                        await sendResetEmail()
                    }
                }) {
                    HStack {
                        if authManager.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }

                        Text(authManager.isLoading ? "Sending..." : "Send Reset Link")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isValidEmail ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!isValidEmail || authManager.isLoading)
                .padding(.horizontal, 32)

                Spacer()

                // Back to login
                Button("Back to Sign In") {
                    dismiss()
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            .navigationTitle("Reset Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .alert(alertTitle, isPresented: $showAlert) {
            if isSuccess {
                Button("Continue") {
                    dismiss()
                }
            } else {
                Button("OK") { }
            }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            isEmailFocused = true
        }
        .onTapGesture {
            isEmailFocused = false
        }
    }

    // MARK: - Computed Properties

    private var isValidEmail: Bool {
        let emailRegex = "^[\\w\\.-]+@([\\w\\-]+\\.)+[A-Z]{1,4}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES[c] %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    // MARK: - Actions

    private func sendResetEmail() async {
        isEmailFocused = false

        do {
            try await authManager.resetPassword(email: email)
            await MainActor.run {
                alertTitle = "Reset Link Sent"
                alertMessage = "Password reset link has been sent to your email address. Please check your inbox and follow the instructions."
                isSuccess = true
                showAlert = true
            }
        } catch {
            await MainActor.run {
                alertTitle = "Reset Failed"
                alertMessage = getErrorMessage(from: error)
                isSuccess = false
                showAlert = true
            }
        }
    }

    private func getErrorMessage(from error: Error) -> String {
        if let authError = error as? AuthManagerError {
            switch authError {
            case .invalidEmail:
                return "Please enter a valid email address."
            case .networkError:
                return "Network connection error. Please check your internet connection and try again."
            default:
                return authError.localizedDescription
            }
        } else {
            let errorDescription = error.localizedDescription.lowercased()
            if errorDescription.contains("email") && errorDescription.contains("not found") {
                return "No account found with this email address. Please check the email or create a new account."
            } else if errorDescription.contains("network") || errorDescription.contains("connection") {
                return "Network connection error. Please check your internet connection and try again."
            } else if errorDescription.contains("rate limit") || errorDescription.contains("too many") {
                return "Too many reset attempts. Please wait a few minutes before trying again."
            } else {
                return "Password reset failed: \(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    ForgotPasswordView()
}