import SwiftUI
import Charts

struct TodayView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.scenePhase) private var scenePhase
    @State private var foodRoute: AddFoodView.StartMode?
    @State private var showingWorkout = false
    @State private var showingWeight = false
    /// Remind on every app open when a session is due. Session state only, never persisted:
    /// ignoring the nudge must not silence it forever.
    @State private var showsTrainingNudge = false

    private var totals: DailyTotals { store.todayTotals }
    private var headline: CalorieHeadline { CalorieHeadline(totals: totals, goal: store.settings.calorieGoal) }
    private var weightTrend: [WeightTrendPoint] { store.weightTrend(days: 30) }
    private var isCompact: Bool { typeSize >= .accessibility1 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CutLogStyle.Space.xl) {
                    header
                    if isCompact {
                        energyCard
                        consistencySection
                        weightSection
                        trainingRow
                    } else {
                        energyAndConsistency
                        weightAndTraining
                    }
                    logFoodButton
                    todaySection
                }
                .padding(.horizontal, CutLogStyle.Space.l)
                .padding(.top, CutLogStyle.Space.s)
                .padding(.bottom, CutLogStyle.Space.xl)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { trainingNudge }
            .toolbar(.hidden, for: .navigationBar)
            .task(id: store.workouts.count) {
                await WorkoutReminder.refresh(isDue: store.workoutIsDue, enabled: store.settings.reminderEnabled)
            }
            .sheet(item: $foodRoute) { mode in AddFoodView(startMode: mode) }
            .sheet(isPresented: $showingWorkout) { workoutSheet }
            .sheet(isPresented: $showingWeight) { AddWeightView() }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active: showsTrainingNudge = store.workoutIsDue
                case .background: showsTrainingNudge = false
                default: break
                }
            }
        }
    }

    /// Slim sage bar. Complements the 6 PM notification, does not replace it, and needs no
    /// permission because it is in-app.
    @ViewBuilder
    private var trainingNudge: some View {
        if showsTrainingNudge && store.workoutIsDue {
            HStack(spacing: CutLogStyle.Space.m) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .foregroundStyle(CutLogPalette.sage)
                Text("\(store.launchWorkout.template.title) is due today")
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Spacer(minLength: CutLogStyle.Space.s)
                Button("Start") {
                    showsTrainingNudge = false
                    showingWorkout = true
                }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .tint(CutLogPalette.sage)
                .controlSize(.small)
            }
            .padding(.horizontal, CutLogStyle.Space.l)
            .padding(.vertical, CutLogStyle.Space.s)
            .background(.bar)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Training due. \(store.launchWorkout.template.title) is due today.")
        }
    }

    @ViewBuilder
    private var workoutSheet: some View {
        if store.unfinishedWorkouts.isEmpty && store.workoutIsDue {
            WorkoutView(template: store.launchWorkout.template)
        } else {
            WorkoutLaunchView()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Cut.")
                    .font(.largeTitle.weight(.bold))
                Text(Date.now, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: CutLogStyle.Space.m)
            streakDisplay
        }
    }

    private var streakDisplay: some View {
        let streak = store.loggingStreak
        return HStack(spacing: 4) {
            Image(systemName: streak > 0 ? "flame.fill" : "flame")
                .foregroundStyle(streak > 0 ? CutLogPalette.apricot : Color.secondary)
            Text(streak, format: .number)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(streak) day logging streak. Any food or weight log counts.")
    }

    // MARK: - Two-column rows

    /// Calories left, 30-day grid right. One card, fixed 8pt rhythm.
    private var energyAndConsistency: some View {
        Card {
            HStack(alignment: .top, spacing: CutLogStyle.Space.m) {
                energyBlock
                    .frame(maxWidth: .infinity, alignment: .leading)
                ConsistencyChart(days: store.consistencyLevels())
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var energyBlock: some View {
        VStack(alignment: .leading, spacing: CutLogStyle.Space.s) {
            HStack(alignment: .firstTextBaseline, spacing: CutLogStyle.Space.xs) {
                Text(headline.consumed, format: .number)
                    .font(CutLogStyle.Number.hero)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(headline.isOverGoal ? Color.red : Color.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text("/ \(headline.goal)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text(headline.isOverGoal ? "kcal over" : "kcal")
                .font(CutLogStyle.Number.label)
                .foregroundStyle(.secondary)
            MetricBar(value: headline.progress,
                      tint: headline.isOverGoal ? Color.red : CutLogPalette.apricot, height: 3)
            HStack(spacing: CutLogStyle.Space.m) {
                StatTile(value: "\(totals.protein)", label: "P", bar: Double(totals.protein) / Double(max(1, store.settings.proteinGoal)))
                StatTile(value: "\(totals.carbs)", label: "C")
                StatTile(value: "\(totals.fat)", label: "F")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(headline.consumed) of \(headline.goal) calories, \(headline.isOverGoal ? "over goal" : "under goal"). Protein \(totals.protein) of \(store.settings.proteinGoal) grams, carbs \(totals.carbs) grams, fat \(totals.fat) grams.")
    }

    /// Weight left, training right. The row owns one fixed height and both cards fill it,
    /// so they are equal by construction rather than by two separate constraints.
    private var weightAndTraining: some View {
        HStack(alignment: .top, spacing: CutLogStyle.Space.m) {
            Card {
                weightContents
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            Button { showingWorkout = true } label: {
                Card {
                    trainingContents
                }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(height: pairHeight)
    }

    /// Sized to fit the taller card (weight) plus its padding. Both cards use this one value.
    private let pairHeight: CGFloat = 140

    // MARK: - Stacked variants

    private var energyCard: some View {
        Card {
            energyBlock
        }
    }

    private var consistencySection: some View {
        Card {
            ConsistencyChart(days: store.consistencyLevels())
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var weightSection: some View {
        Card {
            weightContents
        }
    }

    private var trainingRow: some View {
        Button { showingWorkout = true } label: {
            Card {
                trainingContents
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the workout.")
    }

    // MARK: - Shared blocks

    private var weightContents: some View {
        VStack(alignment: .leading, spacing: CutLogStyle.Space.xs) {
            SectionLabel("Weight")
            Button { showingWeight = true } label: {
                Text(latestWeightText)
                    .font(CutLogStyle.Number.metric)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
            if weightTrend.count > 1 {
                WeightSparkline(points: weightTrend, days: 30)
                    .frame(height: 30)
                Text("\(weightDeltaText) · 30d")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            } else {
                Text(store.latestWeight == nil ? "Add a weigh-in" : "One weigh-in")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(weightAccessibilityLabel)
    }

    private var latestWeightText: String {
        guard let latest = store.latestWeight else { return "—" }
        return "\(latest.kilograms.formatted(.number.precision(.fractionLength(1)))) kg"
    }

    private var weightDeltaText: String {
        guard let first = weightTrend.first, let last = weightTrend.last, last.kilograms != first.kilograms else { return "0.0 kg" }
        let delta = (last.kilograms - first.kilograms).formatted(.number.sign(strategy: .always()).precision(.fractionLength(1)))
        return "\(delta) kg"
    }

    private var weightAccessibilityLabel: String {
        let latest = store.latestWeight.map { "latest \($0.kilograms.formatted(.number.precision(.fractionLength(1)))) kilograms" } ?? "no weigh-in"
        return "Weight, \(latest). Change over 30 days: \(weightDeltaText)."
    }

    private var trainingContents: some View {
        VStack(alignment: .leading, spacing: CutLogStyle.Space.xs) {
            SectionLabel("Training") {
                Image(systemName: trainingSymbol)
                    .font(.subheadline)
                    .foregroundStyle(store.workoutIsDue ? CutLogPalette.sage : Color.secondary)
            }
            Text(store.launchWorkout.template.title)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(2)
            Spacer(minLength: 0)
            Text(trainingStatus)
                .font(CutLogStyle.Number.label)
                .foregroundStyle(store.workoutIsDue ? CutLogPalette.sage : Color.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the workout.")
    }

    private var trainingSymbol: String {
        if !store.unfinishedWorkouts.isEmpty { return "play.fill" }
        return store.workoutIsDue ? "figure.strengthtraining.traditional" : "checkmark"
    }

    private var trainingStatus: String {
        if !store.unfinishedWorkouts.isEmpty { return "Unfinished session" }
        if store.workoutIsDue { return "Due today" }
        return didTrainToday ? "Done today" : "Rest day"
    }

    private var didTrainToday: Bool {
        guard let scheduled = WorkoutSchedule.scheduledWorkout(on: .now) else { return false }
        return !store.workoutIsDue && store.workouts.contains {
            $0.templateID == scheduled.templateID && Calendar.current.isDate($0.startedAt ?? $0.completedAt, inSameDayAs: .now)
        }
    }

    // MARK: - Actions

    private var logFoodButton: some View {
        Button { foodRoute = .manual } label: {
            Label("Log food", systemImage: "plus")
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 56)
        }
        .buttonStyle(.borderedProminent)
        .tint(CutLogPalette.apricot)
        .controlSize(.large)
        .accessibilityHint("Opens food logging. Search, barcode and photo options are available there.")
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: CutLogStyle.Space.m) {
            SectionLabel("Today")

            if !store.quickLogFoods.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: CutLogStyle.Space.s) {
                        ForEach(store.quickLogFoods.prefix(4)) { food in
                            Button { store.addFood(FoodCatalog.entry(from: food)) } label: {
                                Text(food.name)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                    .padding(.horizontal, CutLogStyle.Space.m)
                                    .padding(.vertical, 6)
                                    .background(CutLogPalette.surface, in: Capsule())
                                    .overlay { Capsule().strokeBorder(CutLogPalette.hairline, lineWidth: 0.5) }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if store.todayFoods.isEmpty {
                ContentUnavailableView("Nothing logged", systemImage: "fork.knife")
                    .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 0) {
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
        }
    }
}

private struct WeightSparkline: View {
    let points: [WeightTrendPoint]
    let days: Int

    var body: some View {
        let values = points.map(\.kilograms)
        let low = values.min() ?? 0
        let high = values.max() ?? low
        // At least 1 kg of vertical range: don't dramatize tiny daily noise.
        let padding = max(0.15, (1 - (high - low)) / 2)
        Chart(points) { point in
            LineMark(x: .value("Date", point.date), y: .value("7-day average", point.kilograms))
                .foregroundStyle(CutLogPalette.apricot.opacity(0.9))
                .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.monotone)
        }
        .chartYScale(domain: (low - padding)...(high + padding))
        .chartXScale(domain: xDomain)
        .chartXAxis(.hidden).chartYAxis(.hidden).chartLegend(.hidden)
        .accessibilityHidden(true)
    }

    /// Fixed 30-day window, so one old or isolated weigh-in cannot stretch the line edge to edge.
    private var xDomain: ClosedRange<Date> {
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: .now)
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: end) ?? end.addingTimeInterval(-86_400)
        return start...end.addingTimeInterval(86_400)
    }
}

private struct FoodRow: View {
    let food: FoodEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(food.name).fontWeight(.medium)
                Text("P \(food.protein) · C \(food.carbs) · F \(food.fat)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(food.calories, format: .number)
                .fontWeight(.semibold)
                .monospacedDigit()
            Text("kcal")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, CutLogStyle.Space.s)
        .overlay(alignment: .bottom) {
            Rectangle().fill(CutLogPalette.hairline).frame(height: 0.5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(food.name), \(food.calories) calories, protein \(food.protein), carbs \(food.carbs), fat \(food.fat) grams")
    }
}