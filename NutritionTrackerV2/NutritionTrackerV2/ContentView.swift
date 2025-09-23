//
//  ContentView.swift
//  NutritionTrackerV2
//
//  Created by Diego Serrano on 9/22/25.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var authManager = AuthManager.shared

    var body: some View {
        Group {
            if authManager.isUserAuthenticated {
                // User is authenticated - show main app with tabs
                AuthenticatedContentView(viewContext: viewContext)
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
    let viewContext: NSManagedObjectContext
    @StateObject private var authManager = AuthManager.shared

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Item.timestamp, ascending: true)],
        animation: .default)
    private var items: FetchedResults<Item>

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
                        QuickActionCard(
                            title: "Log Food",
                            icon: "plus.circle.fill",
                            color: .green
                        ) {
                            // TODO: Navigate to food logging
                        }

                        QuickActionCard(
                            title: "View Progress",
                            icon: "chart.line.uptrend.xyaxis",
                            color: .blue
                        ) {
                            // TODO: Navigate to progress view
                        }

                        QuickActionCard(
                            title: "Scan Barcode",
                            icon: "barcode.viewfinder",
                            color: .orange
                        ) {
                            // TODO: Navigate to barcode scanner
                        }

                        QuickActionCard(
                            title: "Settings",
                            icon: "gear",
                            color: .purple
                        ) {
                            // TODO: Navigate to settings
                        }
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

            // Core Data Items Tab (legacy)
            NavigationView {
                List {
                    ForEach(items) { item in
                        NavigationLink {
                            Text("Item at \(item.timestamp!, formatter: itemFormatter)")
                        } label: {
                            Text(item.timestamp!, formatter: itemFormatter)
                        }
                    }
                    .onDelete(perform: deleteItems)
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        EditButton()
                    }
                    ToolbarItem {
                        Button(action: addItem) {
                            Label("Add Item", systemImage: "plus")
                        }
                    }
                }
                .navigationTitle("Items")
            }
            .tabItem {
                Image(systemName: "list.bullet")
                Text("Items")
            }

            // Testing tabs
            SupabaseTestView()
                .tabItem {
                    Image(systemName: "network")
                    Text("Supabase Test")
                }

            AuthTestView()
                .tabItem {
                    Image(systemName: "person.circle")
                    Text("Auth Test")
                }
        }
    }

    private func addItem() {
        withAnimation {
            let newItem = Item(context: viewContext)
            newItem.timestamp = Date()

            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { items[$0] }.forEach(viewContext.delete)

            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

// MARK: - Supporting Views

struct QuickActionCard: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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
        .buttonStyle(PlainButtonStyle())
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
