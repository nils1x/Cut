import SwiftUI
import Charts

struct TodayView: View {
    @Environment(AppStore.self) private var store
    @State private var foodRoute: AddFoodView.StartMode?
    @State private var showingWorkout = false
    @State private var showingWeight = false
    @ScaledMetric(relativeTo: .largeTitle) private var calorieFontSize = 48

    private var totals: DailyTotals { store.todayTotals }
    private var caloriesLeft: Int { store.settings.calorieGoal - totals.calories }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Cut.")
                                .font(.largeTitle.weight(.bold))
                            Text(Date.now, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 12)
                        LoggingStreakDisplay(streak: store.loggingStreak)
                    }

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
                            .tint(Color.accentColor)
                        LabeledContent("Protein", value: "\(totals.protein) / \(store.settings.proteinGoal) g")
                            .font(.subheadline).monospacedDigit()
                        Divider()
                        WeightSummary(latestWeight: store.latestWeight,
                                      trend: store.weightTrend(days: 90)) { showingWeight = true }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Button { showingWorkout = true } label: {
                        WorkoutStatusCard(template: store.launchWorkout.template, isDue: store.workoutIsDue, isResuming: !store.unfinishedWorkouts.isEmpty, didTrainToday: !store.workoutIsDue && WorkoutSchedule.scheduledWorkout(on: .now) != nil && store.workouts.contains { $0.templateID == store.launchWorkout.template.id && Calendar.current.isDateInToday($0.startedAt ?? $0.completedAt) })
                    }
                    .buttonStyle(.plain)

                    Button { foodRoute = .manual } label: {
                        Label("Log food", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 54)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.accentColor)
                    .accessibilityHint("Opens food logging. Barcode and photo options are available there.")

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
            .toolbar(.hidden, for: .navigationBar)
            .task(id: store.workouts.count) {
                await WorkoutReminder.refresh(isDue: store.workoutIsDue, enabled: store.settings.reminderEnabled)
            }
            .sheet(item: $foodRoute) { mode in AddFoodView(startMode: mode) }
            .sheet(isPresented: $showingWorkout) {
                if store.unfinishedWorkouts.isEmpty && store.workoutIsDue {
                    WorkoutView(template: store.launchWorkout.template)
                } else {
                    WorkoutLaunchView()
                }
            }
            .sheet(isPresented: $showingWeight) { AddWeightView() }
        }
    }

}

private struct LoggingStreakDisplay: View {
    let streak: Int
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: streak > 0 ? "flame.fill" : "flame")
                .foregroundStyle(streak > 0 ? Color.accentColor : Color.secondary)
            Text(streak, format: .number)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .font(.subheadline.weight(.semibold))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(streak) day logging streak. Any food or weight log counts.")
    }
}

private struct WeightSummary: View {
    let latestWeight: WeightEntry?
    let trend: [WeightTrendPoint]
    let addWeight: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: addWeight) {
                HStack(spacing: 10) {
                    Image(systemName: "scalemass")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Weight").font(.caption).foregroundStyle(.secondary)
                        Text(latestWeight.map { "\($0.kilograms, format: .number.precision(.fractionLength(1))) kg" } ?? "Log your weight")
                            .font(.headline.weight(.semibold)).foregroundStyle(.primary)
                    }
                    Spacer()
                    Text(Calendar.current.isDateInToday(latestWeight?.date ?? .distantPast) ? "Logged today" : "Add weight")
                        .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, minHeight: 60)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(latestWeight.map { "Log weight. Latest \($0.kilograms.formatted(.number.precision(.fractionLength(1)))) kilograms" } ?? "Log weight")
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
                Text(latestWeight == nil ? "Add a weigh-in to start your trend." : "No weigh-ins in the last 90 days.")
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
                .foregroundStyle(isDue ? Color.accentColor : Color.secondary)
                .frame(width: 42, height: 42)
                .background((isDue ? Color.accentColor : Color.secondary).opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(isResuming ? "Choose workout" : (isDue ? "Training today" : (didTrainToday ? "Training saved" : "Recovery day")))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isDue ? Color.accentColor : Color.secondary)
                Text(template.title)
                    .font(.headline)
                Text(isResuming ? "Continue a saved session or start this one" : (isDue ? template.subtitle : (didTrainToday ? "Completed today" : "Next session")))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
        .padding(18)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct FoodRow: View {
    let food: FoodEntry

    var body: some View {
        HStack {
            Image(systemName: "fork.knife")
                .foregroundStyle(Color.accentColor)
                .frame(width: 34, height: 34)
                .background(Color.accentColor.opacity(0.12), in: Circle())
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
