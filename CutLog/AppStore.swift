import Foundation
import Observation

@MainActor
@Observable
final class AppStore {
	var foods: [FoodEntry] { didSet { save(foods, key: Keys.foods); refreshWidget() } }
	var pinnedFoods: [FoodEntry] { didSet { save(pinnedFoods, key: Keys.pinnedFoods) } }
	var weights: [WeightEntry] { didSet { save(weights, key: Keys.weights) } }
	var workouts: [WorkoutEntry] { didSet { save(workouts, key: Keys.workouts) } }
	var settings: AppSettings { didSet { save(settings, key: Keys.settings); refreshWidget() } }
	var trainingPlan: TrainingPlan { didSet { save(trainingPlan, key: Keys.trainingPlan) } }
	private(set) var activeWorkout: WorkoutDraft? { didSet { save(activeWorkout, key: Keys.activeWorkout) } }
	var healthSyncError: String?
	private let defaults: UserDefaults
	private let sideEffectsEnabled: Bool

	private enum Keys {
		static let foods = "foods"
		static let pinnedFoods = "pinned-foods-v1"
		static let weights = "weights"
		static let workouts = "workouts"
		static let settings = "settings"
		static let trainingPlan = "training-plan-v2"
		static let activeWorkout = "active-workout-v1"
	}

	// An injected suite isolates both storage and external effects in tests.
	init(defaults: UserDefaults? = nil) {
		let storage = defaults ?? .standard
		self.defaults = storage
		sideEffectsEnabled = defaults == nil
		foods = Self.load([FoodEntry].self, key: Keys.foods, defaults: storage) ?? []
		pinnedFoods = Self.load([FoodEntry].self, key: Keys.pinnedFoods, defaults: storage) ?? []
		weights = Self.load([WeightEntry].self, key: Keys.weights, defaults: storage) ?? []
		workouts = Self.load([WorkoutEntry].self, key: Keys.workouts, defaults: storage) ?? []
		settings = Self.load(AppSettings.self, key: Keys.settings, defaults: storage) ?? AppSettings()
		Self.migrateLegacyExerciseDBKey(in: storage, sideEffectsEnabled: defaults == nil)
		let savedPlan = Self.load(TrainingPlan.self, key: Keys.trainingPlan, defaults: storage) ?? .default
		trainingPlan = Self.upgradeTrainingPlan(savedPlan)
		activeWorkout = Self.load(WorkoutDraft.self, key: Keys.activeWorkout, defaults: storage)
		// Recover an interrupted finish without creating a second history entry.
		if let draft = activeWorkout, workouts.contains(where: { $0.id == draft.id }) { activeWorkout = nil }
		refreshWidget()
	}

	func refreshWidget() {
		guard sideEffectsEnabled else { return }
		WidgetSnapshot.write(from: self)
	}

	var todayFoods: [FoodEntry] {
		foods.filter { Calendar.current.isDateInToday($0.date) }.sorted { $0.date > $1.date }
	}

	var quickLogFoods: [FoodEntry] { pinnedFoods }

	var recentFoods: [FoodEntry] {
		var seen = Set<String>()
		return foods.sorted { $0.date > $1.date }.filter { entry in
			let key = foodKey(for: entry)
			return !isPinned(entry) && seen.insert(key).inserted
		}.prefix(8).map { $0 }
	}

	func isPinned(_ food: FoodEntry) -> Bool {
		pinnedFoods.contains { foodKey(for: $0) == foodKey(for: food) }
	}

	func togglePinned(_ food: FoodEntry) {
		let key = foodKey(for: food)
		if let index = pinnedFoods.firstIndex(where: { foodKey(for: $0) == key }) {
			pinnedFoods.remove(at: index)
		} else {
			pinnedFoods.append(food)
		}
	}

	private func foodKey(for food: FoodEntry) -> String {
		let barcode = food.barcode ?? ""
		return "\(food.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())|\(food.calories)|\(food.protein)|\(food.carbs)|\(food.fat)|\(food.servingGrams ?? 0)|\(barcode)"
	}

	var todayTotals: DailyTotals {
		todayFoods.reduce(into: DailyTotals()) { totals, food in
			totals.calories += food.calories
			totals.protein += food.protein
			totals.carbs += food.carbs
			totals.fat += food.fat
		}
	}

	var nextScheduledWorkout: (workout: ScheduledWorkout, date: Date) {
		let today = Date.now
		let start = WorkoutSchedule.scheduledWorkout(on: today) != nil && !workoutIsDue
			? Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today : today
		return WorkoutSchedule.nextScheduledWorkout(from: start)
	}

	var nextWorkout: WorkoutTemplate {
		if let draft = activeWorkout { return draft.template }
		return template(for: nextScheduledWorkout.workout.templateID) ?? trainingPlan.templates.first ?? .upperA
	}

	var workoutIsDue: Bool { WorkoutSchedule.isDue(workouts: workouts) }
	var latestWeight: WeightEntry? { weights.max(by: { $0.date < $1.date }) }

	// Seven calendar days of smoothing, not seven points of display history.
	var sevenDayWeightTrend: [WeightTrendPoint] {
		let calendar = Calendar.current
		let dailyWeights = Dictionary(grouping: weights.filter { $0.kilograms.isFinite && $0.kilograms > 0 }) { calendar.startOfDay(for: $0.date) }
			.compactMap { day, entries in entries.max(by: { $0.date < $1.date }).map { (day, $0.kilograms) } }
			.sorted { $0.0 < $1.0 }
		return dailyWeights.compactMap { day, _ in
			guard let start = calendar.date(byAdding: .day, value: -6, to: day) else { return nil }
			let values = dailyWeights.filter { $0.0 >= start && $0.0 <= day }.map(\.1)
			return WeightTrendPoint(date: day, kilograms: values.reduce(0, +) / Double(values.count))
		}
	}

	func weightTrend(days: Int?, endingAt date: Date = .now, calendar: Calendar = .current) -> [WeightTrendPoint] {
		let end = calendar.startOfDay(for: date)
		let start = days.flatMap { calendar.date(byAdding: .day, value: -(max(1, $0) - 1), to: end) } ?? .distantPast
		return sevenDayWeightTrend.filter { $0.date >= start && $0.date <= end }
	}

	var latestSevenDayAverage: Double? { sevenDayWeightTrend.last?.kilograms }

	func template(for id: String) -> WorkoutTemplate? { trainingPlan.templates.first { $0.id == id } }

	func updateTemplate(_ template: WorkoutTemplate) {
		guard let index = trainingPlan.templates.firstIndex(where: { $0.id == template.id }) else { return }
		trainingPlan.templates[index] = template
	}

	func resetTrainingPlan() { trainingPlan = .default }

	private static func migrateLegacyExerciseDBKey(in defaults: UserDefaults, sideEffectsEnabled: Bool) {
		guard sideEffectsEnabled,
			let data = defaults.data(forKey: Keys.settings),
			var legacy = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
			let key = legacy["exerciseDBAPIKey"] as? String,
			!key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
		if KeychainStore.exerciseDBKey().isEmpty { KeychainStore.setExerciseDBKey(key) }
		legacy.removeValue(forKey: "exerciseDBAPIKey")
		if let cleaned = try? JSONSerialization.data(withJSONObject: legacy) {
			defaults.set(cleaned, forKey: Keys.settings)
		}
	}

	private static func upgradeTrainingPlan(_ plan: TrainingPlan) -> TrainingPlan {
		let defaultsByTemplate = Dictionary(uniqueKeysWithValues: TrainingPlan.default.templates.map { ($0.id, $0) })
		let upgradedTemplates = plan.templates.map { template in
			guard let defaultTemplate = defaultsByTemplate[template.id] else { return template }
			let defaultExercises = Dictionary(uniqueKeysWithValues: defaultTemplate.exercises.map { ($0.name, $0) })
			var exercises = template.exercises.map { existing in
				guard let defaultExercise = defaultExercises[existing.name] else { return existing }
				var exercise = existing
				if exercise.matAlternative.isEmpty { exercise.matAlternative = defaultExercise.matAlternative }
				if exercise.exerciseDBQuery.isEmpty { exercise.exerciseDBQuery = defaultExercise.exerciseDBQuery }
				return exercise
			}
			for exercise in defaultTemplate.exercises where !exercises.contains(where: { $0.name == exercise.name }) {
				exercises.append(exercise)
			}
			var result = template
			result.exercises = exercises
			return result
		}
		return TrainingPlan(templates: upgradedTemplates)
	}

	func lastPerformance(for exerciseName: String) -> LoggedSet? {
		workouts.sorted { $0.completedAt > $1.completedAt }.lazy.flatMap(\.sets).first { $0.exerciseName == exerciseName }
	}

	func beginWorkout(_ template: WorkoutTemplate) {
		guard activeWorkout == nil else { return }
		activeWorkout = WorkoutDraft(template: template)
	}

	func updateWorkoutSet(_ value: WorkoutSetDraft) {
		guard let index = activeWorkout?.sets.firstIndex(where: { $0.id == value.id }) else { return }
		activeWorkout?.sets[index] = value
	}

	@discardableResult
	func finishWorkout() -> WorkoutEntry? {
		guard let draft = activeWorkout else { return nil }
		let workout = WorkoutEntry(id: draft.id, templateID: draft.template.id, sets: draft.loggedSets,
			startedAt: draft.startedAt, templateTitle: draft.template.title, setRecords: draft.sets)
		if !workouts.contains(where: { $0.id == draft.id }) { workouts.append(workout) }
		activeWorkout = nil
		if sideEffectsEnabled && settings.healthSyncEnabled {
			Task {
				do { try await HealthKitStore.shared.save(workout: workout) }
				catch { healthSyncError = HealthKitStore.message(for: error) }
			}
		}
		return workout
	}

	func addFood(_ food: FoodEntry) {
		foods.append(food)
		guard sideEffectsEnabled && settings.healthSyncEnabled else { return }
		Task {
			do { try await HealthKitStore.shared.save(food: food) }
			catch { healthSyncError = HealthKitStore.message(for: error) }
		}
	}

	func deleteFood(_ food: FoodEntry) { foods.removeAll { $0.id == food.id } }

	func addWeight(_ kilograms: Double) {
		let entry = WeightEntry(kilograms: kilograms)
		weights.append(entry)
		guard sideEffectsEnabled && settings.healthSyncEnabled else { return }
		Task {
			do { try await HealthKitStore.shared.save(weight: entry) }
			catch { healthSyncError = HealthKitStore.message(for: error) }
		}
	}

	func importLatestHealthWeight() async {
		guard sideEffectsEnabled && settings.healthSyncEnabled else { return }
		do {
			guard let entry = try await HealthKitStore.shared.latestWeight(),
				!weights.contains(where: { $0.date == entry.date && abs($0.kilograms - entry.kilograms) < 0.001 }) else { return }
			weights.append(entry)
		} catch { healthSyncError = HealthKitStore.message(for: error) }
	}

	private func save<T: Encodable>(_ value: T, key: String) {
		guard let data = try? JSONEncoder().encode(value) else { return }
		defaults.set(data, forKey: key)
	}

	private static func load<T: Decodable>(_ type: T.Type, key: String, defaults: UserDefaults) -> T? {
		guard let data = defaults.data(forKey: key) else { return nil }
		return try? JSONDecoder().decode(type, from: data)
	}
}
