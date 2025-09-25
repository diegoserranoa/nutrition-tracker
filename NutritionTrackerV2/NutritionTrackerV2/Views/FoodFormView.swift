//
//  FoodFormView.swift
//  NutritionTrackerV2
//
//  Form for creating and editing food items
//

import SwiftUI

enum FoodFormField: Hashable {
    case name, brand, barcode, description, category,
         servingSize, servingUnit, servingSizeGrams,
         calories, protein, carbohydrates, fat,
         fiber, sugar, saturatedFat, unsaturatedFat, transFat,
         sodium, potassium, calcium, iron, magnesium, phosphorus, zinc,
         vitaminA, vitaminC, vitaminD, vitaminE, vitaminK,
         vitaminB1, vitaminB2, vitaminB3, vitaminB6, vitaminB12, folate
}

struct FoodFormView: View {
    let prefilledFood: Food?
    let onSave: () -> Void

    @StateObject private var viewModel = FoodFormViewModel()
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: FoodFormField?

    var body: some View {
        NavigationView {
            Form {
                // Basic Information Section
                Section("Basic Information") {
                    TextField("Food Name", text: $viewModel.name)
                        .focused($focusedField, equals: .name)

                    TextField("Brand (optional)", text: $viewModel.brand)
                        .focused($focusedField, equals: .brand)

                    TextField("Barcode (optional)", text: $viewModel.barcode)
                        .focused($focusedField, equals: .barcode)

                    TextField("Description (optional)", text: $viewModel.description)
                        .focused($focusedField, equals: .description)

                    // Category picker
                    Picker("Category", selection: $viewModel.selectedCategory) {
                        Text("No Category").tag(nil as FoodCategory?)
                        ForEach(FoodCategory.allCases, id: \.self) { category in
                            Text(category.displayName).tag(category as FoodCategory?)
                        }
                    }
                    .pickerStyle(.menu)

                    Toggle("Verified", isOn: $viewModel.isVerified)
                }

                // Serving Information Section
                Section("Serving Information") {
                    HStack {
                        TextField("Serving Size", text: $viewModel.servingSize)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .servingSize)

                        TextField("Unit (e.g., g, cup, oz)", text: $viewModel.servingUnit)
                            .focused($focusedField, equals: .servingUnit)
                    }

                    TextField("Serving Size in Grams (optional)", text: $viewModel.servingSizeGrams)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .servingSizeGrams)
                }

                // Macronutrients Section (Required)
                Section("Macronutrients (Required)") {
                    nutrientField("Calories", value: $viewModel.calories, unit: "", field: .calories)
                    nutrientField("Protein", value: $viewModel.protein, unit: "g", field: .protein)
                    nutrientField("Carbohydrates", value: $viewModel.carbohydrates, unit: "g", field: .carbohydrates)
                    nutrientField("Total Fat", value: $viewModel.fat, unit: "g", field: .fat)
                }

                // Additional Macronutrients Section (Optional)
                Section("Additional Macronutrients (Optional)") {
                    nutrientField("Fiber", value: $viewModel.fiber, unit: "g", field: .fiber)
                    nutrientField("Sugar", value: $viewModel.sugar, unit: "g", field: .sugar)
                    nutrientField("Saturated Fat", value: $viewModel.saturatedFat, unit: "g", field: .saturatedFat)
                    nutrientField("Unsaturated Fat", value: $viewModel.unsaturatedFat, unit: "g", field: .unsaturatedFat)
                    nutrientField("Trans Fat", value: $viewModel.transFat, unit: "g", field: .transFat)
                }

                // Micronutrients Section
                DisclosureGroup("Micronutrients (Optional)", isExpanded: $viewModel.showMoreNutrients) {
                    Group {
                        nutrientField("Sodium", value: $viewModel.sodium, unit: "mg", field: .sodium)
                        nutrientField("Potassium", value: $viewModel.potassium, unit: "mg", field: .potassium)
                        nutrientField("Calcium", value: $viewModel.calcium, unit: "mg", field: .calcium)
                        nutrientField("Iron", value: $viewModel.iron, unit: "mg", field: .iron)
                        nutrientField("Magnesium", value: $viewModel.magnesium, unit: "mg", field: .magnesium)
                        nutrientField("Phosphorus", value: $viewModel.phosphorus, unit: "mg", field: .phosphorus)
                        nutrientField("Zinc", value: $viewModel.zinc, unit: "mg", field: .zinc)
                    }

                    Group {
                        nutrientField("Vitamin A", value: $viewModel.vitaminA, unit: "mcg", field: .vitaminA)
                        nutrientField("Vitamin C", value: $viewModel.vitaminC, unit: "mg", field: .vitaminC)
                        nutrientField("Vitamin D", value: $viewModel.vitaminD, unit: "mcg", field: .vitaminD)
                        nutrientField("Vitamin E", value: $viewModel.vitaminE, unit: "mg", field: .vitaminE)
                        nutrientField("Vitamin K", value: $viewModel.vitaminK, unit: "mcg", field: .vitaminK)
                    }

                    Group {
                        nutrientField("Vitamin B1 (Thiamin)", value: $viewModel.vitaminB1, unit: "mg", field: .vitaminB1)
                        nutrientField("Vitamin B2 (Riboflavin)", value: $viewModel.vitaminB2, unit: "mg", field: .vitaminB2)
                        nutrientField("Vitamin B3 (Niacin)", value: $viewModel.vitaminB3, unit: "mg", field: .vitaminB3)
                        nutrientField("Vitamin B6", value: $viewModel.vitaminB6, unit: "mg", field: .vitaminB6)
                        nutrientField("Vitamin B12", value: $viewModel.vitaminB12, unit: "mcg", field: .vitaminB12)
                        nutrientField("Folate", value: $viewModel.folate, unit: "mcg", field: .folate)
                    }
                }

                // Save Button Section
                Section {
                    Button(action: {
                        Task {
                            viewModel.onSave = { onSave() }
                            viewModel.onError = { error in
                                // Error handling will be improved in next todo
                                print("Save failed: \(error)")
                            }
                            await viewModel.save()
                        }
                    }) {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(prefilledFood != nil ? "Update Food" : "Save Food")
                        }
                    }
                    .disabled(!viewModel.isFormValid || viewModel.isLoading)
                }
            }
            .navigationTitle(prefilledFood != nil ? "Edit Food" : "New Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onSave()
                    }
                    .disabled(viewModel.isLoading)
                }

                ToolbarItem(placement: .keyboard) {
                    inputAccessoryToolbar
                }
            }
            .onAppear {
                if let food = prefilledFood {
                    viewModel.loadFood(food)
                }
            }
            .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") {
                    viewModel.clearError()
                }
            } message: {
                Text(viewModel.error?.localizedDescription ?? "Unknown error occurred")
            }
        }
    }

    // MARK: - Helper Views

    @ViewBuilder
    private func nutrientField(_ label: String, value: Binding<String>, unit: String, field: FoodFormField) -> some View {
        HStack {
            Text(label)
                .frame(maxWidth: .infinity, alignment: .leading)

            TextField("0", text: value)
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: field)
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)

            Text(unit)
                .foregroundColor(.secondary)
                .frame(width: 30, alignment: .leading)
        }
    }

    private var inputAccessoryToolbar: some View {
        HStack {
            Button("Previous") {
                moveFocus(-1)
            }
            .disabled(previousField == nil)

            Spacer()

            Button("Next") {
                moveFocus(1)
            }
            .disabled(nextField == nil)

            Spacer()

            Button("Done") {
                focusedField = nil
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Focus Management

    private var fieldOrder: [FoodFormField] {
        [
            .name, .brand, .barcode, .description,
            .servingSize, .servingUnit, .servingSizeGrams,
            .calories, .protein, .carbohydrates, .fat,
            .fiber, .sugar, .saturatedFat, .unsaturatedFat, .transFat,
            .sodium, .potassium, .calcium, .iron, .magnesium, .phosphorus, .zinc,
            .vitaminA, .vitaminC, .vitaminD, .vitaminE, .vitaminK,
            .vitaminB1, .vitaminB2, .vitaminB3, .vitaminB6, .vitaminB12, .folate
        ]
    }

    private var currentIndex: Int? {
        guard let focused = focusedField else { return nil }
        return fieldOrder.firstIndex(of: focused)
    }

    private var nextField: FoodFormField? {
        guard let index = currentIndex, index + 1 < fieldOrder.count else { return nil }
        return fieldOrder[index + 1]
    }

    private var previousField: FoodFormField? {
        guard let index = currentIndex, index > 0 else { return nil }
        return fieldOrder[index - 1]
    }

    private func moveFocus(_ direction: Int) {
        guard let index = currentIndex else { return }
        let newIndex = index + direction
        if newIndex >= 0 && newIndex < fieldOrder.count {
            focusedField = fieldOrder[newIndex]
        }
    }
}

#if DEBUG
struct FoodFormView_Previews: PreviewProvider {
    static var previews: some View {
        FoodFormView(prefilledFood: nil) {
            // Preview completion
        }
    }
}
#endif