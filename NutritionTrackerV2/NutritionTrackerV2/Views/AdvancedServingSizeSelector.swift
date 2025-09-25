//
//  AdvancedServingSizeSelector.swift
//  NutritionTrackerV2
//
//  Advanced serving size selection interface with real-time nutritional scaling
//

import SwiftUI

struct AdvancedServingSizeSelector: View {
    let food: Food
    @State private var quantity: String
    @State private var selectedUnit: String
    @State private var servingSizePreset: ServingSizePreset?
    @State private var showingCustomUnit = false
    @State private var customUnit: String = ""
    @State private var selectedDate: Date
    @State private var includeTime: Bool = false
    @Environment(\.dismiss) private var dismiss

    let onSave: (Food, Double, String, Date) -> Void

    init(food: Food, initialQuantity: String? = nil, initialUnit: String? = nil, initialDate: Date? = nil, onSave: @escaping (Food, Double, String, Date) -> Void) {
        self.food = food
        self._quantity = State(initialValue: initialQuantity ?? String(food.servingSize))
        self._selectedUnit = State(initialValue: initialUnit ?? food.servingUnit)
        self._selectedDate = State(initialValue: initialDate ?? Date())
        self.onSave = onSave
    }

    private var quantityValue: Double {
        Double(quantity) ?? 0
    }

    private var isValidInput: Bool {
        quantityValue > 0 && !selectedUnit.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var nutritionalMultiplier: Double {
        guard quantityValue > 0 else { return 0 }

        // Calculate multiplier based on unit conversion
        if selectedUnit.lowercased() == food.servingUnit.lowercased() {
            return quantityValue / food.servingSize
        }

        // Handle common unit conversions
        return calculateUnitConversionMultiplier()
    }

    private var scaledNutrition: ScaledNutrition {
        ScaledNutrition(food: food, multiplier: nutritionalMultiplier)
    }

    var body: some View {
        NavigationView {
            Form {
                // Food Information Section
                foodInfoSection

                // Date and Time Section
                dateTimeSection

                // Quantity Input Section
                quantityInputSection

                // Serving Size Presets Section
                servingPresetsSection

                // Unit Selection Section
                unitSelectionSection

                // Live Nutrition Preview Section
                if quantityValue > 0 {
                    nutritionPreviewSection
                }

                // Micronutrients Section
                if quantityValue > 0 && hasMicronutrients {
                    micronutrientsSection
                }
            }
            .navigationTitle("Serving Size")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        let finalDate = includeTime ? selectedDate : Calendar.current.startOfDay(for: selectedDate)
                        onSave(food, quantityValue, selectedUnit.trimmingCharacters(in: .whitespaces), finalDate)
                    }
                    .disabled(!isValidInput)
                    .fontWeight(.semibold)
                    .foregroundColor(isValidInput ? .blue : .gray)
                }
            }
        }
    }

    // MARK: - View Sections

    private var foodInfoSection: some View {
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

                HStack(spacing: 8) {
                    Label("\(Int(food.calories)) cal", systemImage: "flame.fill")
                        .font(.caption)
                        .foregroundColor(.orange)

                    Text("per \(food.servingSize.formatted()) \(food.servingUnit)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var dateTimeSection: some View {
        Section("When did you eat this?") {
            VStack(spacing: 16) {
                // Date picker
                HStack {
                    Label("Date", systemImage: "calendar")
                        .font(.subheadline)
                        .foregroundColor(.primary)

                    Spacer()

                    DatePicker(
                        "",
                        selection: $selectedDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                }

                // Time toggle and picker
                VStack(spacing: 12) {
                    Toggle(isOn: $includeTime) {
                        Label("Include specific time", systemImage: "clock")
                            .font(.subheadline)
                    }

                    if includeTime {
                        HStack {
                            Label("Time", systemImage: "clock")
                                .font(.subheadline)
                                .foregroundColor(.primary)

                            Spacer()

                            DatePicker(
                                "",
                                selection: $selectedDate,
                                displayedComponents: .hourAndMinute
                            )
                            .datePickerStyle(.compact)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: includeTime)

                // Quick time buttons when time is enabled
                if includeTime {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                        ForEach(quickTimeOptions, id: \.description) { timeOption in
                            Button(timeOption.description) {
                                let calendar = Calendar.current
                                let dateComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
                                if let newDate = calendar.date(bySettingHour: timeOption.hour, minute: timeOption.minute, second: 0, of: calendar.date(from: dateComponents) ?? selectedDate) {
                                    selectedDate = newDate
                                }
                            }
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray6))
                            .cornerRadius(6)
                            .buttonStyle(.plain)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private var quantityInputSection: some View {
        Section("Quantity") {
            HStack {
                // Stepper controls
                VStack(spacing: 8) {
                    Button(action: incrementQuantity) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)

                    Button(action: decrementQuantity) {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    .disabled(quantityValue <= 0.25)
                }

                VStack {
                    TextField("Amount", text: $quantity)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .onChange(of: quantity) { newValue in
                            validateAndFormatQuantity(newValue)
                        }

                    Text(selectedUnit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Quick fraction buttons
                VStack(spacing: 4) {
                    ForEach(quickFractions, id: \.0) { fraction, label in
                        Button(label) {
                            let baseQuantity = servingSizePreset?.quantity ?? food.servingSize
                            quantity = String(baseQuantity * fraction)
                        }
                        .font(.caption2)
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                    }
                }
            }
        }
    }

    private var servingPresetsSection: some View {
        Section("Common Serving Sizes") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(servingSizePresets, id: \.id) { preset in
                    ServingSizePresetButton(
                        preset: preset,
                        isSelected: servingSizePreset?.id == preset.id,
                        action: {
                            selectServingPreset(preset)
                        }
                    )
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var unitSelectionSection: some View {
        Section("Unit") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach(commonUnits, id: \.self) { unit in
                    Button(action: {
                        selectedUnit = unit
                        servingSizePreset = nil
                    }) {
                        Text(unit)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(selectedUnit == unit ? Color.blue : Color(.systemGray6))
                            .foregroundColor(selectedUnit == unit ? .white : .primary)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }

                Button("Custom") {
                    showingCustomUnit = true
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .foregroundColor(.blue)
                .cornerRadius(8)
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
        }
        .alert("Custom Unit", isPresented: $showingCustomUnit) {
            TextField("Unit name", text: $customUnit)
            Button("Add") {
                if !customUnit.trimmingCharacters(in: .whitespaces).isEmpty {
                    selectedUnit = customUnit.trimmingCharacters(in: .whitespaces)
                    customUnit = ""
                }
            }
            Button("Cancel", role: .cancel) {
                customUnit = ""
            }
        }
    }

    private var nutritionPreviewSection: some View {
        Section("Nutrition Facts") {
            VStack(spacing: 12) {
                // Calorie highlight
                HStack {
                    Label("Calories", systemImage: "flame.fill")
                        .font(.headline)
                        .foregroundColor(.orange)

                    Spacer()

                    Text(scaledNutrition.calories.formatted(.number.precision(.fractionLength(0...1))))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // Macronutrients
                VStack(spacing: 8) {
                    ServingNutrientRow(
                        name: "Protein",
                        value: scaledNutrition.protein,
                        unit: "g",
                        color: .red,
                        icon: "leaf.fill"
                    )

                    ServingNutrientRow(
                        name: "Carbohydrates",
                        value: scaledNutrition.carbohydrates,
                        unit: "g",
                        color: .orange,
                        icon: "leaf.fill"
                    )

                    ServingNutrientRow(
                        name: "Fat",
                        value: scaledNutrition.fat,
                        unit: "g",
                        color: .purple,
                        icon: "drop.fill"
                    )

                    if let fiber = scaledNutrition.fiber {
                        ServingNutrientRow(
                            name: "Fiber",
                            value: fiber,
                            unit: "g",
                            color: .green,
                            icon: "leaf.fill"
                        )
                    }

                    if let sugar = scaledNutrition.sugar {
                        ServingNutrientRow(
                            name: "Sugar",
                            value: sugar,
                            unit: "g",
                            color: .yellow,
                            icon: "sparkles"
                        )
                    }
                }
            }
        }
    }

    private var micronutrientsSection: some View {
        Section("Vitamins & Minerals") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(availableMicronutrients, id: \.name) { nutrient in
                    MicronutrientCard(
                        name: nutrient.name,
                        value: nutrient.value,
                        unit: nutrient.unit,
                        color: nutrient.color
                    )
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var servingSizePresets: [ServingSizePreset] {
        ServingSizePreset.presets(for: food)
    }

    private var commonUnits: [String] {
        var units = [food.servingUnit]
        let standardUnits = ["g", "oz", "cup", "tbsp", "tsp", "ml", "piece", "slice", "serving"]

        for unit in standardUnits {
            if !units.contains(where: { $0.lowercased() == unit.lowercased() }) {
                units.append(unit)
            }
        }

        return units
    }

    private var quickFractions: [(Double, String)] {
        [(0.25, "1/4"), (0.5, "1/2"), (0.75, "3/4"), (1.0, "1x"), (1.5, "1.5x"), (2.0, "2x")]
    }

    private var hasMicronutrients: Bool {
        food.vitaminA != nil || food.vitaminC != nil || food.calcium != nil ||
        food.iron != nil || food.sodium != nil || food.potassium != nil
    }

    private var availableMicronutrients: [MicronutrientInfo] {
        var nutrients: [MicronutrientInfo] = []

        if let sodium = scaledNutrition.sodium {
            nutrients.append(MicronutrientInfo(name: "Sodium", value: sodium, unit: "mg", color: .blue))
        }
        if let potassium = scaledNutrition.potassium {
            nutrients.append(MicronutrientInfo(name: "Potassium", value: potassium, unit: "mg", color: .orange))
        }
        if let calcium = scaledNutrition.calcium {
            nutrients.append(MicronutrientInfo(name: "Calcium", value: calcium, unit: "mg", color: .green))
        }
        if let iron = scaledNutrition.iron {
            nutrients.append(MicronutrientInfo(name: "Iron", value: iron, unit: "mg", color: .red))
        }
        if let vitaminC = scaledNutrition.vitaminC {
            nutrients.append(MicronutrientInfo(name: "Vitamin C", value: vitaminC, unit: "mg", color: .yellow))
        }
        if let vitaminA = scaledNutrition.vitaminA {
            nutrients.append(MicronutrientInfo(name: "Vitamin A", value: vitaminA, unit: "mcg", color: .purple))
        }

        return nutrients
    }

    private var quickTimeOptions: [QuickTimeOption] {
        [
            QuickTimeOption(hour: 7, minute: 0, description: "7:00 AM"),
            QuickTimeOption(hour: 8, minute: 0, description: "8:00 AM"),
            QuickTimeOption(hour: 12, minute: 0, description: "12:00 PM"),
            QuickTimeOption(hour: 13, minute: 0, description: "1:00 PM"),
            QuickTimeOption(hour: 18, minute: 0, description: "6:00 PM"),
            QuickTimeOption(hour: 19, minute: 0, description: "7:00 PM"),
            QuickTimeOption(hour: 20, minute: 0, description: "8:00 PM"),
            QuickTimeOption(hour: 21, minute: 0, description: "9:00 PM")
        ]
    }

    // MARK: - Helper Methods

    private func incrementQuantity() {
        let current = quantityValue
        let increment: Double = current < 1 ? 0.25 : (current < 5 ? 0.5 : 1.0)
        quantity = String(current + increment)
    }

    private func decrementQuantity() {
        let current = quantityValue
        let decrement: Double = current <= 1 ? 0.25 : (current <= 5 ? 0.5 : 1.0)
        let newValue = max(0.25, current - decrement)
        quantity = String(newValue)
    }

    private func validateAndFormatQuantity(_ value: String) {
        // Allow decimal input but validate range
        if let numValue = Double(value), numValue < 0 {
            quantity = "0"
        }
    }

    private func selectServingPreset(_ preset: ServingSizePreset) {
        servingSizePreset = preset
        quantity = String(preset.quantity)
        selectedUnit = preset.unit
    }

    private func calculateUnitConversionMultiplier() -> Double {
        // Basic unit conversions - in a real app, this would be more comprehensive
        let quantityInGrams = convertToGrams(quantity: quantityValue, unit: selectedUnit)
        let foodServingInGrams = convertToGrams(quantity: food.servingSize, unit: food.servingUnit)

        if quantityInGrams > 0 && foodServingInGrams > 0 {
            return quantityInGrams / foodServingInGrams
        }

        // Fallback to simple ratio
        return quantityValue / food.servingSize
    }

    private func convertToGrams(quantity: Double, unit: String) -> Double {
        // Basic conversion factors - would be expanded in production
        switch unit.lowercased() {
        case "g", "gram", "grams":
            return quantity
        case "oz", "ounce", "ounces":
            return quantity * 28.35
        case "lb", "pound", "pounds":
            return quantity * 453.59
        case "kg", "kilogram", "kilograms":
            return quantity * 1000
        case "cup", "cups":
            return quantity * 240 // approximate for liquids
        case "tbsp", "tablespoon", "tablespoons":
            return quantity * 15
        case "tsp", "teaspoon", "teaspoons":
            return quantity * 5
        default:
            return 0 // Unknown unit, return 0 to trigger fallback
        }
    }
}

// MARK: - Supporting Types

struct ServingSizePreset: Identifiable {
    let id = UUID()
    let name: String
    let quantity: Double
    let unit: String
    let description: String

    static func presets(for food: Food) -> [ServingSizePreset] {
        var presets: [ServingSizePreset] = []

        // Always include the original serving size
        presets.append(ServingSizePreset(
            name: "Standard Serving",
            quantity: food.servingSize,
            unit: food.servingUnit,
            description: "As labeled"
        ))

        // Add common fractions
        presets.append(ServingSizePreset(
            name: "Half Serving",
            quantity: food.servingSize * 0.5,
            unit: food.servingUnit,
            description: "50% of standard"
        ))

        presets.append(ServingSizePreset(
            name: "Double Serving",
            quantity: food.servingSize * 2,
            unit: food.servingUnit,
            description: "200% of standard"
        ))

        // Add common gram amounts if not already in grams
        if !food.servingUnit.lowercased().contains("g") {
            presets.append(contentsOf: [
                ServingSizePreset(name: "100g", quantity: 100, unit: "g", description: "Standard comparison"),
                ServingSizePreset(name: "50g", quantity: 50, unit: "g", description: "Small portion"),
                ServingSizePreset(name: "200g", quantity: 200, unit: "g", description: "Large portion")
            ])
        }

        return presets
    }
}

struct ScaledNutrition {
    let calories: Double
    let protein: Double
    let carbohydrates: Double
    let fat: Double
    let fiber: Double?
    let sugar: Double?
    let saturatedFat: Double?
    let sodium: Double?
    let potassium: Double?
    let calcium: Double?
    let iron: Double?
    let vitaminA: Double?
    let vitaminC: Double?

    init(food: Food, multiplier: Double) {
        self.calories = food.calories * multiplier
        self.protein = food.protein * multiplier
        self.carbohydrates = food.carbohydrates * multiplier
        self.fat = food.fat * multiplier
        self.fiber = food.fiber.map { $0 * multiplier }
        self.sugar = food.sugar.map { $0 * multiplier }
        self.saturatedFat = food.saturatedFat.map { $0 * multiplier }
        self.sodium = food.sodium.map { $0 * multiplier }
        self.potassium = food.potassium.map { $0 * multiplier }
        self.calcium = food.calcium.map { $0 * multiplier }
        self.iron = food.iron.map { $0 * multiplier }
        self.vitaminA = food.vitaminA.map { $0 * multiplier }
        self.vitaminC = food.vitaminC.map { $0 * multiplier }
    }
}

struct MicronutrientInfo {
    let name: String
    let value: Double
    let unit: String
    let color: Color
}

struct QuickTimeOption {
    let hour: Int
    let minute: Int
    let description: String
}

// MARK: - Supporting Views

struct ServingSizePresetButton: View {
    let preset: ServingSizePreset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(preset.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)

                Text("\(preset.quantity.formatted()) \(preset.unit)")
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)

                Text(preset.description)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isSelected ? Color.blue : Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

struct ServingNutrientRow: View {
    let name: String
    let value: Double
    let unit: String
    let color: Color
    let icon: String

    var body: some View {
        HStack {
            Label(name, systemImage: icon)
                .font(.subheadline)
                .foregroundColor(color)

            Spacer()

            Text("\(value.formatted(.number.precision(.fractionLength(0...1))))\(unit)")
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.vertical, 2)
    }
}

struct MicronutrientCard: View {
    let name: String
    let value: Double
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(name)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Text("\(value.formatted(.number.precision(.fractionLength(0...1))))")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(unit)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Previews

#if DEBUG
struct AdvancedServingSizeSelector_Previews: PreviewProvider {
    static var previews: some View {
        AdvancedServingSizeSelector(food: .sampleFoods[0]) { food, quantity, unit, date in
            print("Selected: \(food.name), \(quantity) \(unit), \(date)")
        }
    }
}
#endif