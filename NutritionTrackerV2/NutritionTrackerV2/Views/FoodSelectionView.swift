//
//  FoodSelectionView.swift
//  NutritionTrackerV2
//
//  Food selection interface for logging meals with quantity and unit entry
//

import SwiftUI

struct FoodSelectionView: View {
    let mealType: MealType
    let selectedDate: Date
    let onFoodSelected: (Food, Double, String, Date) -> Void
    @Environment(\.dismiss) private var dismiss

    @StateObject private var foodListViewModel = FoodListViewModel()
    @State private var selectedFood: Food?
    @State private var showingQuantityEntry = false
    @State private var quantity: String = ""
    @State private var selectedUnit: String = ""
    @State private var showingCamera = false
    @State private var capturedImage: UIImage?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                searchBar

                // Food List
                Group {
                    if foodListViewModel.isLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Loading foods...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let error = foodListViewModel.error {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 48))
                                .foregroundColor(.red)

                            Text("Error loading foods")
                                .font(.headline)
                                .foregroundColor(.red)

                            Text(error.localizedDescription)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)

                            Button("Try Again") {
                                foodListViewModel.fetchFoods()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                    } else if foodListViewModel.filteredFoods.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: foodListViewModel.searchText.isEmpty ? "fork.knife.circle" : "magnifyingglass")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)

                            Text(foodListViewModel.searchText.isEmpty ? "No foods yet" : "No foods found")
                                .font(.headline)
                                .foregroundColor(.gray)

                            Text(foodListViewModel.searchText.isEmpty ? "Add some foods first" : "Try a different search term")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(foodListViewModel.filteredFoods) { food in
                                FoodSelectionRowView(food: food) {
                                    selectedFood = food
                                    quantity = String(food.servingSize)
                                    selectedUnit = food.servingUnit
                                    showingQuantityEntry = true
                                }
                            }
                        }
                        .refreshable {
                            foodListViewModel.refreshFoods()
                        }
                    }
                }
            }
            .navigationTitle("Add to \(mealType.displayName)")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingCamera = true
                    }) {
                        Image(systemName: "camera")
                            .font(.headline)
                    }
                }
            }
            .onAppear {
                if foodListViewModel.foods.isEmpty && !foodListViewModel.isLoading {
                    foodListViewModel.fetchFoods()
                }
            }
        }
        .sheet(isPresented: $showingQuantityEntry) {
            if let food = selectedFood {
                AdvancedServingSizeSelector(
                    food: food,
                    initialQuantity: quantity,
                    initialUnit: selectedUnit,
                    initialDate: selectedDate
                ) { finalFood, finalQuantity, finalUnit, finalDate in
                    onFoodSelected(finalFood, finalQuantity, finalUnit, finalDate)
                    dismiss()
                }
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraView(capturedImage: $capturedImage) { image in
                capturedImage = image
                // Here we would integrate with FoodImageClassifier
                handleCapturedImage(image)
            }
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search foods...", text: $foodListViewModel.searchText)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding()
    }

    // MARK: - Private Methods

    private func handleCapturedImage(_ image: UIImage) {
        // Initialize the food image classifier
        guard let classifier = FoodImageClassifier() else {
            print("Failed to initialize FoodImageClassifier")
            return
        }

        // Classify the captured image
        classifier.classify(image: image) { [weak foodListViewModel] result in
            DispatchQueue.main.async {
                if let foodType = result {
                    print("🍎 Detected food: \(foodType)")
                    // Filter the food list based on the detected food type
                    foodListViewModel?.searchText = foodType
                } else {
                    print("❓ Could not identify food in the image")
                    // Could show an alert or message to the user
                }
            }
        }
    }
}

struct FoodSelectionRowView: View {
    let food: Food
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(food.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if let brand = food.brand {
                        Text(brand)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    HStack {
                        Text("\(Int(food.calories)) cal")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        Text("\(food.servingSize.formatted()) \(food.servingUnit)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }
}

// QuantityEntryView has been replaced with AdvancedServingSizeSelector

#if DEBUG
struct FoodSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        FoodSelectionView(mealType: .breakfast, selectedDate: Date()) { food, quantity, unit, date in
            print("Selected: \(food.name), \(quantity) \(unit), \(date)")
        }
    }
}
#endif