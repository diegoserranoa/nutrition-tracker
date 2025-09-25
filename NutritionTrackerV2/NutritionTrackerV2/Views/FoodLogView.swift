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
    @State private var isTransitioning = false
    @State private var showingDetailedStats = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Date Header
                    dateHeaderView

                    // Operation feedback banner
                    if let feedback = viewModel.operationFeedback {
                        operationFeedbackBanner(feedback)
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            ))
                            .animation(.easeInOut(duration: 0.3), value: viewModel.operationFeedback)
                    }

                    // Content with transition animations
                    Group {
                        // Daily Summary Card
                        if let summary = viewModel.dailySummary, summary.logCount > 0 {
                            dailySummaryCard(summary)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .move(edge: .trailing)),
                                    removal: .opacity.combined(with: .move(edge: .leading))
                                ))
                        }

                        // Meal Sections
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.displayedMealTypes, id: \.self) { mealType in
                                mealSection(for: mealType)
                                    .transition(.asymmetric(
                                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                                        removal: .opacity.combined(with: .move(edge: .leading))
                                    ))
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 100) // Space for floating button
                    }
                    .opacity(isTransitioning ? 0.3 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isTransitioning)
                }
            }
            .refreshable {
                viewModel.refreshFoodLogs()
            }
// TODO: Add swipe gestures for navigation - temporarily disabled due to build issue
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
            .sheet(isPresented: $showingDetailedStats) {
                if let summary = viewModel.dailySummary {
                    DailyNutritionStatsView(
                        summary: summary,
                        foodLogs: viewModel.foodLogs,
                        date: viewModel.selectedDate
                    )
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
        .onAppear {
            viewModel.loadFoodLogs()
            Task {
                await viewModel.loadDatesWithLogsForMonth()
            }
        }
    }

    // MARK: - Date Header

    private var dateHeaderView: some View {
        VStack(spacing: 0) {
            // Main date navigation
            HStack {
                // Previous day button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.selectDate(Calendar.current.date(byAdding: .day, value: -1, to: viewModel.selectedDate) ?? viewModel.selectedDate)
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                        .frame(width: 32, height: 32)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Spacer()

                // Date display
                VStack(spacing: 2) {
                    HStack(spacing: 8) {
                        Text(viewModel.selectedDateString)
                            .font(.title2)
                            .fontWeight(.semibold)

                        // Visual indicator for dates with logs
                        if viewModel.hasLogsForDate(viewModel.selectedDate) {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 8, height: 8)
                        }
                    }

                    if viewModel.isToday {
                        Text("Today")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .fontWeight(.medium)
                    } else {
                        Text(relativeDateString(for: viewModel.selectedDate))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .onTapGesture {
                    showingDatePicker = true
                }

                Spacer()

                // Next day button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.selectDate(Calendar.current.date(byAdding: .day, value: 1, to: viewModel.selectedDate) ?? viewModel.selectedDate)
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                        .frame(width: 32, height: 32)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.vertical, 16)

            // Quick date navigation
            HStack(spacing: 12) {
                QuickDateButton(title: "Today", isSelected: viewModel.isToday) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.selectDate(Date())
                    }
                }

                QuickDateButton(title: "Yesterday", isSelected: Calendar.current.isDateInYesterday(viewModel.selectedDate)) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.selectDate(Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())
                    }
                }

                Button(action: {
                    showingDatePicker = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption)
                        Text("Pick Date")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
        .background(Color(.systemGroupedBackground))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.systemGray4)),
            alignment: .bottom
        )
    }

    // MARK: - Daily Summary Card

    private func dailySummaryCard(_ summary: DailyNutritionSummary) -> some View {
        Button(action: {
            showingDetailedStats = true
        }) {
            VStack(spacing: 12) {
                HStack {
                    Text("Daily Summary")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: "chart.bar.fill")
                        .font(.subheadline)
                        .foregroundColor(.blue)

                    Text("View Details")
                        .font(.caption)
                        .foregroundColor(.blue)
                }

                HStack(spacing: 20) {
                    summaryItem("Calories", value: summary.totalCalories, unit: "cal", color: .orange)
                    summaryItem("Protein", value: summary.totalProtein, unit: "g", color: .red)
                    summaryItem("Carbs", value: summary.totalCarbohydrates, unit: "g", color: .blue)
                    summaryItem("Fat", value: summary.totalFat, unit: "g", color: .purple)
                }

                HStack {
                    Text("\(summary.logCount) item\(summary.logCount == 1 ? "" : "s") logged")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("Tap for detailed analysis")
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .italic()
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
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

    // MARK: - Operation Feedback Banner

    private func operationFeedbackBanner(_ feedback: OperationFeedback) -> some View {
        HStack(spacing: 12) {
            // Icon
            Group {
                if feedback.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else if feedback.isError {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .frame(width: 16, height: 16)

            // Message
            Text(feedback.message)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)

            Spacer()

            // Dismiss button for errors
            if feedback.isError {
                Button("✕") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.clearOperationFeedback()
                    }
                }
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            feedback.isError ?
            Color.red.opacity(0.9) :
            (feedback.isLoading ? Color.blue.opacity(0.9) : Color.green.opacity(0.9))
        )
        .cornerRadius(0) // Full width banner
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
        FoodSelectionView(mealType: selectedMealForAdding, selectedDate: viewModel.selectedDate) { food, quantity, unit, loggedDate in
            // Add the food to the log
            Task { @MainActor in
                await viewModel.addFoodLog(
                    food: food,
                    quantity: quantity,
                    unit: unit,
                    mealType: selectedMealForAdding,
                    loggedAt: loggedDate
                )
            }
            showingFoodSelection = false
        }
    }

    private var datePickerSheet: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Enhanced date picker with indicators
                VStack {
                    DatePicker(
                        "Select Date",
                        selection: $viewModel.selectedDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .onChange(of: viewModel.selectedDate) { newDate in
                        // Load month data when month changes
                        Task {
                            await viewModel.loadDatesWithLogsForMonth(newDate)
                        }
                        // Auto-dismiss after selection for better UX
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            showingDatePicker = false
                        }
                    }

                    // Visual indicator legend
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 8, height: 8)
                            Text("Has food logs")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text("Today")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                .padding()

                // Quick date selection buttons
                VStack(spacing: 12) {
                    Text("Quick Select")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        QuickDatePickerButton(title: "Today", date: Date()) {
                            viewModel.selectDate(Date())
                            showingDatePicker = false
                        }

                        QuickDatePickerButton(title: "Yesterday", date: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()) {
                            viewModel.selectDate(Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())
                            showingDatePicker = false
                        }

                        QuickDatePickerButton(title: "This Week", date: Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()) {
                            viewModel.selectDate(Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date())
                            showingDatePicker = false
                        }

                        QuickDatePickerButton(title: "Last Week", date: Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()) {
                            viewModel.selectDate(Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date())
                            showingDatePicker = false
                        }
                    }
                }
                .padding()

                Spacer()
            }
            .navigationTitle("Select Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingDatePicker = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Helper Methods

    private enum DateNavigationDirection {
        case previous, next
    }

    private func navigateToDate(_ direction: DateNavigationDirection) {
        let calendar = Calendar.current
        let newDate: Date

        switch direction {
        case .previous:
            newDate = calendar.date(byAdding: .day, value: -1, to: viewModel.selectedDate) ?? viewModel.selectedDate
        case .next:
            newDate = calendar.date(byAdding: .day, value: 1, to: viewModel.selectedDate) ?? viewModel.selectedDate
        }

        // Show transition state
        isTransitioning = true

        // Animate the date change
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            viewModel.selectDate(newDate)

            // Hide transition state after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isTransitioning = false
                }
            }
        }
    }

    private func relativeDateString(for date: Date) -> String {
        let calendar = Calendar.current
        let today = Date()

        if calendar.isDate(date, inSameDayAs: today) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            let daysDifference = calendar.dateComponents([.day], from: today, to: date).day ?? 0
            if abs(daysDifference) <= 7 {
                if daysDifference > 0 {
                    return "\(daysDifference) day\(daysDifference == 1 ? "" : "s") ahead"
                } else {
                    return "\(abs(daysDifference)) day\(abs(daysDifference) == 1 ? "" : "s") ago"
                }
            } else {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                return formatter.string(from: date)
            }
        }
    }
}

// MARK: - Helper Views

struct QuickDateButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(.systemGray6))
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

struct QuickDatePickerButton: View {
    let title: String
    let date: Date
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
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