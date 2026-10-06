import AVKit
import SwiftUI

struct TrainingPlanView: View {
	@Environment(AppStore.self) private var store
	@State private var selectedTemplate: WorkoutTemplate?
	@State private var showingWorkout = false
	@State private var showingPlanEditor = false

	private var nextTemplate: WorkoutTemplate {
		store.launchWorkout.template
	}

	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(alignment: .leading, spacing: CutLogStyle.Space.xl) {
					SectionLabel("Plan") {
						Button("Edit") { showingPlanEditor = true }
							.font(.subheadline.weight(.medium))
					}

					NextWorkoutCard(template: nextTemplate, date: store.launchWorkout.date, isDue: store.workoutIsDue, isResuming: !store.unfinishedWorkouts.isEmpty) {
						showingWorkout = true
					} onOpen: {
						selectedTemplate = nextTemplate
					}

					VStack(alignment: .leading, spacing: CutLogStyle.Space.s) {
						SectionLabel("This week")
						HStack(spacing: CutLogStyle.Space.s) {
							ForEach(WorkoutSchedule.weeklySchedule) { scheduled in
								if let template = store.template(for: scheduled.templateID) {
									WeekCell(scheduled: scheduled, template: template,
									         isToday: scheduled.weekday == Calendar.current.component(.weekday, from: .now),
									         isDone: isCompleted(scheduled)) { selectedTemplate = template }
								}
							}
						}
					}

					DisclosureGroup {
						Text("Start around 2,400–2,500 kcal and 180–210 g protein. Judge weight from the 7-day average, not one weird Tuesday. If the 14-day trend stalls, add 1,500–2,000 steps first; then cut 100–150 kcal.")
							.font(.subheadline)
							.foregroundStyle(.secondary)
				 } label: {
						Text("Keep the cut boring")
							.font(.headline)
					}
				}
				.padding(.horizontal, CutLogStyle.Space.l)
				.padding(.vertical, CutLogStyle.Space.l)
			}
			.toolbar(.hidden, for: .navigationBar)
			.sheet(isPresented: $showingWorkout) {
				if store.unfinishedWorkouts.isEmpty && store.workoutIsDue {
					WorkoutView(template: store.launchWorkout.template)
				} else {
					WorkoutLaunchView()
				}
			}
			.sheet(item: $selectedTemplate) { template in
				WorkoutDetailView(template: template)
			}
			.sheet(isPresented: $showingPlanEditor) {
				PlanEditorView()
			}
		}
	}

	/// A scheduled day is done when that exact template was completed on that exact weekday.
	private func isCompleted(_ scheduled: ScheduledWorkout) -> Bool {
		store.workouts.contains { workout in
			workout.templateID == scheduled.templateID
				&& workout.completedSetCount > 0
				&& Calendar.current.component(.weekday, from: workout.startedAt ?? workout.completedAt) == scheduled.weekday
		}
	}
}

/// Training is the point of the app, so the session leads the tab. Two independent targets:
/// the button starts the session, the rest of the card opens the detail.
private struct NextWorkoutCard: View {
	let template: WorkoutTemplate
	let date: Date
	let isDue: Bool
	let isResuming: Bool
	let start: () -> Void
	let onOpen: () -> Void

	private var whenLabel: String {
		if isResuming { return "Choose session" }
		return Calendar.current.isDateInToday(date) ? "Today" : date.formatted(.dateTime.weekday(.wide))
	}

	var body: some View {
		Card(padding: CutLogStyle.Space.l) {
			VStack(alignment: .leading, spacing: CutLogStyle.Space.m) {
				Button(action: onOpen) {
					VStack(alignment: .leading, spacing: CutLogStyle.Space.s) {
						SectionLabel(whenLabel) {
							Image(systemName: "chevron.right")
								.font(.caption.weight(.semibold))
								.foregroundStyle(.tertiary)
						}
						Text(template.title)
							.font(.title2.weight(.bold))
							.foregroundStyle(.primary)
						Text(template.subtitle)
							.foregroundStyle(.secondary)
						HStack(spacing: CutLogStyle.Space.l) {
							Label("~\(template.estimatedMinutes) min", systemImage: "clock")
							Label("\(template.exercises.count) exercises", systemImage: "dumbbell")
						}
						.font(CutLogStyle.Number.label)
						.foregroundStyle(.secondary)
					}
					.frame(maxWidth: .infinity, alignment: .leading)
					.contentShape(Rectangle())
				}
				.buttonStyle(.plain)

				Button(action: start) {
					Text(isResuming ? "Choose session" : "Start \(template.title)")
						.font(.headline)
						.frame(maxWidth: .infinity, minHeight: 48)
				}
				.buttonStyle(.borderedProminent)
				.tint(isDue || isResuming ? CutLogPalette.sage : CutLogPalette.apricot)
				.accessibilityHint("Opens the workout.")
			}
		}
	}
}

/// The whole week visible without scrolling: four compact day cells.
private struct WeekCell: View {
	let scheduled: ScheduledWorkout
	let template: WorkoutTemplate
	let isToday: Bool
	let isDone: Bool
	let action: () -> Void

	private var initial: String {
		String(template.title.prefix(1))
	}

	var body: some View {
		Button(action: action) {
			VStack(spacing: CutLogStyle.Space.xs) {
				Text(scheduled.shortDay)
					.font(CutLogStyle.Number.label)
					.foregroundStyle(.secondary)
				Text(initial)
					.font(.headline)
					.foregroundStyle(isToday ? CutLogPalette.sage : .primary)
					.frame(width: 34, height: 34)
					.background(isDone ? CutLogPalette.sage.opacity(0.18) : CutLogPalette.surface,
					            in: Circle())
					.overlay {
						Circle().strokeBorder(isToday ? CutLogPalette.sage.opacity(0.5) : CutLogPalette.hairline,
						                      lineWidth: isToday ? 1 : 0.5)
					}
				Circle()
					.fill(isDone ? CutLogPalette.sage : Color.clear)
					.frame(width: 4, height: 4)
			}
			.frame(maxWidth: .infinity)
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
		.accessibilityLabel("\(scheduled.shortDay), \(template.title)\(isDone ? ", completed" : (isToday ? ", today" : ""))")
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
.foregroundStyle(CutLogPalette.sage)
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
