import SwiftUI
import Charts

struct TodayView: View {
    @Environment(AppStore.self) private var store
    @State private var foodRoute: AddFoodView.StartMode?
    @State private var showingWorkout = false
    @State private var showingWeight = false
    @State private var weightRange = 90
    @ScaledMetric(relativeTo: .largeTitle) private var calorieFontSize = 48

    private var totals: DailyTotals { store.todayTotals }
    private var caloriesLeft: Int { store.settings.calorieGoal - totals.calories }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(Date.now, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(abs(caloriesLeft), format: .number)
                                .font(.system(size: calorieFontSize, weight: .bold, design: .rounded))
                                .monospacedDigit().contentTransition(.numericText())
                                .lineLimit(1).minimumScaleFactor(0.7)
                            Text(caloriesLeft >= 0 ? "kcal left" : "kcal over")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        ProgressView(value: min(1, max(0, Double(totals.calories) / Double(max(1, store.settings.calorieGoal)))))
                            .tint(.orange)
                        LabeledContent("Protein", value: "\(totals.protein) / \(store.settings.proteinGoal) g")
                            .font(.subheadline).monospacedDigit()
                        Divider()
                        WeightSummary(latestWeight: store.latestWeight,
                                      trend: store.weightTrend(days: weightRange == 0 ? nil : weightRange),
                                      range: $weightRange) { showingWeight = true }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                    Button { showingWorkout = true } label: {
                        WorkoutStatusCard(template: store.nextWorkout, isDue: store.workoutIsDue, isResuming: store.activeWorkout != nil, didTrainToday: store.workouts.contains { Calendar.current.isDateInToday($0.completedAt) })
                    }
                    .buttonStyle(.plain)

                    FoodActionsCard { foodRoute = $0 }

                    if !store.quickLogFoods.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(store.quickLogFoods.prefix(4)) { food in
                                    Button {
                                        store.addFood(FoodEntry(
                                            name: food.name,
                                            calories: food.calories,
                                            protein: food.protein,
                                            carbs: food.carbs,
                                            fat: food.fat,
                                            servingGrams: food.servingGrams,
                                            barcode: food.barcode
                                        ))
                                    } label: {
                                        Text(food.name)
                                            .lineLimit(1)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(.secondary.opacity(0.10), in: Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    if store.todayFoods.isEmpty {
                        ContentUnavailableView(
                            "Nothing logged",
                            systemImage: "fork.knife",
                            description: Text("Add food. Rough beats imaginary.")
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    } else {
                        ForEach(store.todayFoods) { food in
                            FoodRow(food: food)
                                .contextMenu {
                                    Button(role: .destructive) { store.deleteFood(food) } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Cut.")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Cut.").font(.headline.weight(.bold))
                }
            }
            .task(id: store.workouts.count) {
                await WorkoutReminder.refresh(isDue: store.workoutIsDue, enabled: store.settings.reminderEnabled)
            }
            .sheet(item: $foodRoute) { mode in AddFoodView(startMode: mode) }
            .sheet(isPresented: $showingWorkout) { WorkoutView(template: store.nextWorkout) }
            .sheet(isPresented: $showingWeight) { AddWeightView() }
        }
    }

}

private struct FoodActionsCard: View {
    let select: (AddFoodView.StartMode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Log food", systemImage: "fork.knife")
                .font(.headline)
                .foregroundStyle(.orange)

            HStack(spacing: 10) {
                FoodActionButton(title: "Barcode", symbol: "barcode.viewfinder") {
                    select(.barcode)
                }
                FoodActionButton(title: "Photo", symbol: "camera") {
                    select(.photo)
                }
                FoodActionButton(title: "Manual", symbol: "square.and.pencil") {
                    select(.manual)
                }
            }
        }
        .padding(16)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct FoodActionButton: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.title3.weight(.semibold))
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(.primary)
            .background(.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Log food with \(title)")
    }
}

private struct WeightSummary: View {
    let latestWeight: WeightEntry?
    let trend: [WeightTrendPoint]
    @Binding var range: Int
    let addWeight: () -> Void

    private var rangeTitle: String { range == 0 ? "All time" : "\(range) days" }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button(action: addWeight) {
                    HStack(spacing: 6) {
                        Text("Weight").foregroundStyle(.secondary)
                        if let latestWeight {
                            Text("\(latestWeight.kilograms, format: .number.precision(.fractionLength(1))) kg")
                                .fontWeight(.semibold).foregroundStyle(.primary)
                        }
                        Image(systemName: "plus.circle").foregroundStyle(.orange)
                    }
                    .font(.subheadline)
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Add a weigh-in")
                Spacer(minLength: 4)
                Menu {
                    Picker("Weight history", selection: $range) {
                        Text("30 days").tag(30)
                        Text("90 days").tag(90)
                        Text("All time").tag(0)
                    }
                } label: {
                    Label(rangeTitle, systemImage: "chevron.down")
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(minHeight: 44)
                }
            }
            if let first = trend.first, let last = trend.last {
                if trend.count > 1 {
                    HStack {
                        Text("\(last.kilograms - first.kilograms, format: .number.sign(strategy: .always()).precision(.fractionLength(1))) kg")
                            .fontWeight(.medium)
                        Text("trend change").foregroundStyle(.secondary)
                        Spacer()
                        Text("7-day smoothing").foregroundStyle(.secondary)
                    }
                    .font(.caption)
                    WeightSparkline(points: trend)
                        .frame(height: 44)
                    HStack {
                        Text(first.date, format: .dateTime.month(.abbreviated).day())
                        Spacer()
                        Text(last.date, format: .dateTime.month(.abbreviated).day())
                    }
                    .font(.caption2).foregroundStyle(.secondary)
                } else {
                    Text("One weigh-in. Your trend starts with the next.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else {
                Text(latestWeight == nil ? "Add a weigh-in to start your trend." : "No weigh-ins in this range. Try All time.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let latestWeight, !Calendar.current.isDateInToday(latestWeight.date) {
                Text("Last weighed \(latestWeight.date.formatted(.dateTime.month(.abbreviated).day()))")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}

private struct WeightSparkline: View {
    let points: [WeightTrendPoint]

    var body: some View {
        let low = points.map(\.kilograms).min() ?? 0
        let high = points.map(\.kilograms).max() ?? low
        // At least 1 kg of vertical range: don't dramatize tiny daily noise.
        let padding = max(0.15, (1 - (high - low)) / 2)
        Chart(points) { point in
            LineMark(x: .value("Date", point.date), y: .value("7-day average", point.kilograms))
                .foregroundStyle(.primary.opacity(0.75))
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .chartYScale(domain: (low - padding)...(high + padding))
        .chartXAxis(.hidden).chartYAxis(.hidden).chartLegend(.hidden)
        .accessibilityLabel("Weight trend, rolling seven-day average of available weigh-ins")
    }
}

private struct WorkoutStatusCard: View {
    let template: WorkoutTemplate
    let isDue: Bool
    let isResuming: Bool
    let didTrainToday: Bool

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: isResuming ? "play.fill" : (didTrainToday ? "checkmark.circle.fill" : "figure.strengthtraining.traditional"))
                .font(.title2)
                .foregroundStyle(isDue ? .orange : .green)
                .frame(width: 42, height: 42)
                .background((isDue ? Color.orange : .green).opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(isResuming ? "Resume training" : (isDue ? "Training today" : (didTrainToday ? "Training saved" : "Recovery day")))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isDue ? .orange : .green)
                Text(template.title)
                    .font(.headline)
                Text(isResuming ? "Your sets are saved" : (isDue ? template.subtitle : "Next session"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
        .padding(18)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct FoodRow: View {
    let food: FoodEntry

    var body: some View {
        HStack {
            Image(systemName: "fork.knife")
                .foregroundStyle(.orange)
                .frame(width: 34, height: 34)
                .background(.orange.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(food.name).fontWeight(.medium)
                Text("P \(food.protein)g · C \(food.carbs)g · F \(food.fat)g")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(food.calories)").fontWeight(.semibold)
            Text("kcal").font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}
