import SwiftUI

struct WorkoutView: View {
	@Environment(AppStore.self) private var store
	@Environment(\.dismiss) private var dismiss
	let template: WorkoutTemplate
	@State private var confirmingFinish = false

	var body: some View {
		NavigationStack {
			List {
				if let draft = store.activeWorkout {
					Section {
						LabeledContent("Completed", value: "\(draft.completedSetCount) / \(draft.sets.count) sets")
					} footer: {
						Text("Saved automatically. Close and resume whenever you like.")
					}
					ForEach(draft.template.exercises) { exercise in
						Section {
							Text("\(exercise.reps) reps · \(exercise.rirTarget) RIR · \(exercise.restSeconds)s rest")
								.font(.caption).foregroundStyle(.secondary)
							if let previous = store.lastPerformance(for: exercise.name) {
								Text("Last: \(previous.weightKilograms, format: .number.precision(.fractionLength(1))) kg × \(previous.repetitions) · \(previous.rir, format: .number) RIR")
									.font(.caption).foregroundStyle(.secondary)
							}
							ForEach(draft.sets.filter { $0.id.hasPrefix("\(exercise.id)-") }) { set in
								SetRow(value: binding(for: set))
							}
						} header: { Text(exercise.name) }
					}
					Section {
						Button("Finish workout") {
							if draft.completedSetCount < draft.sets.count || draft.loggedSets.count < draft.sets.count {
								confirmingFinish = true
							} else { finish() }
						}
						.fontWeight(.semibold)
						.frame(maxWidth: .infinity, minHeight: 44)
					} footer: {
						Text("You can finish with skipped sets or empty fields. Only what you entered is recorded.")
					}
				}
			}
			.navigationTitle(store.activeWorkout?.template.title ?? template.title)
			.navigationBarTitleDisplayMode(.inline)
			.scrollDismissesKeyboard(.interactively)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
			}
			.onAppear { store.beginWorkout(template) }
			.alert("Finish this session?", isPresented: $confirmingFinish) {
				Button("Keep training", role: .cancel) {}
				Button("Finish workout") { finish() }
			} message: {
				Text("All entries and checkmarks will be kept. Unchecked sets stay skipped; missing numbers stay empty.")
			}
		}
	}

	private func binding(for set: WorkoutSetDraft) -> Binding<WorkoutSetDraft> {
		Binding(get: { store.activeWorkout?.sets.first { $0.id == set.id } ?? set }, set: { store.updateWorkoutSet($0) })
	}

	private func finish() {
		store.finishWorkout()
		dismiss()
	}
}

private struct SetRow: View {
	@Binding var value: WorkoutSetDraft

	var body: some View {
		HStack(spacing: 12) {
			Button { value.isComplete.toggle() } label: {
				Image(systemName: value.isComplete ? "checkmark.circle.fill" : "circle")
					.font(.title3)
					.foregroundStyle(value.isComplete ? .green : .secondary)
					.frame(width: 44, height: 44)
			}
			.buttonStyle(.plain)
			.accessibilityLabel("Set \(value.setNumber), \(value.isComplete ? "completed" : "not completed")")
			Text("\(value.setNumber)").font(.caption).foregroundStyle(.secondary)
			input("kg", text: $value.weight, keyboard: .decimalPad)
			input("reps", text: $value.reps, keyboard: .numberPad)
			input("RIR", text: $value.rir, keyboard: .decimalPad)
		}
	}

	private func input(_ unit: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
		VStack(alignment: .trailing, spacing: 2) {
			Text(unit).font(.caption2).foregroundStyle(.secondary)
			TextField("—", text: text)
				.keyboardType(keyboard)
				.multilineTextAlignment(.trailing)
				.monospacedDigit()
				.accessibilityLabel("\(value.exerciseName), set \(value.setNumber), \(unit)")
		}
		.frame(maxWidth: .infinity)
	}
}
