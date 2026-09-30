import SwiftUI

struct HistoryView: View {
    @Environment(AppStore.self) private var store
    @State private var selection = HistorySection.weight

    private var sortedWeights: [WeightEntry] {
        store.weights.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("History section", selection: $selection) {
                    ForEach(HistorySection.allCases) { section in
                        Text(section.title).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 4)

                List {
                    if selection == .weight {
                        weightSection
                    } else {
                        workoutSection
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("History")
        }
    }

    @ViewBuilder
    private var weightSection: some View {
        if sortedWeights.isEmpty {
            ContentUnavailableView("No weigh-ins yet", systemImage: "scalemass")
        } else {
            Section("Recent weigh-ins") {
                ForEach(sortedWeights.prefix(10)) { entry in
                    weightRow(entry)
                }
                if sortedWeights.count > 10 {
                    NavigationLink {
                        AllWeightLogsView(entries: sortedWeights)
                    } label: {
                        Label("All weigh-ins", systemImage: "list.bullet")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var workoutSection: some View {
        if store.workouts.isEmpty {
            ContentUnavailableView("No workouts yet", systemImage: "figure.strengthtraining.traditional")
        } else {
            Section("Workouts") {
                ForEach(store.workouts.sorted { $0.completedAt > $1.completedAt }) { workout in
                    DisclosureGroup {
                        if let records = workout.setRecords {
                            ForEach(records) { record in
                                VStack(alignment: .leading, spacing: 3) {
                                    Label("\(record.exerciseName) · Set \(record.setNumber)", systemImage: record.isComplete ? "checkmark.circle" : "minus.circle")
                                        .font(.subheadline)
                                    Text("\(record.weight.isEmpty ? "—" : record.weight) kg · \(record.reps.isEmpty ? "—" : record.reps) reps · \(record.rir.isEmpty ? "—" : record.rir) RIR")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        } else {
                            ForEach(workout.sets) { set in
                                Text("\(set.exerciseName) · \(set.weightKilograms, format: .number) kg × \(set.repetitions) · \(set.rir, format: .number) RIR")
                                    .font(.caption)
                            }
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(workout.templateTitle ?? store.template(for: workout.templateID)?.title ?? workout.templateID)
                                .fontWeight(.medium)
                            Text("\(workout.completedAt.formatted(.dateTime.month(.abbreviated).day())) · \(workout.completedSetCount) sets completed")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func weightRow(_ entry: WeightEntry) -> some View {
        HStack {
            Text(entry.date, format: .dateTime.month(.abbreviated).day())
            Spacer()
            Text(entry.kilograms, format: .number.precision(.fractionLength(1)))
                .monospacedDigit()
            Text("kg").foregroundStyle(.secondary)
        }
    }
}

private enum HistorySection: String, CaseIterable, Identifiable {
    case weight
    case workouts

    var id: String { rawValue }
    var title: String { self == .weight ? "Weight" : "Workouts" }
}

private struct AllWeightLogsView: View {
    let entries: [WeightEntry]

    var body: some View {
        List(entries) { entry in
            HStack {
                Text(entry.date, format: .dateTime.month(.abbreviated).day().year())
                Spacer()
                Text(entry.kilograms, format: .number.precision(.fractionLength(1)))
                    .monospacedDigit()
                Text("kg").foregroundStyle(.secondary)
            }
        }
        .navigationTitle("All weigh-ins")
        .navigationBarTitleDisplayMode(.inline)
    }
}
