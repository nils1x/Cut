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
                            HStack {
                                Label("Full body \(workout.templateID)", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Spacer()
                                Text("\(workout.sets.count) sets")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
        }
    }
}
