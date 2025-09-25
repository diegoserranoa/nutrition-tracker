//
//  DailyNutritionStatsView.swift
//  NutritionTrackerV2
//
//  Comprehensive daily nutrition statistics with goals, charts, and meal breakdown
//

import SwiftUI
import Charts

struct DailyNutritionStatsView: View {
    let summary: DailyNutritionSummary
    let foodLogs: [FoodLog]
    let date: Date
    @State private var selectedChartType: ChartType = .macros
    @State private var showingDetailedBreakdown = false

    // Default daily goals - in a real app, these would be user-configurable
    private let defaultGoals = NutritionGoals(
        calories: 2000,
        protein: 150,      // grams
        carbohydrates: 250, // grams
        fat: 67,           // grams
        fiber: 25,         // grams
        sodium: 2300,      // mg
        sugar: 50          // grams
    )

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                dailyStatsHeader

                // Main macros overview with progress
                macroProgressSection

                // Chart selection and display
                chartSection

                // Meal distribution
                mealDistributionSection

                // Micronutrients grid
                if hasMicronutrients {
                    micronutrientsSection
                }

                // Detailed breakdown button
                detailedBreakdownButton
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showingDetailedBreakdown) {
            DetailedNutritionBreakdownView(
                summary: summary,
                foodLogs: foodLogs,
                goals: defaultGoals,
                date: date
            )
        }
    }

    // MARK: - View Sections

    private var dailyStatsHeader: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Daily Nutrition")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(formatDate(date))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text("\(summary.logCount)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)

                    Text("items logged")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Overall goal progress indicator
            ProgressView(value: min(summary.totalCalories / defaultGoals.calories, 1.2)) {
                HStack {
                    Text("Daily Goal Progress")
                        .font(.caption)
                    Spacer()
                    Text("\(Int((summary.totalCalories / defaultGoals.calories) * 100))%")
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            .tint(goalProgressColor(summary.totalCalories / defaultGoals.calories))
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2)
    }

    private var macroProgressSection: some View {
        VStack(spacing: 16) {
            Text("Macronutrients")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                MacroProgressCard(
                    name: "Calories",
                    current: summary.totalCalories,
                    goal: defaultGoals.calories,
                    unit: "",
                    color: .orange,
                    icon: "flame.fill"
                )

                MacroProgressCard(
                    name: "Protein",
                    current: summary.totalProtein,
                    goal: defaultGoals.protein,
                    unit: "g",
                    color: .red,
                    icon: "leaf.fill"
                )

                MacroProgressCard(
                    name: "Carbs",
                    current: summary.totalCarbohydrates,
                    goal: defaultGoals.carbohydrates,
                    unit: "g",
                    color: .blue,
                    icon: "leaf.fill"
                )

                MacroProgressCard(
                    name: "Fat",
                    current: summary.totalFat,
                    goal: defaultGoals.fat,
                    unit: "g",
                    color: .purple,
                    icon: "drop.fill"
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2)
    }

    private var chartSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Visual Analysis")
                    .font(.headline)

                Spacer()

                Picker("Chart Type", selection: $selectedChartType) {
                    ForEach(ChartType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }

            Group {
                switch selectedChartType {
                case .macros:
                    macroDonutChart
                case .mealDistribution:
                    mealDistributionChart
                case .progress:
                    goalProgressChart
                }
            }
            .frame(height: 200)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2)
    }

    private var mealDistributionSection: some View {
        VStack(spacing: 12) {
            Text("Meal Distribution")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(MealType.allCases.filter { type in
                mealCalories(for: type) > 0
            }, id: \.self) { mealType in
                MealDistributionRow(
                    mealType: mealType,
                    calories: mealCalories(for: mealType),
                    totalCalories: summary.totalCalories,
                    itemCount: mealItemCount(for: mealType)
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2)
    }

    private var micronutrientsSection: some View {
        VStack(spacing: 12) {
            Text("Key Micronutrients")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                ForEach(availableMicronutrients, id: \.name) { nutrient in
                    MicronutrientProgressCard(nutrient: nutrient)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2)
    }

    private var detailedBreakdownButton: some View {
        Button(action: {
            showingDetailedBreakdown = true
        }) {
            HStack {
                Text("View Detailed Breakdown")
                    .fontWeight(.medium)
                Spacer()
                Image(systemName: "chevron.right")
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2)
        }
        .buttonStyle(.plain)
        .foregroundColor(.primary)
    }

    // MARK: - Charts

    @ViewBuilder
    private var macroDonutChart: some View {
        if #available(iOS 16.0, *) {
            Chart {
                SectorMark(
                    angle: .value("Calories", summary.totalProtein * 4),
                    innerRadius: .ratio(0.5),
                    angularInset: 1.5
                )
                .foregroundStyle(.red)
                .cornerRadius(5)

                SectorMark(
                    angle: .value("Calories", summary.totalCarbohydrates * 4),
                    innerRadius: .ratio(0.5),
                    angularInset: 1.5
                )
                .foregroundStyle(.blue)
                .cornerRadius(5)

                SectorMark(
                    angle: .value("Calories", summary.totalFat * 9),
                    innerRadius: .ratio(0.5),
                    angularInset: 1.5
                )
                .foregroundStyle(.purple)
                .cornerRadius(5)
            }
            .overlay {
                VStack {
                    Text("\(Int(summary.totalCalories))")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("calories")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } else {
            // Fallback for older iOS versions
            VStack {
                Text("Macro Distribution")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack {
                    MacroLegendItem(color: .red, label: "Protein", percentage: proteinPercentage)
                    MacroLegendItem(color: .blue, label: "Carbs", percentage: carbsPercentage)
                    MacroLegendItem(color: .purple, label: "Fat", percentage: fatPercentage)
                }
            }
        }
    }

    @ViewBuilder
    private var mealDistributionChart: some View {
        if #available(iOS 16.0, *) {
            Chart {
                ForEach(MealType.allCases.filter { mealCalories(for: $0) > 0 }, id: \.self) { mealType in
                    BarMark(
                        x: .value("Meal", mealType.displayName),
                        y: .value("Calories", mealCalories(for: mealType))
                    )
                    .foregroundStyle(Color(mealType.color))
                    .cornerRadius(4)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
        } else {
            // Fallback for older iOS versions
            VStack {
                Text("Meal Distribution")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                ForEach(MealType.allCases.filter { mealCalories(for: $0) > 0 }, id: \.self) { mealType in
                    HStack {
                        Text(mealType.displayName)
                        Spacer()
                        Text("\(Int(mealCalories(for: mealType))) cal")
                            .fontWeight(.medium)
                    }
                    .font(.caption)
                }
            }
        }
    }

    @ViewBuilder
    private var goalProgressChart: some View {
        if #available(iOS 16.0, *) {
            Chart {
                BarMark(
                    x: .value("Nutrient", "Calories"),
                    y: .value("Progress", min(summary.totalCalories / defaultGoals.calories, 1.2))
                )
                .foregroundStyle(.orange)

                BarMark(
                    x: .value("Nutrient", "Protein"),
                    y: .value("Progress", min(summary.totalProtein / defaultGoals.protein, 1.2))
                )
                .foregroundStyle(.red)

                BarMark(
                    x: .value("Nutrient", "Carbs"),
                    y: .value("Progress", min(summary.totalCarbohydrates / defaultGoals.carbohydrates, 1.2))
                )
                .foregroundStyle(.blue)

                BarMark(
                    x: .value("Nutrient", "Fat"),
                    y: .value("Progress", min(summary.totalFat / defaultGoals.fat, 1.2))
                )
                .foregroundStyle(.purple)
            }
            .chartYScale(domain: 0...1.2)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text("\(Int(doubleValue * 100))%")
                        }
                    }
                }
            }
        } else {
            // Fallback for older iOS versions
            VStack {
                Text("Goal Progress")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                VStack(spacing: 8) {
                    GoalProgressRow(name: "Calories", current: summary.totalCalories, goal: defaultGoals.calories, color: .orange)
                    GoalProgressRow(name: "Protein", current: summary.totalProtein, goal: defaultGoals.protein, color: .red)
                    GoalProgressRow(name: "Carbs", current: summary.totalCarbohydrates, goal: defaultGoals.carbohydrates, color: .blue)
                    GoalProgressRow(name: "Fat", current: summary.totalFat, goal: defaultGoals.fat, color: .purple)
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var hasMicronutrients: Bool {
        (summary.totalSodium ?? 0) > 0 || (summary.totalFiber ?? 0) > 0
    }

    private var availableMicronutrients: [MicronutrientData] {
        var nutrients: [MicronutrientData] = []

        if let fiber = summary.totalFiber, fiber > 0 {
            nutrients.append(MicronutrientData(
                name: "Fiber",
                current: fiber,
                dailyValue: 25,
                unit: "g",
                color: .green
            ))
        }

        if let sodium = summary.totalSodium, sodium > 0 {
            nutrients.append(MicronutrientData(
                name: "Sodium",
                current: sodium,
                dailyValue: 2300,
                unit: "mg",
                color: .blue
            ))
        }

        // Note: totalSugar is not available in DailyNutritionSummary
        // This would need to be calculated from individual food logs if needed

        return nutrients
    }

    private var proteinPercentage: Double {
        guard summary.totalCalories > 0 else { return 0 }
        return (summary.totalProtein * 4) / summary.totalCalories
    }

    private var carbsPercentage: Double {
        guard summary.totalCalories > 0 else { return 0 }
        return (summary.totalCarbohydrates * 4) / summary.totalCalories
    }

    private var fatPercentage: Double {
        guard summary.totalCalories > 0 else { return 0 }
        return (summary.totalFat * 9) / summary.totalCalories
    }

    // MARK: - Helper Methods

    private func mealCalories(for mealType: MealType) -> Double {
        let mealLogs = foodLogs.filter { $0.mealType == mealType }
        return mealLogs.compactMap { $0.scaledCalories }.reduce(0, +)
    }

    private func mealItemCount(for mealType: MealType) -> Int {
        foodLogs.filter { $0.mealType == mealType }.count
    }

    private func goalProgressColor(_ progress: Double) -> Color {
        switch progress {
        case 0.8...1.2:
            return .green
        case 0.5...0.8:
            return .yellow
        case 1.2...:
            return .orange
        default:
            return .red
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Types

enum ChartType: String, CaseIterable {
    case macros = "macros"
    case mealDistribution = "meals"
    case progress = "progress"

    var displayName: String {
        switch self {
        case .macros: return "Macros"
        case .mealDistribution: return "Meals"
        case .progress: return "Goals"
        }
    }
}

struct NutritionGoals {
    let calories: Double
    let protein: Double
    let carbohydrates: Double
    let fat: Double
    let fiber: Double
    let sodium: Double
    let sugar: Double
}

struct MicronutrientData {
    let name: String
    let current: Double
    let dailyValue: Double
    let unit: String
    let color: Color

    var percentage: Double {
        min((current / dailyValue) * 100, 999)
    }
}

// MARK: - Supporting Views

struct MacroProgressCard: View {
    let name: String
    let current: Double
    let goal: Double
    let unit: String
    let color: Color
    let icon: String

    private var progress: Double {
        min(current / goal, 1.2)
    }

    private var isOverGoal: Bool {
        current > goal
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Label(name, systemImage: icon)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(color)
                Spacer()
            }

            VStack(spacing: 4) {
                HStack {
                    Text("\(current.formatted(.number.precision(.fractionLength(0...1))))")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("/ \(Int(goal))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                ProgressView(value: progress)
                    .tint(isOverGoal ? .orange : color)

                HStack {
                    Text("\(Int(progress * 100))%")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(isOverGoal ? .orange : color)
                    Spacer()
                    if isOverGoal {
                        Text("Over goal")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct MealDistributionRow: View {
    let mealType: MealType
    let calories: Double
    let totalCalories: Double
    let itemCount: Int

    private var percentage: Double {
        guard totalCalories > 0 else { return 0 }
        return (calories / totalCalories) * 100
    }

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: mealType.systemImage)
                    .foregroundColor(mealType.uiColor)
                    .font(.subheadline)

                Text(mealType.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("(\(itemCount) item\(itemCount == 1 ? "" : "s"))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(calories)) cal")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("\(Int(percentage))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct MicronutrientProgressCard: View {
    let nutrient: MicronutrientData

    var body: some View {
        VStack(spacing: 6) {
            Text(nutrient.name)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)

            Text("\(Int(nutrient.percentage))%")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(nutrient.color)

            Text("DV")
                .font(.caption2)
                .foregroundColor(.secondary)

            Text("\(nutrient.current.formatted(.number.precision(.fractionLength(0...1)))) \(nutrient.unit)")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct MacroLegendItem: View {
    let color: Color
    let label: String
    let percentage: Double

    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)

            Text(label)
                .font(.caption2)

            Text("\(Int(percentage * 100))%")
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

struct GoalProgressRow: View {
    let name: String
    let current: Double
    let goal: Double
    let color: Color

    private var progress: Double {
        min(current / goal, 1.2)
    }

    var body: some View {
        HStack {
            Text(name)
                .font(.caption)

            Spacer()

            ProgressView(value: progress)
                .frame(width: 60)
                .tint(color)

            Text("\(Int(progress * 100))%")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(color)
                .frame(width: 35, alignment: .trailing)
        }
    }
}

// Detailed breakdown view (simplified for now)
struct DetailedNutritionBreakdownView: View {
    let summary: DailyNutritionSummary
    let foodLogs: [FoodLog]
    let goals: NutritionGoals
    let date: Date
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Detailed breakdown coming soon...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .navigationTitle("Detailed Breakdown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
struct DailyNutritionStatsView_Previews: PreviewProvider {
    static var previews: some View {
        DailyNutritionStatsView(
            summary: .sampleSummary,
            foodLogs: FoodLog.sampleLogs,
            date: Date()
        )
    }
}

extension DailyNutritionSummary {
    static let sampleSummary = DailyNutritionSummary(
        date: Date(),
        totalCalories: 1850,
        totalProtein: 125,
        totalCarbohydrates: 230,
        totalFat: 65,
        totalFiber: 28,
        totalSodium: 1800,
        mealBreakdown: [:],
        logCount: 12
    )
}
#endif