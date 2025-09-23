//
//  ProfileCreationView.swift
//  NutritionTrackerV2
//
//  Dedicated view for creating user profiles with enhanced error handling
//

import SwiftUI

struct ProfileCreationView: View {
    @StateObject private var authManager = AuthManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var username = ""
    @State private var customKey = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = "Profile Creation"
    @State private var isSuccess = false
    @State private var isLoading = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case username, customKey
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
                        Spacer(minLength: 40)

                        // Header
                        VStack(spacing: 16) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.blue)

                            Text("Complete Your Profile")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)

                            Text("Help us personalize your nutrition tracking experience")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }

                        // Profile form
                        VStack(spacing: 20) {
                            // Username field
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Username")
                                        .font(.headline)
                                        .foregroundColor(.primary)

                                    Text("*")
                                        .foregroundColor(.red)
                                        .font(.headline)
                                }

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
                                            focusedField = .customKey
                                        }
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(focusedField == .username ? Color.blue : Color.clear, lineWidth: 2)
                                )

                                if !username.isEmpty && !isValidUsername {
                                    Text("Username must be at least 3 characters")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }

                            // Custom Key field (optional)
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Custom Identifier")
                                        .font(.headline)
                                        .foregroundColor(.primary)

                                    Text("(Optional)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                HStack {
                                    Image(systemName: "key")
                                        .foregroundColor(.secondary)

                                    TextField("Optional custom identifier", text: $customKey)
                                        .textFieldStyle(PlainTextFieldStyle())
                                        .autocapitalization(.none)
                                        .focused($focusedField, equals: .customKey)
                                        .submitLabel(.done)
                                        .onSubmit {
                                            if isFormValid {
                                                Task {
                                                    await createProfile()
                                                }
                                            }
                                        }
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(focusedField == .customKey ? Color.blue : Color.clear, lineWidth: 2)
                                )

                                Text("This can be used to identify your account across different platforms")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            // Create profile button
                            Button(action: {
                                Task {
                                    await createProfile()
                                }
                            }) {
                                HStack {
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    }

                                    Text(isLoading ? "Creating Profile..." : "Create Profile")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(isFormValid ? Color.blue : Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(!isFormValid || isLoading)

                            // Skip button
                            Button("Skip for Now") {
                                dismiss()
                            }
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                        }
                        .padding(.horizontal, 32)

                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationTitle("Profile Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
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
                Button("Try Again") {
                    Task {
                        await createProfile()
                    }
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

    private var isValidUsername: Bool {
        username.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3
    }

    private var isFormValid: Bool {
        isValidUsername
    }

    // MARK: - Actions

    private func createProfile() async {
        focusedField = nil

        await MainActor.run {
            isLoading = true
        }

        do {
            let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedCustomKey = customKey.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalCustomKey = trimmedCustomKey.isEmpty ? nil : trimmedCustomKey

            try await authManager.createUserProfile(
                username: trimmedUsername,
                customKey: finalCustomKey
            )

            await MainActor.run {
                isLoading = false
                alertTitle = "Profile Created!"
                alertMessage = "Your profile has been successfully created. You can now start tracking your nutrition!"
                isSuccess = true
                showAlert = true
            }
        } catch {
            await MainActor.run {
                isLoading = false
                alertTitle = "Profile Creation Failed"
                alertMessage = getErrorMessage(from: error)
                isSuccess = false
                showAlert = true
            }
        }
    }

    private func getErrorMessage(from error: Error) -> String {
        if let authError = error as? AuthManagerError {
            switch authError {
            case .userNotAuthenticated:
                return "Authentication required. Please sign in first."
            case .invalidUsername:
                return "Username is invalid. Please choose a different username."
            case .networkError:
                return "Network connection error. Please check your internet connection and try again."
            default:
                return authError.localizedDescription
            }
        } else {
            let errorDescription = error.localizedDescription.lowercased()
            if errorDescription.contains("username") && errorDescription.contains("taken") {
                return "This username is already taken. Please choose a different one."
            } else if errorDescription.contains("network") || errorDescription.contains("connection") {
                return "Network connection error. Please check your internet connection and try again."
            } else {
                return "Profile creation failed: \(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    ProfileCreationView()
}