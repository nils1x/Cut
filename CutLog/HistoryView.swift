import SwiftUI
import Charts

struct HistoryView: View {
    @Environment(AppStore.self) private var store
    @State private var section: HistorySection = .weight
    @State private var weightRange: WeightRange = .thirtyDays
    @State private var editingWeight: WeightEntry?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CutLogStyle.Space.xl) {
                    SectionLabel("History") {
                        Picker("Section", selection: $section) {
                            ForEach(HistorySection.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 150)
                    }

                    if section == .weight {
                        weightContent
                    } else {
                        workoutContent
                    }
                }
                .padding(.horizontal, CutLogStyle.Space.l)
                .padding(.vertical, CutLogStyle.Space.l)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $editingWeight) { entry in
                AddWeightView(editing: entry)
            }
        }
    }

    // MARK: - Weight

    private var rangeChips: some View {
        HStack(spacing: CutLogStyle.Space.s) {
            ForEach(WeightRange.allCases) { range in
                RangePill(title: range.title, isSelected: range == weightRange) { weightRange = range }
            }
        }
    }

    private var visibleWeights: [WeightEntry] {
        let calendar = Calendar.current
        guard let start = weightRange.start(endingAt: .now, calendar: calendar) else { return sortedWeights }
        return sortedWeights.filter { $0.date >= start }
    }

    private var weightTrend: [WeightTrendPoint] {
        store.weightTrend(days: weightRange.days)
    }

    private var sortedWeights: [WeightEntry] {
        store.weights.sorted { $0.date > $1.date }
    }

    private var weightContent: some View {
        VStack(alignment: .leading, spacing: CutLogStyle.Space.l) {
            Card {
                VStack(alignment: .leading, spacing: CutLogStyle.Space.s) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(latestWeightText)
                            .font(CutLogStyle.Number.metric)
                            .monospacedDigit()
                        Spacer()
                        Text(rangeDeltaText)
                            .font(CutLogStyle.Number.value)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    if weightTrend.count > 1 {
                        WeightTrendChart(points: weightTrend, days: weightRange.days ?? 365)
                            .frame(height: 140)
                    } else {
                        Text(weightTrend.isEmpty ? "No weigh-ins in this range" : "One weigh-in in this range")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(height: 140, alignment: .topLeading)
                    }
                    Text(weightRange.title)
                        .font(CutLogStyle.Number.label)
                        .foregroundStyle(.secondary)
                }
            }

            rangeChips

            if visibleWeights.isEmpty {
                ContentUnavailableView("No weigh-ins", systemImage: "scalemass")
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(monthGroups(visibleWeights), id: \.title) { group in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(group.title)
                            .font(CutLogStyle.Number.label)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, CutLogStyle.Space.xs)
                        ForEach(Array(group.entries.enumerated()), id: \.element.id) { index, entry in
                            Button { editingWeight = entry } label: {
                                KeyValueRow(label: entry.date.formatted(.dateTime.weekday(.abbreviated).day()),
                                            value: "\(entry.kilograms.formatted(.number.precision(.fractionLength(1)))) kg",
                                            showsHairline: index < group.entries.count - 1)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var latestWeightText: String {
        guard let latest = store.latestWeight else { return "—" }
        return "\(latest.kilograms.formatted(.number.precision(.fractionLength(1)))) kg"
    }

    private var rangeDeltaText: String {
        guard let first = weightTrend.first, let last = weightTrend.last, last.kilograms != first.kilograms else { return "0.0 kg" }
        let delta = (last.kilograms - first.kilograms).formatted(.number.sign(strategy: .always()).precision(.fractionLength(1)))
        return "\(delta) kg"
    }

    private func monthGroups(_ entries: [WeightEntry]) -> [(title: String, entries: [WeightEntry])] {
        var order: [String] = []
        var grouped: [String: [WeightEntry]] = [:]
        for entry in entries {
            let title = entry.date.formatted(.dateTime.month(.wide).year())
            if grouped[title] == nil { order.append(title) }
            grouped[title, default: []].append(entry)
        }
        return order.map { (title: $0, entries: grouped[$0] ?? []) }
    }

    // MARK: - Workouts

    private var sortedWorkouts: [WorkoutEntry] {
        store.workouts.sorted { $0.completedAt > $1.completedAt }
    }

    private var workoutContent: some View {
        VStack(alignment: .leading, spacing: CutLogStyle.Space.l) {
            Card {
                HStack(alignment: .firstTextBaseline) {
                    StatTile(value: "\(thisMonthCount)", label: "this month")
                    StatTile(value: "\(totalSets)", label: "sets logged")
                }
            }

            if sortedWorkouts.isEmpty {
                ContentUnavailableView("No workouts", systemImage: "figure.strengthtraining.traditional")
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(monthGroups(workouts: sortedWorkouts), id: \.title) { group in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(group.title)
                            .font(CutLogStyle.Number.label)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, CutLogStyle.Space.xs)
                        ForEach(group.entries) { workout in
                            WorkoutSummaryRow(workout: workout, templateTitle: store.template(for: workout.templateID)?.title)
                        }
                    }
                }
            }
        }
    }

    private var thisMonthCount: Int {
        let calendar = Calendar.current
        return store.workouts.filter { calendar.isDate($0.completedAt, equalTo: .now, toGranularity: .month) }.count
    }

    private var totalSets: Int {
        store.workouts.reduce(0) { $0 + $1.completedSetCount }
    }

    private func monthGroups(workouts: [WorkoutEntry]) -> [(title: String, entries: [WorkoutEntry])] {
        var order: [String] = []
        var grouped: [String: [WorkoutEntry]] = [:]
        for workout in workouts {
            let title = workout.completedAt.formatted(.dateTime.month(.wide).year())
            if grouped[title] == nil { order.append(title) }
            grouped[title, default: []].append(workout)
        }
        return order.map { (title: $0, entries: grouped[$0] ?? []) }
    }
}

/// Flat row, not a DisclosureGroup: no nested list indentation, no expansion animation.
/// Missing fields stay missing rather than showing as zero.
private struct WorkoutSummaryRow: View {
    let workout: WorkoutEntry
    let templateTitle: String?

    private var title: String {
        workout.templateTitle ?? templateTitle ?? workout.templateID
    }

    private var details: String {
        var parts = [workout.completedAt.formatted(.dateTime.weekday(.abbreviated).day())]
        if workout.completedSetCount > 0 { parts.append("\(workout.completedSetCount) sets") }
        if let topSet = topSet { parts.append(topSet) }
        return parts.joined(separator: " · ")
    }

    private var topSet: String? {
        var best: (exercise: String, weight: Double)?
        for set in workout.sets where set.repetitions > 0 {
            if best == nil || set.weightKilograms > best!.weight { best = (set.exerciseName, set.weightKilograms) }
        }
        guard let best else { return nil }
        return "top \(best.exercise) \(best.weight.formatted(.number.precision(.fractionLength(0...1)))) kg"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer(minLength: CutLogStyle.Space.s)
                if workout.completedSetCount > 0 {
                    Text("\(workout.completedSetCount)")
                        .font(CutLogStyle.Number.label)
                        .monospacedDigit()
                        .foregroundStyle(CutLogPalette.sage)
                }
            }
            Text(details)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, CutLogStyle.Space.s)
        .overlay(alignment: .bottom) {
            Rectangle().fill(CutLogPalette.hairline).frame(height: 0.5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(details)")
    }
}

/// No axis labels: the range chip and the delta carry the meaning.
private struct WeightTrendChart: View {
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
                .foregroundStyle(CutLogPalette.apricot)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.monotone)
        }
        .chartYScale(domain: (low - padding)...(high + padding))
        .chartXScale(domain: xDomain)
        .chartXAxis(.hidden).chartYAxis(.hidden).chartLegend(.hidden)
        .accessibilityLabel("Weight trend, rolling seven-day average")
        .accessibilityValue("\(Int(points.count)) days")
    }

    private var xDomain: ClosedRange<Date> {
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: .now)
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: end) ?? end.addingTimeInterval(-86_400)
        return start...end.addingTimeInterval(86_400)
    }
}

private enum HistorySection: String, CaseIterable, Identifiable {
    case weight, workouts
    var id: String { rawValue }
    var title: String { self == .weight ? "Weight" : "Workouts" }
}

enum WeightRange: Int, CaseIterable, Identifiable {
    case thirtyDays = 30
    case ninetyDays = 90
    case all = 0

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .thirtyDays: "30 days"
        case .ninetyDays: "90 days"
        case .all: "All"
        }
    }

    /// nil means "no lower bound".
    var days: Int? { self == .all ? nil : rawValue }

    func start(endingAt date: Date, calendar: Calendar = .current) -> Date? {
        guard let days else { return nil }
        let today = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: -(days - 1), to: today)
    }
}