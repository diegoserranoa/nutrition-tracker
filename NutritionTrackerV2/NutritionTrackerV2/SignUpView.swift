//
//  SignUpView.swift
//  NutritionTrackerV2
//
//  Professional sign up view following iOS design patterns
//

import SwiftUI
import Supabase

struct SignUpView: View {
    @StateObject private var authManager = AuthManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var username = ""
    @State private var agreeToTerms = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case email, password, confirmPassword, username
    }

    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color.green.opacity(0.1), Color.white]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        Spacer(minLength: 40)

                        // Header
                        VStack(spacing: 16) {
                            Image(systemName: "person.crop.circle.badge.plus")
                                .font(.system(size: 50))
                                .foregroundColor(.green)

                            Text("Create Account")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)

                            Text("Join thousands tracking their nutrition")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        // Sign up form
                        VStack(spacing: 20) {
                            // Username field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Username")
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                HStack {
                                    Image(systemName: "person")
                                        .foregroundColor(.secondary)

                                    TextField("Choose a username", text: $username)
                                        .textFieldStyle(PlainTextFieldStyle())
                                        .autocapitalization(.none)
                                        .textContentType(.username)
                                        .focused($focusedField, equals: .username)
                                        .submitLabel(.next)
                                        .onSubmit {
                                            focusedField = .email
                                        }
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(focusedField == .username ? Color.green : Color.clear, lineWidth: 2)
                                )

                                if !username.isEmpty && !isValidUsername {
                                    Text("Username must be at least 3 characters")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }

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
                                        .stroke(focusedField == .email ? Color.green : Color.clear, lineWidth: 2)
                                )

                                if !email.isEmpty && !isValidEmail {
                                    Text("Please enter a valid email address")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }

                            // Password field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Password")
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                HStack {
                                    Image(systemName: "lock")
                                        .foregroundColor(.secondary)

                                    SecureField("Create a password", text: $password)
                                        .textFieldStyle(PlainTextFieldStyle())
                                        .textContentType(.newPassword)
                                        .focused($focusedField, equals: .password)
                                        .submitLabel(.next)
                                        .onSubmit {
                                            focusedField = .confirmPassword
                                        }
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(focusedField == .password ? Color.green : Color.clear, lineWidth: 2)
                                )

                                // Password requirements
                                if !password.isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        PasswordRequirementRow(
                                            text: "At least 8 characters",
                                            isMet: password.count >= 8
                                        )
                                        PasswordRequirementRow(
                                            text: "Contains a letter",
                                            isMet: password.range(of: ".*[A-Za-z]+.*", options: .regularExpression) != nil
                                        )
                                        PasswordRequirementRow(
                                            text: "Contains a number",
                                            isMet: password.range(of: ".*[0-9]+.*", options: .regularExpression) != nil
                                        )
                                    }
                                    .font(.caption)
                                }
                            }

                            // Confirm password field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Confirm Password")
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                HStack {
                                    Image(systemName: "lock.fill")
                                        .foregroundColor(.secondary)

                                    SecureField("Confirm your password", text: $confirmPassword)
                                        .textFieldStyle(PlainTextFieldStyle())
                                        .textContentType(.newPassword)
                                        .focused($focusedField, equals: .confirmPassword)
                                        .submitLabel(.go)
                                        .onSubmit {
                                            if isFormValid {
                                                Task {
                                                    await signUp()
                                                }
                                            }
                                        }
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(focusedField == .confirmPassword ? Color.green : Color.clear, lineWidth: 2)
                                )

                                if !confirmPassword.isEmpty && password != confirmPassword {
                                    Text("Passwords do not match")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }

                            // Terms and conditions
                            HStack(alignment: .top, spacing: 12) {
                                Button(action: {
                                    agreeToTerms.toggle()
                                }) {
                                    Image(systemName: agreeToTerms ? "checkmark.square.fill" : "square")
                                        .foregroundColor(agreeToTerms ? .green : .gray)
                                        .font(.title3)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("I agree to the")
                                        .foregroundColor(.primary)

                                    HStack(spacing: 4) {
                                        Button("Terms of Service") {
                                            // Handle terms of service
                                        }
                                        .foregroundColor(.blue)

                                        Text("and")
                                            .foregroundColor(.primary)

                                        Button("Privacy Policy") {
                                            // Handle privacy policy
                                        }
                                        .foregroundColor(.blue)
                                    }
                                }
                                .font(.subheadline)

                                Spacer()
                            }

                            // Sign up button
                            Button(action: {
                                Task {
                                    await signUp()
                                }
                            }) {
                                HStack {
                                    if authManager.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    }

                                    Text(authManager.isLoading ? "Creating Account..." : "Create Account")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(isFormValid ? Color.green : Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(!isFormValid || authManager.isLoading)
                        }
                        .padding(.horizontal, 32)

                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationTitle("Sign Up")
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
        .alert("Sign Up", isPresented: $showAlert) {
            Button("OK") {
                if alertMessage.contains("successful") {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
        .onTapGesture {
            focusedField = nil
        }
    }

    // MARK: - Computed Properties

    private var isValidEmail: Bool {
        let emailRegex = "^[\\w\\.-]+@([\\w\\-]+\\.)+[A-Z]{1,4}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES[c] %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    private var isValidUsername: Bool {
        username.count >= 3
    }

    private var isValidPassword: Bool {
        password.count >= 8 &&
        password.range(of: ".*[A-Za-z]+.*", options: .regularExpression) != nil &&
        password.range(of: ".*[0-9]+.*", options: .regularExpression) != nil
    }

    private var passwordsMatch: Bool {
        password == confirmPassword
    }

    private var isFormValid: Bool {
        isValidEmail && isValidUsername && isValidPassword && passwordsMatch && agreeToTerms
    }

    // MARK: - Actions

    private func signUp() async {
        focusedField = nil

        do {
            try await authManager.signUp(email: email, password: password)

            // Create user profile
            try await authManager.createUserProfile(username: username)

            alertMessage = "Account created successfully! Please check your email for verification."
            showAlert = true
        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }
}

// MARK: - Supporting Views

struct PasswordRequirementRow: View {
    let text: String
    let isMet: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isMet ? .green : .gray)
                .font(.caption)

            Text(text)
                .foregroundColor(isMet ? .green : .secondary)
        }
    }
}

#Preview {
    SignUpView()
}