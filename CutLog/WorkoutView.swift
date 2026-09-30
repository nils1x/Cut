import SwiftUI

struct WorkoutLaunchView: View {
	@Environment(AppStore.self) private var store
	@Environment(\.dismiss) private var dismiss
	@State private var selectedTemplate: WorkoutTemplate?

	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(alignment: .leading, spacing: 20) {
					if !store.unfinishedWorkouts.isEmpty {
						Text("Continue a saved session or start the scheduled one. Nothing gets deleted.")
							.font(.subheadline).foregroundStyle(.secondary)
						ForEach(store.unfinishedWorkouts) { draft in
							Button {
								store.resumeWorkout(draft.id)
								selectedTemplate = store.activeWorkout?.template
							} label: {
								choice(title: "Continue · \(draft.startedAt.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))", template: draft.template,
									footer: "\(draft.completedSetCount) of \(draft.sets.count) sets checked", symbol: "arrow.counterclockwise")
							}
							.buttonStyle(.plain)
						}
					}
					Button {
						let scheduled = store.launchWorkout
						store.startScheduledWorkout(scheduled.template)
						selectedTemplate = scheduled.template
					} label: {
						choice(title: Calendar.current.isDateInToday(store.launchWorkout.date) ? "Start today's workout" : "Start next plan early · \(store.launchWorkout.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))",
							template: store.launchWorkout.template, footer: "Starts a new session today if none is saved for today", symbol: "play.fill")
					}
					.buttonStyle(.plain)
				}
				.padding()
			}
			.navigationTitle("Choose workout")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
			.sheet(item: $selectedTemplate, onDismiss: { dismiss() }) { WorkoutView(template: $0) }
		}
	}

	private func choice(title: String, template: WorkoutTemplate, footer: String, symbol: String) -> some View {
		HStack(alignment: .top, spacing: 12) {
			Image(systemName: symbol).foregroundStyle(CutLogStyle.accent).frame(width: 24)
			VStack(alignment: .leading, spacing: 6) {
				Text(title).font(.caption.weight(.semibold)).foregroundStyle(CutLogStyle.accent)
				Text(template.title).font(.headline).foregroundStyle(.primary)
				Text(template.subtitle).font(.subheadline).foregroundStyle(.secondary)
				Text(footer).font(.caption).foregroundStyle(.secondary)
			}
			Spacer(minLength: 0)
			Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
		}
		.frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
		.padding(16)
		.background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
		.contentShape(Rectangle())
	}
}

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
