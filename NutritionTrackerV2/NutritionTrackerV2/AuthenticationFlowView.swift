//
//  AuthenticationFlowView.swift
//  NutritionTrackerV2
//
//  Main authentication flow coordinator
//

import SwiftUI

struct AuthenticationFlowView: View {
    @StateObject private var authManager = AuthManager.shared

    var body: some View {
        Group {
            if authManager.isUserAuthenticated {
                // User is authenticated - show main app content
                MainAppView()
            } else {
                // User is not authenticated - show login screen
                AuthenticationView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authManager.isUserAuthenticated)
    }
}

// MARK: - Main App Content

struct MainAppView: View {
    @StateObject private var authManager = AuthManager.shared

    var body: some View {
        TabView {
            // Home tab
            NavigationView {
                VStack(spacing: 20) {
                    Image(systemName: "leaf.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)

                    Text("Welcome to NutritionTracker!")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("You're successfully authenticated")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if let user = authManager.currentUser {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("User Information:")
                                .font(.headline)

                            if let email = user.email {
                                Label(email, systemImage: "envelope")
                            }

                            Label("ID: \(user.id.uuidString.prefix(8))...", systemImage: "person.circle")
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }

                    Button("Sign Out") {
                        Task {
                            try? await authManager.signOut()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Spacer()
                }
                .padding()
                .navigationTitle("Home")
            }
            .tabItem {
                Image(systemName: "house")
                Text("Home")
            }

            // Profile tab
            NavigationView {
                VStack {
                    Text("Profile Content")
                        .font(.title)

                    Spacer()
                }
                .navigationTitle("Profile")
            }
            .tabItem {
                Image(systemName: "person.circle")
                Text("Profile")
            }

            // Auth test tab (keeping for testing)
            AuthTestView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Auth Test")
                }
        }
    }
}

#Preview("Authentication Flow") {
    AuthenticationFlowView()
}

#Preview("Main App") {
    MainAppView()
}