//
//  FoodSelectionView.swift
//  NutritionTrackerV2
//
//  Food selection interface for logging meals with quantity and unit entry
//

import SwiftUI

struct FoodSelectionView: View {
    let mealType: MealType
    let onFoodSelected: (Food, Double, String) -> Void
    @Environment(\.dismiss) private var dismiss

    @StateObject private var foodListViewModel = FoodListViewModel()
    @State private var selectedFood: Food?
    @State private var showingQuantityEntry = false
    @State private var quantity: String = ""
    @State private var selectedUnit: String = ""

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
                    initialUnit: selectedUnit
                ) { finalFood, finalQuantity, finalUnit in
                    onFoodSelected(finalFood, finalQuantity, finalUnit)
                    dismiss()
                }
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
        FoodSelectionView(mealType: .breakfast) { food, quantity, unit in
            print("Selected: \(food.name), \(quantity) \(unit)")
        }
    }
}
#endif