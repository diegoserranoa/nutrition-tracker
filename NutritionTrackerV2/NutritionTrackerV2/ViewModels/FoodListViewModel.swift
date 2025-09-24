//
//  FoodListViewModel.swift
//  NutritionTrackerV2
//
//  ViewModel for managing food list data with Supabase integration
//

import Foundation
import Combine
import OSLog

@MainActor
class FoodListViewModel: ObservableObject {
    @Published var foods: [Food] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var searchText = ""

    private let foodService: FoodService
    private let logger = Logger(subsystem: "com.nutritiontracker.foodlist", category: "FoodListViewModel")
    private var cancellables = Set<AnyCancellable>()

    // Computed property for filtered foods based on search text
    var filteredFoods: [Food] {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return foods
        } else {
            return foods.filter { food in
                food.name.localizedCaseInsensitiveContains(searchText) ||
                food.brand?.localizedCaseInsensitiveContains(searchText) == true ||
                food.description?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
    }

    init(foodService: FoodService? = nil) {
        self.foodService = foodService ?? FoodService()
        setupSearchSubscription()
    }

    private func setupSearchSubscription() {
        // Debounce search text changes to avoid too many API calls
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                // For now, we just filter locally. Later we could implement server-side search
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    func fetchFoods() {
        Task {
            await loadFoods()
        }
    }

    func refreshFoods() {
        Task {
            await loadFoods(forceRefresh: true)
        }
    }

    private func loadFoods(forceRefresh: Bool = false) async {
        isLoading = true
        error = nil

        do {
            logger.info("Fetching foods from service (forceRefresh: \(forceRefresh))")

            let searchParams = FoodSearchParameters(query: nil, limit: 100, offset: 0)
            let fetchedFoods = try await foodService.searchFoods(parameters: searchParams)

            foods = fetchedFoods.sorted { food1, food2 in
                food1.name.localizedCaseInsensitiveCompare(food2.name) == .orderedAscending
            }

            logger.info("Successfully fetched \(self.foods.count) foods")

        } catch {
            logger.error("Failed to fetch foods: \(error.localizedDescription)")
            self.error = error
        }

        isLoading = false
    }

    func deleteFood(_ food: Food) async {
        do {
            logger.info("Deleting food: \(food.name)")

            try await foodService.deleteFood(id: food.id)

            // Remove from local array
            foods.removeAll { $0.id == food.id }

            logger.info("Successfully deleted food: \(food.name)")

        } catch {
            logger.error("Failed to delete food: \(error.localizedDescription)")
            self.error = error
        }
    }

    func createFood(_ food: Food) async {
        do {
            logger.info("Creating new food: \(food.name)")

            let createdFood = try await foodService.createFood(food)

            // Add to local array and resort
            foods.append(createdFood)
            foods.sort { food1, food2 in
                food1.name.localizedCaseInsensitiveCompare(food2.name) == .orderedAscending
            }

            logger.info("Successfully created food: \(createdFood.name)")

        } catch {
            logger.error("Failed to create food: \(error.localizedDescription)")
            self.error = error
        }
    }

    func updateFood(_ food: Food) async {
        do {
            logger.info("Updating food: \(food.name)")

            let updatedFood = try await foodService.updateFood(food)

            // Update in local array
            if let index = foods.firstIndex(where: { $0.id == updatedFood.id }) {
                foods[index] = updatedFood

                // Resort the array
                foods.sort { food1, food2 in
                    food1.name.localizedCaseInsensitiveCompare(food2.name) == .orderedAscending
                }
            }

            logger.info("Successfully updated food: \(updatedFood.name)")

        } catch {
            logger.error("Failed to update food: \(error.localizedDescription)")
            self.error = error
        }
    }

    func searchFoods(query: String) async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            await loadFoods()
            return
        }

        isLoading = true
        error = nil

        do {
            logger.info("Searching foods with query: '\(query)'")

            let searchParams = FoodSearchParameters(query: query, limit: 100, offset: 0)
            let searchResults = try await foodService.searchFoods(parameters: searchParams)

            foods = searchResults.sorted { food1, food2 in
                food1.name.localizedCaseInsensitiveCompare(food2.name) == .orderedAscending
            }

            logger.info("Search returned \(self.foods.count) results")

        } catch {
            logger.error("Food search failed: \(error.localizedDescription)")
            self.error = error
        }

        isLoading = false
    }

    func clearError() {
        error = nil
    }
}