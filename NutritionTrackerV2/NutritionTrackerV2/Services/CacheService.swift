//
//  CacheService.swift
//  NutritionTrackerV2
//
//  Intelligent caching layer for frequently accessed data and optimized retrieval
//

import Foundation
import OSLog
import UIKit

// MARK: - Cache Configuration

struct CacheConfiguration {
    let maxMemorySize: Int // In bytes
    let defaultTTL: TimeInterval // Time to live in seconds
    let maxSearchResults: Int
    let enableMemoryPressureHandling: Bool

    static let `default` = CacheConfiguration(
        maxMemorySize: 50 * 1024 * 1024, // 50MB
        defaultTTL: 300, // 5 minutes
        maxSearchResults: 100,
        enableMemoryPressureHandling: true
    )
}

// MARK: - Cache Entry

private class CacheEntry<T> {
    let value: T
    let timestamp: Date
    let ttl: TimeInterval

    init(value: T, ttl: TimeInterval) {
        self.value = value
        self.timestamp = Date()
        self.ttl = ttl
    }

    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > ttl
    }
}

// MARK: - Cache Statistics

struct CacheStatistics {
    let hitCount: Int
    let missCount: Int
    let totalRequests: Int
    let hitRate: Double
    let memoryUsage: Int
    let entryCount: Int

    var description: String {
        return """
        Cache Statistics:
        - Hit Rate: \(String(format: "%.2f", hitRate * 100))%
        - Total Requests: \(totalRequests)
        - Memory Usage: \(ByteCountFormatter.string(fromByteCount: Int64(memoryUsage), countStyle: .memory))
        - Entries: \(entryCount)
        """
    }
}

// MARK: - Cache Service Protocol

@MainActor
protocol CacheServiceProtocol {
    func get<T>(_ key: String, type: T.Type) -> T?
    func set<T>(_ key: String, value: T, ttl: TimeInterval?)
    func remove(_ key: String)
    func clear()
    func getStatistics() -> CacheStatistics
}

// MARK: - Cache Service Implementation

@MainActor
class CacheService: ObservableObject, CacheServiceProtocol {

    // MARK: - Properties

    private let configuration: CacheConfiguration
    private let logger = Logger(subsystem: "com.nutritiontracker.cache", category: "CacheService")

    // NSCache for automatic memory management
    private let foodCache = NSCache<NSString, CacheEntry<Food>>()
    private let searchResultsCache = NSCache<NSString, CacheEntry<[Food]>>()
    private let nutritionSummaryCache = NSCache<NSString, CacheEntry<DailyNutritionSummary>>()

    // Manual cache for small objects
    private var metadataCache: [String: CacheEntry<Any>] = [:]

    // Cache statistics
    private var hitCount = 0
    private var missCount = 0

    // Popular foods tracking
    private var foodPopularityScores: [UUID: Int] = [:]
    private var preloadedFoodIds: Set<UUID> = []

    // MARK: - Singleton

    static let shared = CacheService()

    // MARK: - Initialization

    init(configuration: CacheConfiguration = .default) {
        self.configuration = configuration
        setupCaches()
        setupMemoryPressureHandling()
    }

    private func setupCaches() {
        // Configure NSCache instances
        foodCache.countLimit = 500 // Maximum 500 food items
        foodCache.totalCostLimit = configuration.maxMemorySize / 3
        foodCache.name = "FoodCache"

        searchResultsCache.countLimit = configuration.maxSearchResults
        searchResultsCache.totalCostLimit = configuration.maxMemorySize / 3
        searchResultsCache.name = "SearchResultsCache"

        nutritionSummaryCache.countLimit = 100 // 100 daily summaries
        nutritionSummaryCache.totalCostLimit = configuration.maxMemorySize / 3
        nutritionSummaryCache.name = "NutritionSummaryCache"

        logger.info("Cache service initialized with max memory: \(ByteCountFormatter.string(fromByteCount: Int64(self.configuration.maxMemorySize), countStyle: .memory))")
    }

    private func setupMemoryPressureHandling() {
        guard configuration.enableMemoryPressureHandling else { return }

        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleMemoryPressure()
            }
        }
    }

    // MARK: - Generic Cache Operations

    func get<T>(_ key: String, type: T.Type) -> T? {
        let cacheKey = NSString(string: key)

        // Try different caches based on type
        if type == Food.self {
            if let entry = foodCache.object(forKey: cacheKey) {
                return handleCacheHit(entry: entry, key: key) as? T
            }
        } else if type == [Food].self {
            if let entry = searchResultsCache.object(forKey: cacheKey) {
                return handleCacheHit(entry: entry, key: key) as? T
            }
        } else if type == DailyNutritionSummary.self {
            if let entry = nutritionSummaryCache.object(forKey: cacheKey) {
                return handleCacheHit(entry: entry, key: key) as? T
            }
        } else {
            // Check metadata cache
            if let entry = metadataCache[key] {
                return handleCacheHit(entry: entry, key: key) as? T
            }
        }

        missCount += 1
        logger.debug("Cache miss for key: \(key)")
        return nil
    }

    func set<T>(_ key: String, value: T, ttl: TimeInterval? = nil) {
        let actualTTL = ttl ?? configuration.defaultTTL
        let cacheKey = NSString(string: key)

        // Route to appropriate cache based on type
        if let food = value as? Food {
            let entry = CacheEntry(value: food, ttl: actualTTL)
            let cost = estimateMemorySize(of: food)
            foodCache.setObject(entry, forKey: cacheKey, cost: cost)

            // Track popularity
            trackFoodAccess(foodId: food.id)

        } else if let foods = value as? [Food] {
            let entry = CacheEntry(value: foods, ttl: actualTTL)
            let cost = foods.reduce(0) { $0 + estimateMemorySize(of: $1) }
            searchResultsCache.setObject(entry, forKey: cacheKey, cost: cost)

        } else if let summary = value as? DailyNutritionSummary {
            let entry = CacheEntry(value: summary, ttl: actualTTL)
            let cost = estimateMemorySize(of: summary)
            nutritionSummaryCache.setObject(entry, forKey: cacheKey, cost: cost)

        } else {
            // Store in metadata cache
            let entry = CacheEntry(value: value as Any, ttl: actualTTL)
            metadataCache[key] = entry
        }

        logger.debug("Cached value for key: \(key) with TTL: \(actualTTL)s")
    }

    func remove(_ key: String) {
        let cacheKey = NSString(string: key)

        foodCache.removeObject(forKey: cacheKey)
        searchResultsCache.removeObject(forKey: cacheKey)
        nutritionSummaryCache.removeObject(forKey: cacheKey)
        metadataCache.removeValue(forKey: key)

        logger.debug("Removed cache entry for key: \(key)")
    }

    func clear() {
        foodCache.removeAllObjects()
        searchResultsCache.removeAllObjects()
        nutritionSummaryCache.removeAllObjects()
        metadataCache.removeAll()

        hitCount = 0
        missCount = 0
        foodPopularityScores.removeAll()
        preloadedFoodIds.removeAll()

        logger.info("Cleared all cache entries")
    }

    // MARK: - Specialized Food Caching

    func cacheFood(_ food: Food, ttl: TimeInterval? = nil) {
        let key = "food_\(food.id.uuidString)"
        set(key, value: food, ttl: ttl)
    }

    func getCachedFood(id: UUID) -> Food? {
        let key = "food_\(id.uuidString)"
        return get(key, type: Food.self)
    }

    func cacheSearchResults(query: String, results: [Food], ttl: TimeInterval? = nil) {
        let key = "search_\(query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))"
        set(key, value: results, ttl: ttl)
    }

    func getCachedSearchResults(query: String) -> [Food]? {
        let key = "search_\(query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))"
        return get(key, type: [Food].self)
    }

    func cacheDailyNutritionSummary(_ summary: DailyNutritionSummary, for date: Date, userId: UUID) {
        let dateString = ISO8601DateFormatter().string(from: date)
        let key = "nutrition_summary_\(userId.uuidString)_\(dateString)"
        set(key, value: summary, ttl: 3600) // 1 hour TTL for nutrition summaries
    }

    func getCachedDailyNutritionSummary(for date: Date, userId: UUID) -> DailyNutritionSummary? {
        let dateString = ISO8601DateFormatter().string(from: date)
        let key = "nutrition_summary_\(userId.uuidString)_\(dateString)"
        return get(key, type: DailyNutritionSummary.self)
    }

    // MARK: - Popular Foods & Preloading

    private func trackFoodAccess(foodId: UUID) {
        foodPopularityScores[foodId, default: 0] += 1

        // Preload popular foods if they reach a threshold
        if let score = foodPopularityScores[foodId], score >= 5 && !preloadedFoodIds.contains(foodId) {
            markForPreloading(foodId: foodId)
        }
    }

    private func markForPreloading(foodId: UUID) {
        preloadedFoodIds.insert(foodId)
        logger.info("Marked food \(foodId) for preloading due to popularity")
    }

    func getPopularFoodIds(limit: Int = 20) -> [UUID] {
        return foodPopularityScores
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { $0.key }
    }

    func getFoodsToPreload() -> Set<UUID> {
        return preloadedFoodIds
    }

    // MARK: - Cache Invalidation

    func invalidateUserData(userId: UUID) {
        let userPrefix = userId.uuidString

        // Remove any user-specific data from metadata cache
        for key in metadataCache.keys {
            if key.contains(userPrefix) {
                metadataCache.removeValue(forKey: key)
            }
        }

        // Clear nutrition summary cache since NSCache doesn't support selective removal
        // Daily nutrition summaries are user-specific, so clearing all is the only option
        nutritionSummaryCache.removeAllObjects()

        logger.info("Invalidated cache data for user: \(userId)")
    }

    func invalidateFoodData(foodId: UUID) {
        let key = "food_\(foodId.uuidString)"
        remove(key)

        // Also invalidate any search results that might contain this food
        searchResultsCache.removeAllObjects()

        logger.info("Invalidated cache data for food: \(foodId)")
    }

    func cleanupExpiredEntries() {
        // Clean metadata cache manually
        metadataCache = metadataCache.filter { _, entry in
            !entry.isExpired
        }

        logger.debug("Cleaned up expired cache entries")
    }

    // MARK: - Memory Management

    private func handleMemoryPressure() {
        logger.warning("Handling memory pressure - clearing caches")

        // Clear search results first (least critical)
        searchResultsCache.removeAllObjects()

        // Clear older nutrition summaries
        nutritionSummaryCache.removeAllObjects()

        // NSCache doesn't provide a way to enumerate keys, so we'll just reduce count limit
        // Note: In a more sophisticated implementation, we could preserve popular foods

        // Reduce cache limits
        foodCache.countLimit = max(100, foodCache.countLimit / 2)
        searchResultsCache.countLimit = max(20, searchResultsCache.countLimit / 2)

        logger.info("Reduced cache sizes due to memory pressure")
    }

    // MARK: - Statistics & Monitoring

    func getStatistics() -> CacheStatistics {
        let totalRequests = hitCount + missCount
        let hitRate = totalRequests > 0 ? Double(hitCount) / Double(totalRequests) : 0.0

        let estimatedMemoryUsage = estimateCurrentMemoryUsage()
        // Note: NSCache doesn't provide actual count, so we use limits + metadata count as approximation
        let totalEntries = metadataCache.count // Only metadata cache provides actual count

        return CacheStatistics(
            hitCount: hitCount,
            missCount: missCount,
            totalRequests: totalRequests,
            hitRate: hitRate,
            memoryUsage: estimatedMemoryUsage,
            entryCount: totalEntries
        )
    }

    // MARK: - Helper Methods

    private func handleCacheHit<T>(entry: CacheEntry<T>, key: String) -> T? {
        guard !entry.isExpired else {
            remove(key)
            missCount += 1
            logger.debug("Cache entry expired for key: \(key)")
            return nil
        }

        hitCount += 1
        logger.debug("Cache hit for key: \(key)")
        return entry.value
    }

    private func estimateMemorySize(of food: Food) -> Int {
        // Rough estimation of Food object memory size
        let baseSize = 200 // Base object overhead
        let nameSize = food.name.utf8.count
        let brandSize = food.brand?.utf8.count ?? 0
        let descriptionSize = food.description?.utf8.count ?? 0

        return baseSize + nameSize + brandSize + descriptionSize
    }

    private func estimateMemorySize(of summary: DailyNutritionSummary) -> Int {
        // Rough estimation of DailyNutritionSummary memory size
        let baseSize = 100
        let mealBreakdownSize = summary.mealBreakdown.count * 50

        return baseSize + mealBreakdownSize
    }

    private func estimateCurrentMemoryUsage() -> Int {
        // Conservative estimate based on cache limits (actual usage likely lower)
        // NSCache doesn't provide actual memory usage or current count
        let estimatedFoodCacheSize = min(foodCache.countLimit, 100) * 300 // ~300 bytes per food item
        let estimatedSearchCacheSize = min(searchResultsCache.countLimit, 20) * 1500 // ~1500 bytes per search result
        let estimatedSummaryCacheSize = min(nutritionSummaryCache.countLimit, 50) * 200 // ~200 bytes per summary
        let estimatedMetadataSize = metadataCache.count * 100 // ~100 bytes per metadata entry

        return estimatedFoodCacheSize + estimatedSearchCacheSize + estimatedSummaryCacheSize + estimatedMetadataSize
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
