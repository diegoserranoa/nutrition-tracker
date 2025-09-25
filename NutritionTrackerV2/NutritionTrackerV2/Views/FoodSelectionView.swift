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
                QuantityEntryView(
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

struct QuantityEntryView: View {
    let food: Food
    @State private var quantity: String
    @State private var selectedUnit: String
    @Environment(\.dismiss) private var dismiss

    let onSave: (Food, Double, String) -> Void

    init(food: Food, initialQuantity: String, initialUnit: String, onSave: @escaping (Food, Double, String) -> Void) {
        self.food = food
        self._quantity = State(initialValue: initialQuantity)
        self._selectedUnit = State(initialValue: initialUnit)
        self.onSave = onSave
    }

    private var isValidInput: Bool {
        Double(quantity) != nil && Double(quantity)! > 0 && !selectedUnit.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(food.name)
                            .font(.title2)
                            .fontWeight(.bold)

                        if let brand = food.brand {
                            Text(brand)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text("\(Int(food.calories)) cal per \(food.servingSize.formatted()) \(food.servingUnit)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("Quantity") {
                    HStack {
                        TextField("Amount", text: $quantity)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)

                        TextField("Unit", text: $selectedUnit)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Common units:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                            ForEach(commonUnits, id: \.self) { unit in
                                Button(unit) {
                                    selectedUnit = unit
                                }
                                .buttonStyle(.bordered)
                                .font(.caption)
                            }
                        }
                    }
                    .padding(.top, 8)
                }

                if let quantityValue = Double(quantity), quantityValue > 0 {
                    Section("Nutrition Preview") {
                        let multiplier = quantityValue / food.servingSize

                        HStack {
                            Text("Calories")
                            Spacer()
                            Text("\((food.calories * multiplier).formatted(.number.precision(.fractionLength(0...1))))")
                                .fontWeight(.medium)
                        }

                        HStack {
                            Text("Protein")
                            Spacer()
                            Text("\((food.protein * multiplier).formatted(.number.precision(.fractionLength(0...1))))g")
                        }

                        HStack {
                            Text("Carbs")
                            Spacer()
                            Text("\((food.carbohydrates * multiplier).formatted(.number.precision(.fractionLength(0...1))))g")
                        }

                        HStack {
                            Text("Fat")
                            Spacer()
                            Text("\((food.fat * multiplier).formatted(.number.precision(.fractionLength(0...1))))g")
                        }
                    }
                }
            }
            .navigationTitle("Add Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        guard let quantityValue = Double(quantity) else { return }
                        onSave(food, quantityValue, selectedUnit.trimmingCharacters(in: .whitespaces))
                    }
                    .disabled(!isValidInput)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var commonUnits: [String] {
        var units = [food.servingUnit]
        let standardUnits = ["g", "oz", "cup", "tbsp", "tsp", "piece", "slice", "serving"]

        for unit in standardUnits {
            if !units.contains(where: { $0.lowercased() == unit.lowercased() }) {
                units.append(unit)
            }
        }

        return units
    }
}

#if DEBUG
struct FoodSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        FoodSelectionView(mealType: .breakfast) { food, quantity, unit in
            print("Selected: \(food.name), \(quantity) \(unit)")
        }
    }
}
#endif