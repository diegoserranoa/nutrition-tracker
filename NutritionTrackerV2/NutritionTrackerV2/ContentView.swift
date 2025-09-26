//
//  ContentView.swift
//  NutritionTrackerV2
//
//  Created by Diego Serrano on 9/22/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authManager = AuthManager.shared

    var body: some View {
        Group {
            if authManager.isUserAuthenticated {
                // User is authenticated - show main app with tabs
                AuthenticatedContentView()
            } else {
                // User is not authenticated - show authentication flow
                AuthenticationView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authManager.isUserAuthenticated)
    }
}

// MARK: - Authenticated Content

struct AuthenticatedContentView: View {
    @StateObject private var authManager = AuthManager.shared

    // Navigation state
    @State private var showingFoodLog = false
    @State private var showingProgress = false
    @State private var showingScanner = false
    @State private var showingSettings = false


    var body: some View {
        TabView {
            // Home/Dashboard Tab
            NavigationView {
                VStack(spacing: 24) {
                    // Welcome header
                    VStack(spacing: 16) {
                        Image(systemName: "leaf.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)

                        Text("Welcome back!")
                            .font(.title)
                            .fontWeight(.bold)

                        if let user = authManager.currentUser, let email = user.email {
                            Text(email)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Quick actions
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        NavigationLink(destination: FoodLogView()) {
                            QuickActionCard(
                                title: "Log Food",
                                icon: "plus.circle.fill",
                                color: .green
                            )
                        }
                        .buttonStyle(PlainButtonStyle())

                        NavigationLink(destination: DailyNutritionStatsView(
                            summary: .sampleSummary,
                            foodLogs: FoodLog.sampleLogs,
                            date: Date()
                        )) {
                            QuickActionCard(
                                title: "View Progress",
                                icon: "chart.line.uptrend.xyaxis",
                                color: .purple
                            )
                        }
                        .buttonStyle(PlainButtonStyle())

                        NavigationLink(destination: NutritionLabelScanView(
                            onNutritionExtracted: { result in
                                print("Nutrition extracted: \(result.summary)")
                                // TODO: Handle nutrition extraction result
                            },
                            onFoodCreated: { food in
                                Task {
                                    do {
                                        let foodService = FoodService()
                                        let savedFood = try await foodService.createFood(food)
                                        print("Food saved successfully: \(savedFood.name)")
                                    } catch {
                                        print("Failed to save food: \(error.localizedDescription)")
                                    }
                                }
                            }
                        )) {
                            QuickActionCard(
                                title: "Scan Label",
                                icon: "doc.viewfinder",
                                color: .orange
                            )
                        }
                        .buttonStyle(PlainButtonStyle())

                        NavigationLink(destination: SettingsView()) {
                            QuickActionCard(
                                title: "Settings",
                                icon: "gear",
                                color: .gray
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    Spacer()
                }
                .padding()
                .navigationTitle("Dashboard")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Sign Out") {
                            Task {
                                try? await authManager.signOut()
                            }
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .tabItem {
                Image(systemName: "house.fill")
                Text("Home")
            }

            // My Foods Tab
            NavigationView {
                FoodListView()
            }
            .tabItem {
                Image(systemName: "list.bullet.rectangle")
                Text("My Foods")
            }

        }
    }

}

// MARK: - Supporting Views

struct QuickActionCard: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(color)

            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}


#Preview {
    ContentView()
}
