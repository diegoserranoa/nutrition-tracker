//
//  RealtimeManager.swift
//  NutritionTrackerV2
//
//  High-level manager for coordinating real-time data synchronization across the app
//

import Foundation
import Combine
import OSLog
import UIKit

// MARK: - Realtime Manager State

enum RealtimeManagerState: Equatable {
    case inactive
    case initializing
    case active
    case reconnecting
    case suspended
    case error(String)

    var isActive: Bool {
        switch self {
        case .active:
            return true
        default:
            return false
        }
    }

    var description: String {
        switch self {
        case .inactive:
            return "Inactive"
        case .initializing:
            return "Initializing..."
        case .active:
            return "Active"
        case .reconnecting:
            return "Reconnecting..."
        case .suspended:
            return "Suspended"
        case .error(let message):
            return "Error: \(message)"
        }
    }
}

// MARK: - Realtime Manager Configuration

struct RealtimeManagerConfig {
    let autoStartOnInit: Bool
    let reconnectOnError: Bool
    let maxReconnectAttempts: Int
    let reconnectDelay: TimeInterval
    let heartbeatInterval: TimeInterval
    let subscriptionTimeout: TimeInterval

    static let `default` = RealtimeManagerConfig(
        autoStartOnInit: false,
        reconnectOnError: true,
        maxReconnectAttempts: 5,
        reconnectDelay: 2.0,
        heartbeatInterval: 30.0,
        subscriptionTimeout: 10.0
    )

    static let aggressive = RealtimeManagerConfig(
        autoStartOnInit: true,
        reconnectOnError: true,
        maxReconnectAttempts: 10,
        reconnectDelay: 1.0,
        heartbeatInterval: 15.0,
        subscriptionTimeout: 5.0
    )
}

// MARK: - Connection Statistics

struct ConnectionStatistics {
    var totalConnections: Int = 0
    var successfulConnections: Int = 0
    var failedConnections: Int = 0
    var reconnectionAttempts: Int = 0
    var totalUptime: TimeInterval = 0
    var lastConnectedAt: Date?
    var lastDisconnectedAt: Date?

    var connectionSuccessRate: Double {
        guard totalConnections > 0 else { return 0.0 }
        return Double(successfulConnections) / Double(totalConnections)
    }

    var averageConnectionDuration: TimeInterval {
        guard successfulConnections > 0 else { return 0.0 }
        return totalUptime / Double(successfulConnections)
    }
}

// MARK: - Realtime Manager

@MainActor
class RealtimeManager: ObservableObject {

    // MARK: - Singleton

    static let shared = RealtimeManager()

    // MARK: - Properties

    private let config: RealtimeManagerConfig
    private let logger = Logger(subsystem: "com.nutritiontracker.realtime", category: "RealtimeManager")

    // Core subscription manager
    private let subscriptionManager: RealtimeSubscriptionManager

    // Published state
    @Published var state: RealtimeManagerState = .inactive
    @Published var isConnected: Bool = false
    @Published var connectionStatistics = ConnectionStatistics()

    // Private state tracking
    private var reconnectAttempts: Int = 0
    private var connectionStartTime: Date?
    private var heartbeatTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?

    // Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()

    // Publishers for external consumption
    var foodEvents: AnyPublisher<RealtimeEventData<Food>, Never> {
        subscriptionManager.foodEvents
    }

    var foodLogEvents: AnyPublisher<RealtimeEventData<FoodLog>, Never> {
        subscriptionManager.foodLogEvents
    }

    // MARK: - Initialization

    init(config: RealtimeManagerConfig = .default, subscriptionManager: RealtimeSubscriptionManager? = nil) {
        self.config = config
        self.subscriptionManager = subscriptionManager ?? RealtimeSubscriptionManager()

        setupSubscriptionManagerBinding()
        setupApplicationLifecycleHandlers()

        logger.info("RealtimeManager initialized with config: autoStart=\(config.autoStartOnInit)")

        if config.autoStartOnInit {
            Task {
                await start()
            }
        }
    }

    deinit {
        // Perform cleanup synchronously in deinit (nonisolated context)
        heartbeatTask?.cancel()
        reconnectTask?.cancel()
        cancellables.removeAll()

        // Note: subscriptionManager.stopSubscriptions() is called separately
        // since deinit cannot call MainActor-isolated methods
    }

    // MARK: - Public Interface

    /// Start real-time synchronization
    func start() async {
        guard state != .active && state != .initializing else {
            logger.info("RealtimeManager already active or initializing")
            return
        }

        logger.info("Starting RealtimeManager")
        state = .initializing
        connectionStartTime = Date()

        await subscriptionManager.startSubscriptions()

        state = .active
        isConnected = true
        reconnectAttempts = 0

        // Update statistics
        connectionStatistics.totalConnections += 1
        connectionStatistics.successfulConnections += 1
        connectionStatistics.lastConnectedAt = Date()

        // Start heartbeat monitoring
        startHeartbeat()

        logger.info("RealtimeManager started successfully")
    }

    /// Stop real-time synchronization
    func stop() {
        guard state != .inactive else {
            logger.info("RealtimeManager already inactive")
            return
        }

        logger.info("Stopping RealtimeManager")

        // Stop subscriptions
        subscriptionManager.stopSubscriptions()

        // Clean up tasks
        heartbeatTask?.cancel()
        reconnectTask?.cancel()
        heartbeatTask = nil
        reconnectTask = nil

        // Update state and statistics
        updateConnectionStatistics(disconnected: true)
        state = .inactive
        isConnected = false

        logger.info("RealtimeManager stopped")
    }

    /// Suspend real-time synchronization (temporary pause)
    func suspend() {
        guard state == .active else {
            logger.info("Cannot suspend RealtimeManager - not active")
            return
        }

        logger.info("Suspending RealtimeManager")
        state = .suspended

        // Pause heartbeat but keep subscriptions
        heartbeatTask?.cancel()
        heartbeatTask = nil
    }

    /// Resume from suspended state
    func resume() async {
        guard state == .suspended else {
            logger.info("Cannot resume RealtimeManager - not suspended")
            return
        }

        logger.info("Resuming RealtimeManager")

        // Resume heartbeat
        startHeartbeat()
        state = .active

        // Verify connections are still working
        await performHealthCheck()
    }

    /// Force reconnection
    func reconnect() async {
        logger.info("Forcing RealtimeManager reconnection")

        stop()

        // Wait a moment before reconnecting
        try? await Task.sleep(for: .seconds(1))

        await start()
    }

    /// Get current connection health status
    func getHealthStatus() -> (isHealthy: Bool, details: String) {
        switch state {
        case .active:
            let uptime = connectionStartTime?.timeIntervalSinceNow.magnitude ?? 0
            return (true, "Connected for \(Int(uptime))s")
        case .inactive:
            return (false, "Not connected")
        case .error(let message):
            return (false, "Error: \(message)")
        case .reconnecting:
            return (false, "Reconnecting (attempt \(reconnectAttempts)/\(config.maxReconnectAttempts))")
        case .suspended:
            return (false, "Suspended")
        case .initializing:
            return (false, "Initializing connection")
        }
    }

    // MARK: - Private Methods

    private func setupSubscriptionManagerBinding() {
        // Monitor subscription manager state changes
        subscriptionManager.$isConnected
            .sink { [weak self] connected in
                Task { @MainActor in
                    await self?.handleSubscriptionManagerStateChange(connected: connected)
                }
            }
            .store(in: &cancellables)

        subscriptionManager.$lastError
            .compactMap { $0 }
            .sink { [weak self] error in
                Task { @MainActor in
                    self?.handleConnectionError(error)
                }
            }
            .store(in: &cancellables)
    }

    private func setupApplicationLifecycleHandlers() {
        // Handle app lifecycle events
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.suspend()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.resume()
                }
            }
            .store(in: &cancellables)
    }

    private func handleSubscriptionManagerStateChange(connected: Bool) async {
        if !connected && state == .active {
            // Connection lost while we were active
            logger.warning("Connection lost - attempting reconnection")
            await attemptReconnection()
        }
    }

    private func handleConnectionError(_ error: Error) {
        logger.error("Connection error: \(error.localizedDescription)")

        connectionStatistics.failedConnections += 1
        state = .error(error.localizedDescription)

        if config.reconnectOnError && reconnectAttempts < config.maxReconnectAttempts {
            Task {
                await attemptReconnection()
            }
        }
    }

    private func attemptReconnection() async {
        guard reconnectAttempts < config.maxReconnectAttempts else {
            logger.error("Max reconnection attempts reached")
            state = .error("Max reconnection attempts exceeded")
            return
        }

        reconnectAttempts += 1
        connectionStatistics.reconnectionAttempts += 1
        state = .reconnecting

        logger.info("Attempting reconnection \(self.reconnectAttempts)/\(self.config.maxReconnectAttempts)")

        // Cancel any existing reconnect task
        reconnectTask?.cancel()

        reconnectTask = Task {
            // Wait before attempting reconnection
            try? await Task.sleep(for: .seconds(config.reconnectDelay))

            guard !Task.isCancelled else { return }

            // Stop current subscriptions
            subscriptionManager.stopSubscriptions()

            // Wait a moment
            try? await Task.sleep(for: .seconds(0.5))

            guard !Task.isCancelled else { return }

            // Attempt to restart
            await start()
        }
    }

    private func startHeartbeat() {
        heartbeatTask?.cancel()

        heartbeatTask = Task {
            while !Task.isCancelled && state == .active {
                try? await Task.sleep(for: .seconds(config.heartbeatInterval))

                guard !Task.isCancelled else { break }

                await performHealthCheck()
            }
        }
    }

    private func performHealthCheck() async {
        // Simple health check - verify subscription manager is connected
        if !subscriptionManager.isConnected && state == .active {
            logger.warning("Health check failed - subscription manager disconnected")
            await attemptReconnection()
        }
    }

    private func updateConnectionStatistics(disconnected: Bool) {
        if disconnected {
            connectionStatistics.lastDisconnectedAt = Date()

            if let startTime = connectionStartTime {
                let sessionDuration = Date().timeIntervalSince(startTime)
                connectionStatistics.totalUptime += sessionDuration
            }

            connectionStartTime = nil
        }
    }

    private func cleanup() {
        logger.info("Cleaning up RealtimeManager")

        heartbeatTask?.cancel()
        reconnectTask?.cancel()
        cancellables.removeAll()

        subscriptionManager.stopSubscriptions()
    }
}

// MARK: - Extensions

extension RealtimeManager {

    /// Get formatted uptime string
    var uptimeString: String {
        guard let startTime = connectionStartTime else {
            return "Not connected"
        }

        let uptime = Date().timeIntervalSince(startTime)
        let hours = Int(uptime) / 3600
        let minutes = (Int(uptime) % 3600) / 60
        let seconds = Int(uptime) % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    /// Get connection statistics summary
    var statisticsSummary: String {
        let stats = connectionStatistics
        return """
        Connections: \(stats.successfulConnections)/\(stats.totalConnections)
        Success Rate: \(String(format: "%.1f%%", stats.connectionSuccessRate * 100))
        Reconnects: \(stats.reconnectionAttempts)
        Total Uptime: \(String(format: "%.1f", stats.totalUptime))s
        """
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension RealtimeManager {
    static func previewInstance() -> RealtimeManager {
        return RealtimeManager(config: .aggressive)
    }

    func simulateConnectionError() {
        handleConnectionError(NSError(domain: "RealtimeManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Simulated error"]))
    }
}
#endif
