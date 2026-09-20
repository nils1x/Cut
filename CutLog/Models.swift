import Foundation

struct FoodEntry: Identifiable, Codable, Hashable {
	var id = UUID()
	var name: String
	var calories: Int
	var protein: Int
	var carbs: Int
	var fat: Int
	var servingGrams: Double?
	var barcode: String?
	var date = Date()

	init(id: UUID = UUID(), name: String, calories: Int, protein: Int, carbs: Int, fat: Int, servingGrams: Double? = nil, barcode: String? = nil, date: Date = .now) {
		self.id = id
		self.name = name
		self.calories = calories
		self.protein = protein
		self.carbs = carbs
		self.fat = fat
		self.servingGrams = servingGrams
		self.barcode = barcode
		self.date = date
	}

	private enum CodingKeys: String, CodingKey { case id, name, calories, protein, carbs, fat, servingGrams, barcode, date }

	init(from decoder: Decoder) throws {
		let values = try decoder.container(keyedBy: CodingKeys.self)
		id = try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
		name = try values.decode(String.self, forKey: .name)
		calories = try values.decode(Int.self, forKey: .calories)
		protein = try values.decode(Int.self, forKey: .protein)
		carbs = try values.decode(Int.self, forKey: .carbs)
		fat = try values.decode(Int.self, forKey: .fat)
		servingGrams = try values.decodeIfPresent(Double.self, forKey: .servingGrams)
		barcode = try values.decodeIfPresent(String.self, forKey: .barcode)
		date = try values.decodeIfPresent(Date.self, forKey: .date) ?? .now
	}
}

struct WeightEntry: Identifiable, Codable, Hashable {
	var id = UUID()
	var kilograms: Double
	var date = Date()
}

struct WeightTrendPoint: Identifiable, Hashable {
	let date: Date
	let kilograms: Double
	var id: Date { date }
}

struct Exercise: Identifiable, Codable, Hashable {
	var id = UUID()
	var name: String
	var muscleGroup: String
	var sets: Int
	var reps: String
	var rirTarget: String
	var purpose: String
	var howTo: String
	var restSeconds: Int
	var progressionNote: String
	var alternatives: [String]
	/// Closest deliberate bodyweight substitute; no equipment, furniture, or weights required.
	var matAlternative: String
	/// Stable search wording for ExerciseDB. It is separate from the display name because plans use compound labels.
	var exerciseDBQuery: String

	init(id: UUID = UUID(), name: String, muscleGroup: String = "Strength", sets: Int, reps: String, rirTarget: String = "1–3", purpose: String = "", howTo: String = "", restSeconds: Int = 90, progressionNote: String = "Hit the top of the range in every set with clean form, then add a little weight next time.", alternatives: [String] = [], matAlternative: String = "", exerciseDBQuery: String = "") {
		self.id = id
		self.name = name
		self.muscleGroup = muscleGroup
		self.sets = sets
		self.reps = reps
		self.rirTarget = rirTarget
		self.purpose = purpose
		self.howTo = howTo
		self.restSeconds = restSeconds
		self.progressionNote = progressionNote
		self.alternatives = alternatives
		self.matAlternative = matAlternative
		self.exerciseDBQuery = exerciseDBQuery
	}

	private enum CodingKeys: String, CodingKey { case id, name, muscleGroup, sets, reps, rirTarget, purpose, howTo, restSeconds, progressionNote, alternatives, matAlternative, exerciseDBQuery }

	init(from decoder: Decoder) throws {
		let values = try decoder.container(keyedBy: CodingKeys.self)
		id = try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
		name = try values.decode(String.self, forKey: .name)
		muscleGroup = try values.decodeIfPresent(String.self, forKey: .muscleGroup) ?? "Strength"
		sets = try values.decode(Int.self, forKey: .sets)
		reps = try values.decode(String.self, forKey: .reps)
		rirTarget = try values.decodeIfPresent(String.self, forKey: .rirTarget) ?? "1–3"
		purpose = try values.decodeIfPresent(String.self, forKey: .purpose) ?? ""
		howTo = try values.decodeIfPresent(String.self, forKey: .howTo) ?? ""
		restSeconds = try values.decodeIfPresent(Int.self, forKey: .restSeconds) ?? 90
		progressionNote = try values.decodeIfPresent(String.self, forKey: .progressionNote) ?? "Hit the top of the range in every set with clean form, then add a little weight next time."
		alternatives = try values.decodeIfPresent([String].self, forKey: .alternatives) ?? []
		matAlternative = try values.decodeIfPresent(String.self, forKey: .matAlternative) ?? ""
		exerciseDBQuery = try values.decodeIfPresent(String.self, forKey: .exerciseDBQuery) ?? ""
	}
}

struct WorkoutTemplate: Identifiable, Codable, Hashable {
	var id: String
	var title: String
	var subtitle: String
	var estimatedMinutes: Int
	var cardioRecommendation: String
	var saunaNote: String
	var exercises: [Exercise]

	init(id: String, title: String, subtitle: String, estimatedMinutes: Int = 70, cardioRecommendation: String = "15–25 min Zone 2 after lifting.", saunaNote: String = "Optional recovery. Rehydrate afterwards; it is not fat loss.", exercises: [Exercise]) {
		self.id = id
		self.title = title
		self.subtitle = subtitle
		self.estimatedMinutes = estimatedMinutes
		self.cardioRecommendation = cardioRecommendation
		self.saunaNote = saunaNote
		self.exercises = exercises
	}

	private enum CodingKeys: String, CodingKey { case id, title, subtitle, estimatedMinutes, cardioRecommendation, saunaNote, exercises }

	init(from decoder: Decoder) throws {
		let values = try decoder.container(keyedBy: CodingKeys.self)
		id = try values.decode(String.self, forKey: .id)
		title = try values.decode(String.self, forKey: .title)
		subtitle = try values.decode(String.self, forKey: .subtitle)
		estimatedMinutes = try values.decodeIfPresent(Int.self, forKey: .estimatedMinutes) ?? 70
		cardioRecommendation = try values.decodeIfPresent(String.self, forKey: .cardioRecommendation) ?? "15–25 min Zone 2 after lifting."
		saunaNote = try values.decodeIfPresent(String.self, forKey: .saunaNote) ?? "Optional recovery. Rehydrate afterwards; it is not fat loss."
		exercises = try values.decode([Exercise].self, forKey: .exercises)
	}
}

struct TrainingPlan: Codable, Hashable {
	var templates: [WorkoutTemplate]
	static let `default` = TrainingPlan(templates: [.upperA, .lowerA, .upperB, .lowerB])
}

private func exercise(_ name: String, _ muscles: String, _ sets: Int, _ reps: String, _ rir: String, _ rest: Int, _ purpose: String, _ howTo: String, _ alternatives: [String] = [], mat: String = "", mediaQuery: String = "") -> Exercise {
	Exercise(name: name, muscleGroup: muscles, sets: sets, reps: reps, rirTarget: rir, purpose: purpose, howTo: howTo, restSeconds: rest, alternatives: alternatives, matAlternative: mat, exerciseDBQuery: mediaQuery)
}

extension WorkoutTemplate {
	static let upperA = WorkoutTemplate(
		id: "upper-a", title: "Upper A", subtitle: "Chest · Back · Arms", estimatedMinutes: 70,
		cardioRecommendation: "15–25 min Zone 2 after lifting: incline walk, bike, or cross-trainer.",
		saunaNote: "Optional recovery. Drink and replace electrolytes afterwards.",
		exercises: [
			exercise("Bench Press / Chest Press", "Chest · Triceps", 3, "6–10", "1–2", 150, "Main horizontal press for chest and triceps.", "Set shoulder blades, press smoothly, lower under control.", ["Machine chest press", "Dumbbell bench press"], mat: "Push-up — 3 × 8–20; hands under shoulders, ribs down, chest to mat with control.", mediaQuery: "bench press"),
			exercise("Lat Pulldown", "Lats · Upper back", 3, "8–12", "1–2", 105, "Vertical pull for lats and upper back.", "Drive elbows down toward ribs; never pull behind the neck.", ["Assisted pull-up", "Neutral-grip pulldown"], mat: "Prone lat pull-down — 3 × 12–20; lie face down, pull elbows to ribs and squeeze your back.", mediaQuery: "lat pulldown"),
			exercise("Seated Cable Row", "Mid-back · Lats", 3, "8–12", "1–2", 105, "Balanced horizontal pulling.", "Sit tall, pull to lower ribs, then return without swinging.", ["Chest-supported row", "Machine row"], mat: "Prone W raise — 3 × 12–20; face down, lift elbows into a W and squeeze shoulder blades.", mediaQuery: "seated cable row"),
			exercise("Incline Dumbbell Press", "Upper chest · Shoulders", 2, "8–12", "1–2", 105, "Second press with an upper-chest bias.", "Use a modest incline and control the stretch.", ["Incline chest press"], mat: "Pike push-up — 2 × 6–15; hips high, lower the crown toward the mat, press back.", mediaQuery: "incline dumbbell press"),
			exercise("Cable Lateral Raise", "Side delts", 3, "12–20", "1–2", 75, "Direct side-delt work.", "Raise slowly; stop before traps take over.", ["Dumbbell lateral raise"], mat: "Prone Y raise — 3 × 12–20; face down, lift straight arms in a Y without shrugging.", mediaQuery: "cable lateral raise"),
			exercise("Triceps Pushdown", "Triceps", 2, "10–15", "1–2", 75, "Simple triceps volume after pressing.", "Pin elbows and straighten arms without rocking.", ["Overhead cable extension"], mat: "Close-grip push-up — 2 × 6–15; elbows track back and keep the body rigid.", mediaQuery: "triceps pushdown"),
				exercise("Dumbbell Curl", "Biceps", 2, "10–15", "1–2", 75, "Direct biceps work.", "Keep upper arms quiet and lower slowly.", ["Cable curl", "EZ-bar curl"], mat: "Self-resisted curl — 2 × 10–20 / arm; curl one arm while the other hand supplies smooth resistance.", mediaQuery: "dumbbell curl"),
				exercise("Dead Bug", "Core · Deep abs", 2, "8–12 / side", "2–3", 60, "Anti-extension core control for a stronger brace.", "Keep your low back gently pressed into the mat while extending opposite arm and leg.", mat: "Dead bug — already mat-only. Slow it down before adding reps.", mediaQuery: "dead bug")
			]
	)

	static let lowerA = WorkoutTemplate(
		id: "lower-a", title: "Lower A", subtitle: "Quads · Hamstrings · Core", estimatedMinutes: 70,
		cardioRecommendation: "15–20 min easy Zone 2 after lifting. Keep it controlled after legs.",
		saunaNote: "Optional recovery, not a calorie strategy. Rehydrate afterwards.",
		exercises: [
			exercise("Back Squat / Hack Squat", "Quads · Glutes", 3, "6–10", "1–3", 150, "Primary squat pattern for quads and glutes.", "Brace, keep feet stable, and let knees track over toes.", ["Leg press", "Goblet squat"], mat: "Tempo bodyweight squat — 3 × 12–25; 3 seconds down, brief pause, stand hard.", mediaQuery: "back squat"),
			exercise("Romanian Deadlift", "Hamstrings · Glutes", 3, "8–12", "1–2", 120, "Hip hinge for hamstrings and glutes.", "Soft knees, hips back, weights close, spine neutral.", ["Dumbbell Romanian deadlift"], mat: "Single-leg glute bridge — 3 × 10–20 / leg; drive heel down and keep hips level.", mediaQuery: "romanian deadlift"),
			exercise("Leg Press", "Quads · Glutes", 2, "10–15", "1–2", 120, "Stable quad volume after squatting.", "Keep lower back on the pad and push through your whole foot.", ["Split squat"], mat: "Reverse lunge — 2 × 10–20 / leg; step back softly and keep the front foot planted.", mediaQuery: "leg press"),
			exercise("Leg Curl", "Hamstrings", 3, "10–15", "1–2", 90, "Knee-flexion hamstring work.", "Align knees with the pivot, curl smoothly, lower slowly.", ["Seated leg curl"], mat: "Hamstring walkout — 3 × 6–12; bridge up, walk heels out and back without dropping hips.", mediaQuery: "leg curl"),
			exercise("Standing Calf Raise", "Calves", 3, "10–15", "1–2", 75, "Calf work through a full range.", "Pause at stretch and squeeze; do not bounce.", ["Seated calf raise"], mat: "Single-leg calf raise — 3 × 15–30 / side; full stretch, hard top squeeze.", mediaQuery: "standing calf raise"),
				exercise("Cable Crunch", "Abs", 3, "10–15", "1–2", 75, "Controlled loaded trunk flexion.", "Curl ribs toward pelvis; do not yank with arms.", ["Machine crunch"], mat: "Reverse crunch — 3 × 10–20; curl pelvis off the mat without swinging legs.", mediaQuery: "cable crunch"),
				exercise("Side Plank", "Core · Obliques", 2, "20–40 sec / side", "2–3", 60, "Anti-side-bend core strength for trunk control.", "Stack shoulders and hips; keep a straight line without sagging.", mat: "Side plank — already mat-only. Bend the bottom knee to regress.", mediaQuery: "side plank")
			]
	)

	static let upperB = WorkoutTemplate(
		id: "upper-b", title: "Upper B", subtitle: "Shoulders · Back · Arms", estimatedMinutes: 75,
		cardioRecommendation: "15–25 min Zone 2 after lifting: incline walk, bike, or cross-trainer.",
		saunaNote: "Optional recovery. It does not earn food or burn special belly fat.",
		exercises: [
			exercise("Overhead Press / Shoulder Press", "Shoulders · Triceps", 3, "6–10", "1–2", 120, "Main vertical press.", "Brace trunk and press without arching the lower back.", ["Machine shoulder press", "Dumbbell shoulder press"], mat: "Pike push-up — 3 × 6–15; hips high and head travels toward the mat.", mediaQuery: "shoulder press"),
			exercise("Pull-Up / Assisted Pull-Up", "Lats · Upper back", 3, "6–10", "1–2", 120, "Vertical pulling strength.", "Drive elbows down and keep every rep controlled.", ["Lat pulldown"], mat: "Prone lat pull-down — 3 × 12–20; pull elbows toward hips with a two-second squeeze.", mediaQuery: "pull up"),
			exercise("Dumbbell Bench Press", "Chest · Triceps", 3, "8–12", "1–2", 120, "Free-weight horizontal pressing.", "Set shoulders, press smoothly, lower under control.", ["Chest press machine"], mat: "Push-up — 3 × 8–20; use knees only if full reps lose control.", mediaQuery: "dumbbell bench press"),
			exercise("Chest-Supported Row", "Mid-back · Lats", 3, "8–12", "1–2", 105, "Row without lower-back fatigue.", "Keep chest on the pad and pull elbows toward hips.", ["Seated cable row", "Machine row"], mat: "Prone W raise — 3 × 12–20; lift elbows and hands, pause at the squeeze.", mediaQuery: "chest supported row"),
			exercise("Rear Delt Fly", "Rear delts", 3, "12–20", "1–2", 75, "Rear-delt and upper-back balance.", "Use a light load and no momentum.", ["Reverse pec deck"], mat: "Prone T raise — 3 × 12–20; arms straight out, lift with shoulder blades not neck.", mediaQuery: "rear delt fly"),
			exercise("Cable Lateral Raise", "Side delts", 2, "12–20", "1–2", 75, "Extra side-delt volume.", "Lift smoothly and stop before traps dominate.", ["Dumbbell lateral raise"], mat: "Prone Y raise — 2 × 12–20; slow reps, no shrugging.", mediaQuery: "cable lateral raise"),
			exercise("Triceps Extension", "Triceps", 2, "10–15", "1–2", 75, "Triceps work after pressing.", "Keep elbows steady and control return.", ["Triceps pushdown"], mat: "Close-grip push-up — 2 × 6–15; keep elbows close to ribs.", mediaQuery: "triceps extension"),
				exercise("Hammer Curl", "Biceps · Forearms", 2, "10–15", "1–2", 75, "Neutral-grip elbow flexion.", "No torso swing; lower under control.", ["Dumbbell curl"], mat: "Self-resisted hammer curl — 2 × 10–20 / arm; resist the curl with your free hand.", mediaQuery: "hammer curl"),
				exercise("Hollow Body Hold", "Core · Deep abs", 2, "20–40 sec", "2–3", 60, "Anti-extension core work that carries over to pressing and bracing.", "Tuck until your low back stays on the mat, then extend only as far as you can control.", mat: "Hollow body hold — already mat-only. Tuck knees when your back lifts.", mediaQuery: "hollow body hold")
			]
	)

	static let lowerB = WorkoutTemplate(
		id: "lower-b", title: "Lower B", subtitle: "Posterior chain · Quads · Core", estimatedMinutes: 75,
		cardioRecommendation: "15–20 min easy Zone 2. Use a relaxed bike or shorten it if fatigue is high.",
		saunaNote: "Optional recovery. Stop if dizzy and drink enough afterwards.",
		exercises: [
			exercise("Deadlift Variation / Trap Bar Deadlift", "Posterior chain", 2, "5–8", "2–3", 150, "Heavy hinge with fatigue controlled.", "Brace, keep load close, and never grind to failure.", ["Trap bar deadlift", "Romanian deadlift"], mat: "Single-leg glute bridge — 2 × 10–20 / leg; controlled heel drive, hips stay square.", mediaQuery: "trap bar deadlift"),
			exercise("Bulgarian Split Squat", "Quads · Glutes", 3, "8–12 / leg", "1–2", 120, "Single-leg quad and glute strength.", "Stay controlled and keep front-foot pressure stable.", ["Walking lunge", "Leg press"], mat: "Reverse lunge — 3 × 10–20 / leg; slow descent and stable front knee.", mediaQuery: "bulgarian split squat"),
			exercise("Hip Thrust", "Glutes", 3, "8–12", "1–2", 120, "Direct glute work.", "Keep ribs down; finish by squeezing glutes, not arching.", ["Glute bridge machine"], mat: "Single-leg glute bridge — 3 × 10–20 / leg; pause one second at the top.", mediaQuery: "hip thrust"),
			exercise("Leg Extension", "Quads", 2, "12–15", "1–2", 75, "Controlled quad isolation.", "Align knee with pivot and avoid kicking the stack.", ["Sissy squat"], mat: "Wall-free squat hold — 2 × 30–60 sec; stay in a comfortable deep squat with chest tall.", mediaQuery: "leg extension"),
			exercise("Seated Leg Curl", "Hamstrings", 3, "10–15", "1–2", 90, "Hamstring work at a long muscle length.", "Keep hips down, curl smoothly, lower slowly.", ["Lying leg curl"], mat: "Hamstring walkout — 3 × 6–12; start in a bridge and keep hips elevated.", mediaQuery: "seated leg curl"),
			exercise("Seated Calf Raise", "Calves", 3, "10–15", "1–2", 75, "Soleus-focused calf work.", "Use stretch and squeeze; do not bounce.", ["Standing calf raise"], mat: "Single-leg calf raise — 3 × 15–30 / side; use slow tempo and a pause at the bottom.", mediaQuery: "seated calf raise"),
			exercise("Hanging Knee Raise", "Abs", 3, "8–15", "1–2", 75, "Controlled trunk work.", "Curl pelvis upward without swinging.", ["Cable crunch"], mat: "Reverse crunch — 3 × 10–20; curl your pelvis, not just your knees.", mediaQuery: "hanging knee raise")
		]
	)
}

struct WorkoutSetDraft: Identifiable, Codable, Hashable {
	var id: String
	var exerciseName: String
	var setNumber: Int
	var weight = ""
	var reps = ""
	var rir = ""
	var isComplete = false

	var loggedSet: LoggedSet? {
		guard isComplete,
			let kg = Double(weight.replacingOccurrences(of: ",", with: ".")), kg.isFinite, kg >= 0,
			let repetitions = Int(reps), repetitions > 0,
			let reserve = Double(rir.replacingOccurrences(of: ",", with: ".")), reserve.isFinite, reserve >= 0 else { return nil }
		return LoggedSet(exerciseName: exerciseName, setNumber: setNumber, weightKilograms: kg, repetitions: repetitions, rir: reserve)
	}
}

struct WorkoutDraft: Identifiable, Codable, Hashable {
	var id = UUID()
	var template: WorkoutTemplate
	var startedAt: Date
	var sets: [WorkoutSetDraft]

	init(template: WorkoutTemplate, startedAt: Date = .now) {
		self.template = template
		self.startedAt = startedAt
		sets = template.exercises.flatMap { exercise in
			(0..<max(0, exercise.sets)).map { index in
				WorkoutSetDraft(id: "\(exercise.id)-\(index + 1)", exerciseName: exercise.name, setNumber: index + 1)
			}
		}
	}

	var completedSetCount: Int { sets.filter(\.isComplete).count }
	var loggedSets: [LoggedSet] { sets.compactMap(\.loggedSet) }
}

struct LoggedSet: Identifiable, Codable, Hashable {
	var id = UUID()
	var exerciseName: String
	var setNumber: Int
	var weightKilograms: Double
	var repetitions: Int
	var rir: Double

	init(id: UUID = UUID(), exerciseName: String, setNumber: Int, weightKilograms: Double, repetitions: Int, rir: Double = 2) {
		self.id = id
		self.exerciseName = exerciseName
		self.setNumber = setNumber
		self.weightKilograms = weightKilograms
		self.repetitions = repetitions
		self.rir = rir
	}

	private enum CodingKeys: String, CodingKey { case id, exerciseName, setNumber, weightKilograms, repetitions, rir }

	init(from decoder: Decoder) throws {
		let values = try decoder.container(keyedBy: CodingKeys.self)
		id = try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
		exerciseName = try values.decode(String.self, forKey: .exerciseName)
		setNumber = try values.decode(Int.self, forKey: .setNumber)
		weightKilograms = try values.decode(Double.self, forKey: .weightKilograms)
		repetitions = try values.decode(Int.self, forKey: .repetitions)
		rir = try values.decodeIfPresent(Double.self, forKey: .rir) ?? 2
	}
}

struct WorkoutEntry: Identifiable, Codable, Hashable {
	var id = UUID()
	var templateID: String
	var sets: [LoggedSet]
	var completedAt = Date()
	var startedAt: Date?
	var templateTitle: String?
	// Preserve partial fields and unchecked sets; never turn missing numbers into zero.
	var setRecords: [WorkoutSetDraft]?
	var completedSetCount: Int { setRecords?.filter(\.isComplete).count ?? sets.count }

	init(id: UUID = UUID(), templateID: String, sets: [LoggedSet] = [], completedAt: Date = .now, startedAt: Date? = nil, templateTitle: String? = nil, setRecords: [WorkoutSetDraft]? = nil) {
		self.id = id
		self.templateID = templateID
		self.sets = sets
		self.completedAt = completedAt
		self.startedAt = startedAt
		self.templateTitle = templateTitle
		self.setRecords = setRecords
	}

	private enum CodingKeys: String, CodingKey { case id, templateID, sets, completedAt, startedAt, templateTitle, setRecords }

	init(from decoder: Decoder) throws {
		let values = try decoder.container(keyedBy: CodingKeys.self)
		id = try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
		templateID = try values.decode(String.self, forKey: .templateID)
		sets = try values.decodeIfPresent([LoggedSet].self, forKey: .sets) ?? []
		completedAt = try values.decodeIfPresent(Date.self, forKey: .completedAt) ?? .now
		startedAt = try values.decodeIfPresent(Date.self, forKey: .startedAt)
		templateTitle = try values.decodeIfPresent(String.self, forKey: .templateTitle)
		setRecords = try values.decodeIfPresent([WorkoutSetDraft].self, forKey: .setRecords)
	}
}

struct AppSettings: Codable, Hashable {
	var calorieGoal = 2_450
	var proteinGoal = 190
	var reminderEnabled = true
	var healthSyncEnabled = false

	private enum CodingKeys: String, CodingKey { case calorieGoal, proteinGoal, reminderEnabled, healthSyncEnabled }

	init() {}

	init(from decoder: Decoder) throws {
		let values = try decoder.container(keyedBy: CodingKeys.self)
		calorieGoal = try values.decodeIfPresent(Int.self, forKey: .calorieGoal) ?? 2_450
		proteinGoal = try values.decodeIfPresent(Int.self, forKey: .proteinGoal) ?? 190
		reminderEnabled = try values.decodeIfPresent(Bool.self, forKey: .reminderEnabled) ?? true
		healthSyncEnabled = try values.decodeIfPresent(Bool.self, forKey: .healthSyncEnabled) ?? false
	}
}

struct DailyTotals: Equatable {
	var calories = 0
	var protein = 0
	var carbs = 0
	var fat = 0
}

struct ScheduledWorkout: Identifiable, Hashable {
	let weekday: Int
	let shortDay: String
	let templateID: String
	var id: Int { weekday }
}

enum WorkoutSchedule {
	static let weeklySchedule = [
		ScheduledWorkout(weekday: 2, shortDay: "Mon", templateID: "upper-a"),
		ScheduledWorkout(weekday: 4, shortDay: "Wed", templateID: "lower-a"),
		ScheduledWorkout(weekday: 6, shortDay: "Fri", templateID: "upper-b"),
		ScheduledWorkout(weekday: 1, shortDay: "Sun", templateID: "lower-b")
	]

	static func scheduledWorkout(on date: Date, calendar: Calendar = .current) -> ScheduledWorkout? {
		weeklySchedule.first { $0.weekday == calendar.component(.weekday, from: date) }
	}

	static func nextScheduledWorkout(from date: Date = .now, calendar: Calendar = .current) -> (workout: ScheduledWorkout, date: Date) {
		for offset in 0...7 {
			guard let candidate = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: date)), let workout = scheduledWorkout(on: candidate, calendar: calendar) else { continue }
			return (workout, candidate)
		}
		return (weeklySchedule[0], date)
	}

	static func isDue(workouts: [WorkoutEntry], now: Date = .now, calendar: Calendar = .current) -> Bool {
		guard scheduledWorkout(on: now, calendar: calendar) != nil else { return false }
		return !workouts.contains { calendar.isDate($0.completedAt, inSameDayAs: now) }
	}
}
