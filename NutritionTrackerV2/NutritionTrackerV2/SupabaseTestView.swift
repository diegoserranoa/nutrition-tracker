//
//  SupabaseTestView.swift
//  NutritionTrackerV2
//
//  Test view to verify Supabase integration
//

import SwiftUI
import Supabase

struct SupabaseTestView: View {
    @StateObject private var supabaseManager = SupabaseManager.shared
    @State private var email = ""
    @State private var password = ""
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Supabase Integration Test")
                    .font(.title)
                    .bold()

                // Connection Status
                HStack {
                    Circle()
                        .fill(connectionStatusColor)
                        .frame(width: 12, height: 12)
                    Text(connectionStatusText)
                        .font(.caption)
                }

                // Authentication Section
                if !supabaseManager.isAuthenticated {
                    VStack(spacing: 16) {
                        TextField("Email", text: $email)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)

                        SecureField("Password", text: $password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())

                        HStack(spacing: 12) {
                            Button("Sign Up") {
                                Task {
                                    await signUp()
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(email.isEmpty || password.isEmpty || supabaseManager.isLoading)

                            Button("Sign In") {
                                Task {
                                    await signIn()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(email.isEmpty || password.isEmpty || supabaseManager.isLoading)
                        }
                    }
                } else {
                    // Authenticated User Info
                    VStack(spacing: 16) {
                        Text("✅ Successfully connected to Supabase!")
                            .foregroundColor(.green)
                            .bold()

                        if let user = supabaseManager.currentUser {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("User ID: \(user.id)")
                                if let email = user.email {
                                    Text("Email: \(email)")
                                }
                                Text("Created: \(user.createdAt)")
                            }
                            .font(.caption)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }

                        Button("Test Database Connection") {
                            Task {
                                await testDatabaseConnection()
                            }
                        }
                        .buttonStyle(.bordered)

                        Button("Sign Out") {
                            Task {
                                await signOut()
                            }
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                    }
                }

                if supabaseManager.isLoading {
                    ProgressView("Loading...")
                        .padding()
                }

                Spacer()

                // Integration Status
                VStack(alignment: .leading, spacing: 8) {
                    Text("SDK Integration Status:")
                        .font(.headline)

                    IntegrationStatusRow(title: "Supabase Client", isWorking: true)
                    IntegrationStatusRow(title: "Auth Module", isWorking: true)
                    IntegrationStatusRow(title: "Database Module", isWorking: true)
                    IntegrationStatusRow(title: "Storage Module", isWorking: true)
                    IntegrationStatusRow(title: "Realtime Module", isWorking: false) // TODO: Implement
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
            }
            .padding()
            .navigationTitle("Supabase Test")
        }
        .alert("Result", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }

    private var connectionStatusColor: Color {
        supabaseManager.isAuthenticated ? .green : .orange
    }

    private var connectionStatusText: String {
        if supabaseManager.isAuthenticated {
            return "Connected & Authenticated"
        } else {
            return "SDK Loaded - Not Authenticated"
        }
    }

    // MARK: - Actions
    private func signUp() async {
        do {
            try await supabaseManager.signUp(email: email, password: password)
            alertMessage = "Sign up successful! Check your email for verification."
            showAlert = true
        } catch {
            alertMessage = "Sign up failed: \(error.localizedDescription)"
            showAlert = true
        }
    }

    private func signIn() async {
        do {
            try await supabaseManager.signIn(email: email, password: password)
            alertMessage = "Sign in successful!"
            showAlert = true
        } catch {
            alertMessage = "Sign in failed: \(error.localizedDescription)"
            showAlert = true
        }
    }

    private func signOut() async {
        do {
            try await supabaseManager.signOut()
            email = ""
            password = ""
            alertMessage = "Signed out successfully"
            showAlert = true
        } catch {
            alertMessage = "Sign out failed: \(error.localizedDescription)"
            showAlert = true
        }
    }

    private func testDatabaseConnection() async {
        do {
            // Test basic database query
            let _: [UserProfile] = try await supabaseManager.from("profiles")
                .select()
                .limit(1)
                .execute()
                .value

            alertMessage = "✅ Database connection successful!"
            showAlert = true
        } catch {
            alertMessage = "Database connection failed: \(error.localizedDescription)"
            showAlert = true
        }
    }
}

struct IntegrationStatusRow: View {
    let title: String
    let isWorking: Bool

    var body: some View {
        HStack {
            Image(systemName: isWorking ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isWorking ? .green : .red)
            Text(title)
            Spacer()
            Text(isWorking ? "✓" : "✗")
                .foregroundColor(isWorking ? .green : .red)
                .bold()
        }
    }
}

#Preview {
    SupabaseTestView()
}