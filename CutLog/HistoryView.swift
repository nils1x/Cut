import SwiftUI

struct HistoryView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        NavigationStack {
            List {
                Section("Weight") {
                    if store.weights.isEmpty {
                        Text("No weigh-ins yet").foregroundStyle(.secondary)
                    } else {
                        ForEach(store.weights.sorted { $0.date > $1.date }) { entry in
                            HStack {
                                Text(entry.date, format: .dateTime.month(.abbreviated).day())
                                Spacer()
                                Text(entry.kilograms, format: .number.precision(.fractionLength(1)))
                                    .monospacedDigit()
                                Text("kg").foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Section("Workouts") {
                    if store.workouts.isEmpty {
                        Text("No workouts yet").foregroundStyle(.secondary)
                    } else {
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
            .navigationTitle("History")
        }
    }
}
