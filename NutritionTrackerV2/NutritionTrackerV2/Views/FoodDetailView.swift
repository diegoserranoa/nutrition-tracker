//
//  FoodDetailView.swift
//  NutritionTrackerV2
//
//  Detailed view for displaying food nutritional information
//

import SwiftUI

struct FoodDetailView: View {
    let food: Food

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header Section
                VStack(alignment: .leading, spacing: 8) {
                    Text(food.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    if let brand = food.brand {
                        Text(brand)
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }

                    if let description = food.description {
                        Text(description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider()

                // Serving Information
                VStack(alignment: .leading, spacing: 8) {
                    Text("Serving Information")
                        .font(.headline)

                    HStack {
                        Text("Serving Size:")
                        Spacer()
                        Text("\(food.servingSize.formatted()) \(food.servingUnit)")
                            .fontWeight(.medium)
                    }

                    if let servingSizeGrams = food.servingSizeGrams {
                        HStack {
                            Text("Serving Size (grams):")
                            Spacer()
                            Text("\(servingSizeGrams.formatted()) g")
                                .fontWeight(.medium)
                        }
                    }
                }

                Divider()

                // Macronutrients
                VStack(alignment: .leading, spacing: 8) {
                    Text("Macronutrients")
                        .font(.headline)

                    NutrientRow(label: "Calories", value: food.calories, unit: "")
                    NutrientRow(label: "Protein", value: food.protein, unit: "g")
                    NutrientRow(label: "Carbohydrates", value: food.carbohydrates, unit: "g")
                    NutrientRow(label: "Fat", value: food.fat, unit: "g")

                    if let fiber = food.fiber {
                        NutrientRow(label: "Fiber", value: fiber, unit: "g")
                    }
                    if let sugar = food.sugar {
                        NutrientRow(label: "Sugar", value: sugar, unit: "g")
                    }
                    if let saturatedFat = food.saturatedFat {
                        NutrientRow(label: "Saturated Fat", value: saturatedFat, unit: "g")
                    }
                }

                // Micronutrients (show only if present)
                let micronutrients = getMicronutrients()
                if !micronutrients.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Micronutrients")
                            .font(.headline)

                        ForEach(micronutrients, id: \.label) { nutrient in
                            NutrientRow(label: nutrient.label, value: nutrient.value, unit: nutrient.unit)
                        }
                    }
                }

                Spacer()
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func getMicronutrients() -> [(label: String, value: Double, unit: String)] {
        var nutrients: [(String, Double, String)] = []

        if let sodium = food.sodium { nutrients.append(("Sodium", sodium, "mg")) }
        if let potassium = food.potassium { nutrients.append(("Potassium", potassium, "mg")) }
        if let calcium = food.calcium { nutrients.append(("Calcium", calcium, "mg")) }
        if let iron = food.iron { nutrients.append(("Iron", iron, "mg")) }
        if let vitaminA = food.vitaminA { nutrients.append(("Vitamin A", vitaminA, "mcg")) }
        if let vitaminC = food.vitaminC { nutrients.append(("Vitamin C", vitaminC, "mg")) }
        if let vitaminD = food.vitaminD { nutrients.append(("Vitamin D", vitaminD, "mcg")) }
        if let vitaminE = food.vitaminE { nutrients.append(("Vitamin E", vitaminE, "mg")) }

        return nutrients
    }
}

struct NutrientRow: View {
    let label: String
    let value: Double
    let unit: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(value.formatted()) \(unit)")
                .fontWeight(.medium)
        }
        .padding(.vertical, 2)
    }
}

#if DEBUG
struct FoodDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleFood = Food(
            id: UUID(),
            name: "Apple",
            brand: "Fresh Produce",
            barcode: nil,
            description: "Fresh red apple",
            servingSize: 1,
            servingUnit: "g",
            servingSizeGrams: 20.0,
            calories: 182,
            protein: 95,
            carbohydrates: 0.5,
            fat: 25,
            fiber: 0.3,
            sugar: 4.4,
            saturatedFat: 19,
            unsaturatedFat: 0.1,
            transFat: nil,
            sodium: nil,
            potassium: 2,
            calcium: 195,
            iron: 11,
            vitaminA: 0.18,
            vitaminC: 6,
            vitaminD: 8.4,
            vitaminE: nil,
            vitaminK: 0.33,
            vitaminB1: nil,
            vitaminB2: nil,
            vitaminB3: nil,
            vitaminB6: nil,
            vitaminB12: nil,
            folate: nil,
            magnesium: nil,
            phosphorus: nil,
            zinc: nil,
            category: nil,
            isVerified: false,
            source: .usda,
            createdAt: Date(),
            updatedAt: Date(),
            createdBy: UUID()
        )

        NavigationView {
            FoodDetailView(food: sampleFood)
        }
    }
}
#endif
