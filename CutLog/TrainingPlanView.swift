import AVKit
import SwiftUI

struct TrainingPlanView: View {
	@Environment(AppStore.self) private var store
	@State private var selectedTemplate: WorkoutTemplate?
	@State private var showingWorkout = false
	@State private var showingPlanEditor = false

	private var nextScheduled: (workout: ScheduledWorkout, date: Date) {
		store.nextScheduledWorkout
	}

	private var nextTemplate: WorkoutTemplate {
		store.nextWorkout
	}

	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(alignment: .leading, spacing: 16) {
					Button { showingWorkout = true } label: {
						NextWorkoutCard(template: nextTemplate, date: nextScheduled.date, isDue: store.workoutIsDue, isResuming: store.activeWorkout != nil)
					}
					.buttonStyle(.plain)

					VStack(alignment: .leading, spacing: 8) {
						Text("This week")
							.font(.headline)
						ForEach(WorkoutSchedule.weeklySchedule) { scheduled in
							if let template = store.template(for: scheduled.templateID) {
								Button { selectedTemplate = template } label: {
									WeekRow(scheduled: scheduled, template: template, isToday: scheduled.weekday == Calendar.current.component(.weekday, from: .now), isDone: scheduled.weekday == Calendar.current.component(.weekday, from: .now) && !store.workoutIsDue)
								}
								.buttonStyle(.plain)
							}
						}
					}
					.padding(16)
					.background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

					PlanRuleCard()
				}
				.padding()
			}
			.navigationTitle("Plan")
			.toolbar {
				ToolbarItem(placement: .primaryAction) {
					Button("Edit") { showingPlanEditor = true }
				}
			}
			.sheet(isPresented: $showingWorkout) {
				WorkoutView(template: nextTemplate)
			}
			.sheet(item: $selectedTemplate) { template in
				WorkoutDetailView(template: template)
			}
			.sheet(isPresented: $showingPlanEditor) {
				PlanEditorView()
			}
		}
	}
}

private struct NextWorkoutCard: View {
	let template: WorkoutTemplate
	let date: Date
	let isDue: Bool
	let isResuming: Bool

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			HStack {
				Label(isResuming ? "Resume session" : (isDue ? "Today" : date.formatted(.dateTime.weekday(.wide))), systemImage: "figure.strengthtraining.traditional")
					.font(.subheadline.weight(.semibold))
					.foregroundStyle(.orange)
				Spacer()
				Image(systemName: "arrow.right.circle.fill")
					.font(.title3)
					.foregroundStyle(.orange)
			}
			Text(template.title)
				.font(.title2.weight(.bold))
			Text(template.subtitle)
				.foregroundStyle(.secondary)
			HStack(spacing: 14) {
				Label("~\(template.estimatedMinutes) min", systemImage: "clock")
				Label("\(template.exercises.count) exercises", systemImage: "dumbbell")
			}
			.font(.caption.weight(.medium))
			.foregroundStyle(.secondary)
		}
		.padding(20)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
	}
}

private struct WeekRow: View {
	let scheduled: ScheduledWorkout
	let template: WorkoutTemplate
	let isToday: Bool
	let isDone: Bool

	var body: some View {
		HStack(spacing: 12) {
			Text(scheduled.shortDay)
				.font(.caption.weight(.bold))
				.foregroundStyle(isToday ? .orange : .secondary)
				.frame(width: 32, alignment: .leading)
			VStack(alignment: .leading, spacing: 2) {
				Text(template.title).foregroundStyle(.primary)
				Text(template.subtitle).font(.caption).foregroundStyle(.secondary)
			}
			Spacer()
			if isToday {
				Image(systemName: isDone ? "checkmark.circle.fill" : "circle.fill")
					.foregroundStyle(isDone ? .green : .orange)
			} else {
				Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
			}
		}
		.padding(.vertical, 7)
	}
}

private struct PlanRuleCard: View {
	var body: some View {
		VStack(alignment: .leading, spacing: 9) {
			Label("Keep the cut boring", systemImage: "chart.line.downtrend.xyaxis")
				.font(.headline)
			Text("Start around 2,400–2,500 kcal and 180–210 g protein. Judge weight from the 7-day average, not one weird Tuesday. If the 14-day trend stalls, add 1,500–2,000 steps first; then cut 100–150 kcal.")
				.font(.subheadline)
				.foregroundStyle(.secondary)
		}
		.padding(16)
		.background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
	}
}

private struct WorkoutDetailView: View {
	@Environment(\.dismiss) private var dismiss
	let template: WorkoutTemplate
	@State private var selectedExercise: Exercise?

	var body: some View {
		NavigationStack {
			List {
				Section {
					Label("~\(template.estimatedMinutes) min strength", systemImage: "clock")
					Label(template.cardioRecommendation, systemImage: "figure.walk")
					Label(template.saunaNote, systemImage: "drop")
						.foregroundStyle(.secondary)
				} header: {
					Text("Session")
				}

				Section("Exercises") {
					ForEach(template.exercises) { exercise in
						Button { selectedExercise = exercise } label: {
							HStack {
								VStack(alignment: .leading, spacing: 3) {
									Text(exercise.name).foregroundStyle(.primary)
									Text("\(exercise.sets) × \(exercise.reps) · RIR \(exercise.rirTarget)")
										.font(.caption).foregroundStyle(.secondary)
								}
								Spacer()
								Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
							}
						}
						.buttonStyle(.plain)
					}
				}
			}
			.navigationTitle(template.title)
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
			}
			.sheet(item: $selectedExercise) { ExerciseDetailView(exercise: $0) }
		}
	}
}

private struct ExerciseDetailView: View {
	@Environment(\.dismiss) private var dismiss
	let exercise: Exercise
	@State private var tutorial: ExerciseDBExercise?
	@State private var tutorialError: String?
	@State private var isLoadingTutorial = false
	@State private var showingVideo = false

	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(alignment: .leading, spacing: 20) {
					Text(exercise.muscleGroup.uppercased())
						.font(.caption.weight(.bold))
						.foregroundStyle(.orange)
					Text(exercise.name).font(.title2.weight(.bold))
					HStack(spacing: 8) {
						Pill("\(exercise.sets) sets", "number")
						Pill("\(exercise.reps) reps", "repeat")
						Pill("RIR \(exercise.rirTarget)", "gauge.with.dots.needle.50percent")
						Pill("\(exercise.restSeconds)s", "timer")
					}

					TutorialSection(
						tutorial: tutorial,
						error: tutorialError,
						isLoading: isLoadingTutorial,
						onLoad: loadTutorial,
						onPlay: { showingVideo = true }
					)

					DetailSection(title: "Purpose", text: exercise.purpose)
					DetailSection(title: "Cue", text: exercise.howTo)
					DetailSection(title: "Mat-only alternative", text: exercise.matAlternative.isEmpty ? "No mat-only alternative added yet." : exercise.matAlternative)
					DetailSection(title: "Progress", text: exercise.progressionNote)
					if !exercise.alternatives.isEmpty {
						DetailSection(title: "If it is taken", text: exercise.alternatives.joined(separator: " · "))
					}
				}
				.padding()
			}
			.navigationTitle("Exercise")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
			.sheet(isPresented: $showingVideo) {
				if let url = tutorial?.videoURL {
					TutorialVideoView(url: url)
				}
			}
		}
	}

	private func loadTutorial() {
		guard !isLoadingTutorial else { return }
		isLoadingTutorial = true
		tutorialError = nil
		Task {
			do {
				let result = try await ExerciseDBService.shared.tutorial(
					for: exercise.exerciseDBQuery.isEmpty ? exercise.name : exercise.exerciseDBQuery,
					apiKey: KeychainStore.exerciseDBKey()
				)
				await MainActor.run {
					tutorial = result
					isLoadingTutorial = false
				}
			} catch {
				await MainActor.run {
					tutorialError = error.localizedDescription
					isLoadingTutorial = false
				}
			}
		}
	}
}

private struct TutorialSection: View {
	let tutorial: ExerciseDBExercise?
	let error: String?
	let isLoading: Bool
	let onLoad: () -> Void
	let onPlay: () -> Void

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			Text("Tutorial").font(.headline)
			if let tutorial {
				if let imageURL = tutorial.preferredImageURL {
					AsyncImage(url: imageURL) { phase in
						switch phase {
						case .success(let image):
							image.resizable().scaledToFill()
						default:
							RoundedRectangle(cornerRadius: 16, style: .continuous)
								.fill(.secondary.opacity(0.1))
								.overlay { ProgressView() }
						}
					}
					.frame(height: 210)
					.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
				}
				if !tutorial.targetMuscles.isEmpty {
					DetailSection(title: "Targets", text: tutorial.targetMuscles.map { $0.capitalized }.joined(separator: " · "))
				}
				if let overview = tutorial.overview, !overview.isEmpty {
					DetailSection(title: "About", text: overview)
				}
				if !tutorial.instructions.isEmpty {
					VStack(alignment: .leading, spacing: 7) {
						Text("How to do it").font(.headline)
						ForEach(Array(tutorial.instructions.enumerated()), id: \.offset) { index, instruction in
							Label(instruction, systemImage: "\(index + 1).circle.fill")
									.font(.subheadline)
									.foregroundStyle(.secondary)
						}
					}
				}
				if tutorial.videoURL != nil {
					Button(action: onPlay) {
						Label("Watch form video", systemImage: "play.rectangle.fill")
							.frame(maxWidth: .infinity)
					}
					.buttonStyle(.borderedProminent)
				}
			} else if isLoading {
				HStack(spacing: 10) { ProgressView(); Text("Loading ExerciseDB tutorial…").foregroundStyle(.secondary) }
			} else {
				Text(error ?? "Load a photo, form cues, and a video tutorial on demand.")
					.font(.subheadline)
					.foregroundStyle(error == nil ? Color.secondary : Color.red)
				Button("Load tutorial", action: onLoad).buttonStyle(.bordered)
			}
		}
		.padding(16)
		.background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
	}
}

private struct TutorialVideoView: View {
	@Environment(\.dismiss) private var dismiss
	let url: URL

	var body: some View {
		NavigationStack {
			VideoPlayer(player: AVPlayer(url: url))
				.navigationTitle("Form video")
				.navigationBarTitleDisplayMode(.inline)
				.toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
		}
	}
}

private struct Pill: View {
	let text: String
	let symbol: String
	init(_ text: String, _ symbol: String) { self.text = text; self.symbol = symbol }
	var body: some View {
		Label(text, systemImage: symbol)
			.font(.caption.weight(.semibold))
			.padding(.horizontal, 9).padding(.vertical, 7)
			.background(.secondary.opacity(0.1), in: Capsule())
	}
}

private struct DetailSection: View {
	let title: String
	let text: String
	var body: some View {
		VStack(alignment: .leading, spacing: 6) {
			Text(title).font(.headline)
			Text(text).foregroundStyle(.secondary)
		}
	}
}

private struct PlanEditorView: View {
	@Environment(AppStore.self) private var store
	@Environment(\.dismiss) private var dismiss
	@State private var selectedTemplate: WorkoutTemplate?

	var body: some View {
		NavigationStack {
			List {
				Section("Your editable template") {
					ForEach(store.trainingPlan.templates) { template in
						Button { selectedTemplate = template } label: {
							HStack {
								VStack(alignment: .leading) {
									Text(template.title).foregroundStyle(.primary)
									Text("\(template.exercises.count) exercises").font(.caption).foregroundStyle(.secondary)
								}
								Spacer()
								Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
							}
						}
						.buttonStyle(.plain)
					}
				}
				Section {
					Button("Restore default plan", role: .destructive) { store.resetTrainingPlan() }
				} footer: {
					Text("Edits stay on this iPhone. Restore is useful if experiments turn into spreadsheet cosplay.")
				}
			}
			.navigationTitle("Edit plan")
			.toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
			.sheet(item: $selectedTemplate) { TemplateEditorView(template: $0) }
		}
	}
}

private struct TemplateEditorView: View {
	@Environment(AppStore.self) private var store
	@Environment(\.dismiss) private var dismiss
	@State private var draft: WorkoutTemplate

	init(template: WorkoutTemplate) {
		_draft = State(initialValue: template)
	}

	var body: some View {
		NavigationStack {
			Form {
				Section("Session") {
					TextField("Title", text: $draft.title)
					TextField("Focus", text: $draft.subtitle)
					Stepper("Strength: ~\(draft.estimatedMinutes) min", value: $draft.estimatedMinutes, in: 45...100, step: 5)
					TextField("Cardio recommendation", text: $draft.cardioRecommendation, axis: .vertical)
				}
				Section("Exercises") {
					ForEach($draft.exercises) { $exercise in
						ExerciseEditorRow(exercise: $exercise)
					}
				}
			}
			.navigationTitle(draft.title)
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
				ToolbarItem(placement: .confirmationAction) {
					Button("Save") { store.updateTemplate(draft); dismiss() }
				}
			}
		}
	}
}

private struct ExerciseEditorRow: View {
	@Binding var exercise: Exercise
	var body: some View {
		DisclosureGroup(exercise.name) {
			TextField("Name", text: $exercise.name)
			TextField("Muscle group", text: $exercise.muscleGroup)
			Stepper("Sets: \(exercise.sets)", value: $exercise.sets, in: 1...6)
			TextField("Rep range", text: $exercise.reps)
			TextField("RIR target", text: $exercise.rirTarget)
			Stepper("Rest: \(exercise.restSeconds)s", value: $exercise.restSeconds, in: 30...240, step: 15)
			TextField("Alternatives (separate with commas)", text: Binding(get: { exercise.alternatives.joined(separator: ", ") }, set: { exercise.alternatives = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }))
		}
	}
}
