import SwiftUI

struct WorkoutView: View {
	@Environment(AppStore.self) private var store
	@Environment(\.dismiss) private var dismiss
	let template: WorkoutTemplate
	@State private var completedSets: Set<String> = []
	@State private var setValues: [String: SetValue] = [:]
	@State private var isFinished = false

	private var totalSets: Int { template.exercises.reduce(0) { $0 + $1.sets } }
	private var canFinish: Bool { completedSets.count == totalSets && loggedSets.count == totalSets }

	var body: some View {
		NavigationStack {
			List {
				Section {
					HStack {
						Label(template.subtitle, systemImage: "figure.strengthtraining.traditional")
						Spacer()
						Text("\(completedSets.count) / \(totalSets) sets")
							.monospacedDigit()
							.foregroundStyle(.secondary)
					}
				}

				ForEach(template.exercises) { exercise in
					Section {
						if let previous = store.lastPerformance(for: exercise.name) {
							Text("Last: \(previous.weightKilograms, format: .number.precision(.fractionLength(1))) kg × \(previous.repetitions) · \(previous.rir, format: .number.precision(.fractionLength(0))) RIR")
								.font(.footnote)
								.foregroundStyle(.secondary)
						}

						ForEach(1...exercise.sets, id: \.self) { number in
							let id = setID(for: exercise, number: number)
							SetRow(number: number, target: exercise.reps, rirTarget: exercise.rirTarget, value: binding(for: id, exercise: exercise), isComplete: completedSets.contains(id)) {
								toggleSet(id)
							}
						}
					} header: {
						Text(exercise.name)
					}
				}

				Section {
					Button {
						store.completeWorkout(templateID: template.id, sets: loggedSets)
						isFinished = true
					} label: {
						Text("Finish workout")
							.frame(maxWidth: .infinity)
							.fontWeight(.bold)
					}
					.disabled(!canFinish)
				} footer: {
					Text("Complete every set with kg, reps, and RIR. No invented calories burned.")
				}
			}
			.navigationTitle(template.title)
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Close") { dismiss() }
				}
			}
			.alert("Workout logged", isPresented: $isFinished) {
				Button("Nice") { dismiss() }
			} message: {
				Text("Next session: \(store.nextWorkout.title).")
			}
		}
	}

	private var loggedSets: [LoggedSet] {
		template.exercises.flatMap { exercise in
			(1...exercise.sets).compactMap { number in
				let id = setID(for: exercise, number: number)
				guard completedSets.contains(id), let value = setValues[id], let weight = Double(value.weight.replacingOccurrences(of: ",", with: ".")), let reps = Int(value.reps), let rir = Double(value.rir.replacingOccurrences(of: ",", with: ".")) else { return nil }
				return LoggedSet(exerciseName: exercise.name, setNumber: number, weightKilograms: weight, repetitions: reps, rir: rir)
			}
		}
	}

	private func setID(for exercise: Exercise, number: Int) -> String { "\(exercise.id)-\(number)" }

	private func binding(for id: String, exercise: Exercise) -> Binding<SetValue> {
		Binding(
			get: {
				if let value = setValues[id] { return value }
				let previous = store.lastPerformance(for: exercise.name)
				return SetValue(
					weight: previous.map { String(format: "%.1f", $0.weightKilograms) } ?? "",
					reps: previous.map { String($0.repetitions) } ?? "",
					rir: previous.map { String(format: "%.0f", $0.rir) } ?? exercise.rirTarget.components(separatedBy: "–").first ?? ""
				)
			},
			set: { setValues[id] = $0 }
		)
	}

	private func toggleSet(_ id: String) {
		if completedSets.contains(id) { completedSets.remove(id) }
		else { completedSets.insert(id) }
	}
}

private struct SetValue: Equatable {
	var weight: String
	var reps: String
	var rir: String
}

private struct SetRow: View {
	let number: Int
	let target: String
	let rirTarget: String
	@Binding var value: SetValue
	let isComplete: Bool
	let toggle: () -> Void

	var body: some View {
		HStack(spacing: 8) {
			Button(action: toggle) {
				Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
					.foregroundStyle(isComplete ? .green : .secondary)
			}
			.buttonStyle(.plain)
			Text("\(number)").frame(width: 14, alignment: .leading)
			TextField("kg", text: $value.weight)
				.keyboardType(.decimalPad)
				.multilineTextAlignment(.trailing)
				.frame(maxWidth: 58)
			Text("×").foregroundStyle(.secondary)
			TextField("reps", text: $value.reps)
				.keyboardType(.numberPad)
				.multilineTextAlignment(.trailing)
				.frame(maxWidth: 42)
			TextField("RIR", text: $value.rir)
				.keyboardType(.decimalPad)
				.multilineTextAlignment(.trailing)
				.frame(maxWidth: 40)
			Spacer(minLength: 0)
			Text("\(target) · \(rirTarget)")
				.font(.caption2)
				.foregroundStyle(.secondary)
		}
	}
}
