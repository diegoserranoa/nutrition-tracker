//
//  FoodLogView.swift
//  NutritionTrackerV2
//
//  Main interface for daily food consumption tracking
//

import SwiftUI

struct FoodLogView: View {
    @StateObject private var viewModel = FoodLogViewModel()
    @State private var showingFoodSelection = false
    @State private var selectedMealForAdding: MealType = .breakfast
    @State private var showingDatePicker = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Date Header
                    dateHeaderView

                    // Daily Summary Card
                    if let summary = viewModel.dailySummary, summary.logCount > 0 {
                        dailySummaryCard(summary)
                    }

                    // Meal Sections
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.displayedMealTypes, id: \.self) { mealType in
                            mealSection(for: mealType)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 100) // Space for floating button
                }
            }
            .refreshable {
                viewModel.refreshFoodLogs()
            }
            .navigationTitle("Food Log")
            .navigationBarTitleDisplayMode(.large)
            .overlay(alignment: .bottomTrailing) {
                // Quick Add Button
                quickAddButton
            }
            .sheet(isPresented: $showingFoodSelection) {
                foodSelectionSheet
            }
            .sheet(isPresented: $showingDatePicker) {
                datePickerSheet
            }
            .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") {
                    viewModel.clearError()
                }
            } message: {
                Text(viewModel.error?.localizedDescription ?? "Unknown error occurred")
            }
        }
        .onAppear {
            viewModel.loadFoodLogs()
        }
    }

    // MARK: - Date Header

    private var dateHeaderView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.selectedDateString)
                    .font(.title2)
                    .fontWeight(.semibold)

                if viewModel.isToday {
                    Text("Today")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                }
            }

            Spacer()

            Button(action: {
                showingDatePicker = true
            }) {
                Image(systemName: "calendar")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Daily Summary Card

    private func dailySummaryCard(_ summary: DailyNutritionSummary) -> some View {
        VStack(spacing: 12) {
            Text("Daily Summary")
                .font(.headline)
                .fontWeight(.semibold)

            HStack(spacing: 20) {
                summaryItem("Calories", value: summary.totalCalories, unit: "cal", color: .blue)
                summaryItem("Protein", value: summary.totalProtein, unit: "g", color: .red)
                summaryItem("Carbs", value: summary.totalCarbohydrates, unit: "g", color: .orange)
                summaryItem("Fat", value: summary.totalFat, unit: "g", color: .purple)
            }

            Text("\(summary.logCount) item\(summary.logCount == 1 ? "" : "s") logged")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .padding(.horizontal)
        .padding(.bottom, 16)
    }

    private func summaryItem(_ label: String, value: Double, unit: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value.formatted(.number.precision(.fractionLength(0...1))))")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(unit)
                .font(.caption2)
                .foregroundColor(color)

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Meal Sections

    private func mealSection(for mealType: MealType) -> some View {
        let logs = viewModel.logsByMealType[mealType] ?? []

        return VStack(alignment: .leading, spacing: 8) {
            // Meal Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: mealType.systemImage)
                        .foregroundColor(mealType.uiColor)
                        .font(.title2)

                    Text(mealType.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                }

                Spacer()

                // Add button for this meal
                Button(action: {
                    selectedMealForAdding = mealType
                    showingFoodSelection = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
            }

            // Food Items
            if logs.isEmpty {
                emptyMealView
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(logs) { log in
                        FoodLogRowView(log: log) {
                            // Delete action
                            Task { @MainActor in
                                await viewModel.deleteFoodLog(log)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
    }

    private var emptyMealView: some View {
        HStack {
            Text("No foods logged")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text("Tap + to add")
                .font(.caption)
                .foregroundColor(.blue)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Quick Add Button

    private var quickAddButton: some View {
        Menu {
            ForEach([MealType.breakfast, .lunch, .dinner, .snack], id: \.self) { mealType in
                Button(action: {
                    selectedMealForAdding = mealType
                    showingFoodSelection = true
                }) {
                    Label(mealType.displayName, systemImage: mealType.systemImage)
                }
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Color.blue)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .padding()
    }

    // MARK: - Sheets

    private var foodSelectionSheet: some View {
        FoodSelectionView(mealType: selectedMealForAdding) { food, quantity, unit in
            // Add the food to the log
            Task { @MainActor in
                await viewModel.addFoodLog(
                    food: food,
                    quantity: quantity,
                    unit: unit,
                    mealType: selectedMealForAdding,
                    loggedAt: viewModel.selectedDate
                )
            }
            showingFoodSelection = false
        }
    }

    private var datePickerSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Select Date")
                    .font(.headline)
                    .padding(.top)

                DatePicker("Date", selection: $viewModel.selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()

                Spacer()
            }
            .navigationTitle("Change Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showingDatePicker = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingDatePicker = false
                    }
                }
            }
        }
    }
}

// MARK: - Food Log Row View

struct FoodLogRowView: View {
    let log: FoodLog
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Food info
            VStack(alignment: .leading, spacing: 4) {
                Text(log.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    Text(log.quantityDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let gramsDesc = log.gramsDescription {
                        Text("(\(gramsDesc))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text(log.loggedTimeDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Nutrition info
            if let calories = log.scaledCalories {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(calories.formatted(.number.precision(.fractionLength(0...1)))) cal")
                        .font(.caption)
                        .fontWeight(.medium)

                    if let macros = log.scaledMacros {
                        Text("P:\(macros.protein.formatted(.number.precision(.fractionLength(0...1))))g")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
struct FoodLogView_Previews: PreviewProvider {
    static var previews: some View {
        FoodLogView()
    }
}

struct FoodLogRowView_Previews: PreviewProvider {
    static var previews: some View {
        List {
            FoodLogRowView(log: FoodLog.sampleLogs[0]) { }
            FoodLogRowView(log: FoodLog.sampleLogs[1]) { }
        }
    }
}
#endif