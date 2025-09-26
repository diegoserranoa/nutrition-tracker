//
//  SettingsView.swift
//  NutritionTrackerV2
//
//  Settings and preferences view for the nutrition tracking app
//

import SwiftUI
import Supabase

struct SettingsView: View {
    @StateObject private var authManager = AuthManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingSignOutConfirmation = false

    var body: some View {
        NavigationView {
            List {
                // Profile Section
                Section("Profile") {
                    if let user = authManager.currentUser {
                        ProfileRow(label: "Email", value: user.email ?? "Not available")
                        ProfileRow(label: "User ID", value: String(user.id.uuidString.prefix(8)) + "...")

                        ProfileRow(label: "Member Since", value: DateFormatter.settingsDate.string(from: user.createdAt))
                    }
                }

                // App Settings Section
                Section("App Settings") {
                    SettingsRow(
                        icon: "bell.fill",
                        title: "Notifications",
                        subtitle: "Manage app notifications",
                        color: .orange
                    ) {
                        // TODO: Navigate to notification settings
                    }

                    SettingsRow(
                        icon: "chart.bar.fill",
                        title: "Units",
                        subtitle: "Weight, volume, and nutrition units",
                        color: .blue
                    ) {
                        // TODO: Navigate to units settings
                    }

                    SettingsRow(
                        icon: "target",
                        title: "Goals",
                        subtitle: "Set your nutrition targets",
                        color: .green
                    ) {
                        // TODO: Navigate to goals settings
                    }
                }

                // Data & Privacy Section
                Section("Data & Privacy") {
                    SettingsRow(
                        icon: "icloud.fill",
                        title: "Data Sync",
                        subtitle: "Manage cloud synchronization",
                        color: .cyan
                    ) {
                        // TODO: Navigate to data sync settings
                    }

                    SettingsRow(
                        icon: "lock.fill",
                        title: "Privacy",
                        subtitle: "Privacy and data protection",
                        color: .purple
                    ) {
                        // TODO: Navigate to privacy settings
                    }

                    SettingsRow(
                        icon: "arrow.down.circle.fill",
                        title: "Export Data",
                        subtitle: "Download your nutrition data",
                        color: .indigo
                    ) {
                        // TODO: Implement data export
                    }
                }

                // Support Section
                Section("Support") {
                    SettingsRow(
                        icon: "questionmark.circle.fill",
                        title: "Help & FAQ",
                        subtitle: "Get help and find answers",
                        color: .yellow
                    ) {
                        // TODO: Navigate to help
                    }

                    SettingsRow(
                        icon: "envelope.fill",
                        title: "Contact Support",
                        subtitle: "Get in touch with our team",
                        color: .mint
                    ) {
                        // TODO: Open contact support
                    }

                    SettingsRow(
                        icon: "star.fill",
                        title: "Rate App",
                        subtitle: "Rate us on the App Store",
                        color: .yellow
                    ) {
                        // TODO: Open App Store rating
                    }
                }

                // Account Section
                Section("Account") {
                    SettingsRow(
                        icon: "person.crop.circle.fill",
                        title: "Account Settings",
                        subtitle: "Manage your account",
                        color: .gray
                    ) {
                        // TODO: Navigate to account settings
                    }

                    Button {
                        showingSignOutConfirmation = true
                    } label: {
                        SettingsRow(
                            icon: "rectangle.portrait.and.arrow.right.fill",
                            title: "Sign Out",
                            subtitle: "Sign out of your account",
                            color: .red,
                            isDestructive: true
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
        .confirmationDialog("Sign Out", isPresented: $showingSignOutConfirmation, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) {
                Task {
                    try? await authManager.signOut()
                    dismiss()
                }
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to sign out? You'll need to sign in again to access your data.")
        }
    }
}

// MARK: - Supporting Views

struct ProfileRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .fontWeight(.medium)
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    var isDestructive: Bool = false
    let action: (() -> Void)?

    init(icon: String, title: String, subtitle: String, color: Color, isDestructive: Bool = false, action: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.color = color
        self.isDestructive = isDestructive
        self.action = action
    }

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isDestructive ? .red : color)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(isDestructive ? .red : .primary)
                        .multilineTextAlignment(.leading)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                if action != nil && !isDestructive {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Extensions

private extension DateFormatter {
    static let settingsDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()
}

// MARK: - Previews

#Preview {
    SettingsView()
}