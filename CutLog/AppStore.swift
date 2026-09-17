import Foundation
import Observation

@Observable
final class AppStore {
	var foods: [FoodEntry] { didSet { save(foods, key: Keys.foods); WidgetSnapshot.write(from: self) } }
	var weights: [WeightEntry] { didSet { save(weights, key: Keys.weights); WidgetSnapshot.write(from: self) } }
	var workouts: [WorkoutEntry] { didSet { save(workouts, key: Keys.workouts); WidgetSnapshot.write(from: self) } }
	var settings: AppSettings { didSet { save(settings, key: Keys.settings); WidgetSnapshot.write(from: self) } }
	var trainingPlan: TrainingPlan { didSet { save(trainingPlan, key: Keys.trainingPlan) } }

	private enum Keys {
		static let foods = "foods"
		static let weights = "weights"
		static let workouts = "workouts"
		static let settings = "settings"
		static let trainingPlan = "training-plan-v2"
	}

	init(defaults: UserDefaults = .standard) {
		foods = Self.load([FoodEntry].self, key: Keys.foods, defaults: defaults) ?? []
		weights = Self.load([WeightEntry].self, key: Keys.weights, defaults: defaults) ?? []
		workouts = Self.load([WorkoutEntry].self, key: Keys.workouts, defaults: defaults) ?? []
		settings = Self.load(AppSettings.self, key: Keys.settings, defaults: defaults) ?? AppSettings()
		trainingPlan = Self.load(TrainingPlan.self, key: Keys.trainingPlan, defaults: defaults) ?? .default
		WidgetSnapshot.write(from: self)
	}

	var todayFoods: [FoodEntry] {
		foods.filter { Calendar.current.isDateInToday($0.date) }.sorted { $0.date > $1.date }
	}

	var recentFoods: [FoodEntry] {
		var seen = Set<String>()
		return foods.sorted { $0.date > $1.date }.filter { entry in
			let key = "\(entry.name.lowercased())|\(entry.calories)|\(entry.protein)|\(entry.carbs)|\(entry.fat)"
			return seen.insert(key).inserted
		}.prefix(8).map { $0 }
	}

	var todayTotals: DailyTotals {
		todayFoods.reduce(into: DailyTotals()) { totals, food in
			totals.calories += food.calories
			totals.protein += food.protein
			totals.carbs += food.carbs
			totals.fat += food.fat
		}
	}

	var nextWorkout: WorkoutTemplate {
		let scheduled = WorkoutSchedule.nextScheduledWorkout().workout
		return template(for: scheduled.templateID) ?? trainingPlan.templates.first ?? .upperA
	}

	var workoutIsDue: Bool { WorkoutSchedule.isDue(workouts: workouts) }
	var latestWeight: WeightEntry? { weights.max(by: { $0.date < $1.date }) }

	var recentWeights: [WeightEntry] {
		weights.sorted { $0.date < $1.date }.suffix(7).map { $0 }
	}

	var sevenDayWeightTrend: [WeightTrendPoint] {
		let calendar = Calendar.current
		let dailyWeights = Dictionary(grouping: weights) { calendar.startOfDay(for: $0.date) }
			.compactMap { day, entries in entries.max(by: { $0.date < $1.date }).map { (day, $0.kilograms) } }
			.sorted { $0.0 < $1.0 }

		return dailyWeights.compactMap { day, _ in
			guard let start = calendar.date(byAdding: .day, value: -6, to: day) else { return nil }
			let values = dailyWeights.filter { $0.0 >= start && $0.0 <= day }.map(\.1)
			guard !values.isEmpty else { return nil }
			return WeightTrendPoint(date: day, kilograms: values.reduce(0, +) / Double(values.count))
		}.suffix(7).map { $0 }
	}

	var latestSevenDayAverage: Double? { sevenDayWeightTrend.last?.kilograms }

	func template(for id: String) -> WorkoutTemplate? {
		trainingPlan.templates.first { $0.id == id }
	}

	func updateTemplate(_ template: WorkoutTemplate) {
		guard let index = trainingPlan.templates.firstIndex(where: { $0.id == template.id }) else { return }
		trainingPlan.templates[index] = template
	}

	func resetTrainingPlan() {
		trainingPlan = .default
	}

	func lastPerformance(for exerciseName: String) -> LoggedSet? {
		workouts.sorted { $0.completedAt > $1.completedAt }
			.lazy
			.flatMap(\.sets)
			.first { $0.exerciseName == exerciseName }
	}

	func addFood(_ food: FoodEntry) {
		foods.append(food)
		let isHealthSyncEnabled = settings.healthSyncEnabled
		Task { await HealthKitStore.shared.save(food: food, isEnabled: isHealthSyncEnabled) }
	}

	func deleteFood(_ food: FoodEntry) { foods.removeAll { $0.id == food.id } }

	func addWeight(_ kilograms: Double) {
		let entry = WeightEntry(kilograms: kilograms)
		weights.append(entry)
		let isHealthSyncEnabled = settings.healthSyncEnabled
		Task { await HealthKitStore.shared.save(weight: entry, isEnabled: isHealthSyncEnabled) }
	}

	func completeWorkout(templateID: String, sets: [LoggedSet]) {
		let workout = WorkoutEntry(templateID: templateID, sets: sets)
		workouts.append(workout)
		let isHealthSyncEnabled = settings.healthSyncEnabled
		Task { await HealthKitStore.shared.save(workout: workout, isEnabled: isHealthSyncEnabled) }
	}

	@MainActor
	func importLatestHealthWeight() async {
		guard settings.healthSyncEnabled, let entry = await HealthKitStore.shared.latestWeight() else { return }
		guard latestWeight?.date != entry.date else { return }
		weights.append(entry)
	}

	private func save<T: Encodable>(_ value: T, key: String) {
		guard let data = try? JSONEncoder().encode(value) else { return }
		UserDefaults.standard.set(data, forKey: key)
	}

	private static func load<T: Decodable>(_ type: T.Type, key: String, defaults: UserDefaults) -> T? {
		guard let data = defaults.data(forKey: key) else { return nil }
		return try? JSONDecoder().decode(type, from: data)
	}
}
