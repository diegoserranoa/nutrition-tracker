//
//  RealtimeConnectionStatusView.swift
//  NutritionTrackerV2
//
//  Connection status indicator for real-time data synchronization
//

import SwiftUI

struct RealtimeConnectionStatusView: View {
    @ObservedObject var realtimeManager: RealtimeManager
    @State private var showingDetails = false

    var body: some View {
        HStack(spacing: 8) {
            // Connection indicator dot
            Circle()
                .fill(connectionColor)
                .frame(width: 8, height: 8)
                .animation(.easeInOut(duration: 0.3), value: realtimeManager.state)

            // Status text
            Text(statusText)
                .font(.caption2)
                .foregroundColor(.secondary)
                .animation(.none, value: realtimeManager.state)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onTapGesture {
            showingDetails = true
        }
        .alert("Real-time Connection", isPresented: $showingDetails) {
            if realtimeManager.state.isActive {
                Button("Disconnect") {
                    realtimeManager.stop()
                }
            } else {
                Button("Reconnect") {
                    Task {
                        await realtimeManager.start()
                    }
                }
            }
            Button("OK", role: .cancel) { }
        } message: {
            Text(detailedStatusMessage)
        }
    }

    // MARK: - Computed Properties

    private var connectionColor: Color {
        switch realtimeManager.state {
        case .active:
            return .green
        case .initializing, .reconnecting:
            return .yellow
        case .suspended:
            return .orange
        case .error:
            return .red
        case .inactive:
            return .gray
        }
    }

    private var statusText: String {
        switch realtimeManager.state {
        case .active:
            return "Live"
        case .initializing:
            return "Connecting..."
        case .reconnecting:
            return "Reconnecting..."
        case .suspended:
            return "Paused"
        case .error:
            return "Connection Issue"
        case .inactive:
            return "Offline"
        }
    }

    private var detailedStatusMessage: String {
        let (isHealthy, details) = realtimeManager.getHealthStatus()
        var message = realtimeManager.state.description

        if isHealthy {
            message += "\n\n" + realtimeManager.uptimeString
            message += "\n\n" + realtimeManager.statisticsSummary
        } else {
            message += "\n\n" + details
        }

        return message
    }
}

// MARK: - Compact Status View

struct CompactRealtimeStatusView: View {
    @ObservedObject var realtimeManager: RealtimeManager

    var body: some View {
        Circle()
            .fill(connectionColor)
            .frame(width: 6, height: 6)
            .animation(.easeInOut(duration: 0.3), value: realtimeManager.state)
    }

    private var connectionColor: Color {
        switch realtimeManager.state {
        case .active:
            return .green
        case .initializing, .reconnecting:
            return .yellow
        case .suspended:
            return .orange
        case .error:
            return .red
        case .inactive:
            return .gray
        }
    }
}

// MARK: - Previews

#if DEBUG
struct RealtimeConnectionStatusView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            RealtimeConnectionStatusView(realtimeManager: RealtimeManager.previewInstance())

            CompactRealtimeStatusView(realtimeManager: RealtimeManager.previewInstance())
        }
        .padding()
    }
}
#endif