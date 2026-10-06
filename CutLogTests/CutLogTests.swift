import SwiftUI
import XCTest
@testable import CutLog

@MainActor
final class CutLogTests: XCTestCase {
	func testBarcodePackageGramsSupportsAPIFieldsAndLabelFallback() {
		XCTAssertEqual(BarcodeLookupService.packageGrams(productQuantity: 190, unit: "g", quantity: nil), 190)
		XCTAssertEqual(BarcodeLookupService.packageGrams(productQuantity: 0.5, unit: "kg", quantity: nil), 500)
		XCTAssertEqual(BarcodeLookupService.packageGrams(productQuantity: nil, unit: nil, quantity: "2 x 190 g"), 380)
		XCTAssertNil(BarcodeLookupService.packageGrams(productQuantity: 330, unit: "ml", quantity: nil))
	}

	func testWeeklyScheduleUsesUpperLowerSplit() {
		XCTAssertEqual(WorkoutSchedule.weeklySchedule.map(\.templateID), ["upper-a", "lower-a", "upper-b", "lower-b"])
	}

	func testMondayUsesUpperAAndIsDueUntilLogged() {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
		let monday = calendar.date(from: DateComponents(year: 2026, month: 9, day: 14, hour: 9))!
		XCTAssertEqual(WorkoutSchedule.scheduledWorkout(on: monday, calendar: calendar)?.templateID, "upper-a")
		XCTAssertTrue(WorkoutSchedule.isDue(workouts: [], now: monday, calendar: calendar))
		XCTAssertFalse(WorkoutSchedule.isDue(workouts: [WorkoutEntry(templateID: "upper-a", completedAt: monday)], now: monday, calendar: calendar))
	}

	func testFinishingLastWeeksLowerBOnMondayDoesNotCompleteUpperA() throws {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
		let sunday = calendar.date(from: DateComponents(year: 2026, month: 9, day: 27, hour: 18))!
		let monday = calendar.date(from: DateComponents(year: 2026, month: 9, day: 28, hour: 10))!
		try withStore { _, defaults in
			let draft = WorkoutDraft(template: .lowerB, startedAt: sunday)
			defaults.set(try JSONEncoder().encode(draft), forKey: "active-workout-v1")
			let reopened = AppStore(defaults: defaults)
			let completed = try XCTUnwrap(reopened.finishWorkout())
			XCTAssertEqual(completed.templateID, "lower-b")
			XCTAssertEqual(completed.startedAt, sunday)
			XCTAssertTrue(WorkoutSchedule.isDue(workouts: reopened.workouts, now: monday, calendar: calendar))
			XCTAssertEqual(WorkoutSchedule.nextScheduledWorkout(from: monday, calendar: calendar).workout.templateID, "upper-a")
		}
	}

	func testStartedSundayAndFinishedMondayCountsForSundayNotMonday() {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
		let sunday = calendar.date(from: DateComponents(year: 2026, month: 9, day: 27, hour: 23, minute: 55))!
		let monday = calendar.date(from: DateComponents(year: 2026, month: 9, day: 28, hour: 0, minute: 15))!
		let workout = WorkoutEntry(templateID: "lower-b", completedAt: monday, startedAt: sunday)
		XCTAssertFalse(WorkoutSchedule.isDue(workouts: [workout], now: sunday, calendar: calendar))
		XCTAssertTrue(WorkoutSchedule.isDue(workouts: [workout], now: monday, calendar: calendar))
	}

	func testAnotherWorkoutTodayDoesNotCompleteScheduledWorkout() {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
		let monday = calendar.date(from: DateComponents(year: 2026, month: 9, day: 28, hour: 10))!
		XCTAssertTrue(WorkoutSchedule.isDue(workouts: [WorkoutEntry(templateID: "lower-b", completedAt: monday)], now: monday, calendar: calendar))
		XCTAssertFalse(WorkoutSchedule.isDue(workouts: [WorkoutEntry(templateID: "upper-a", completedAt: monday)], now: monday, calendar: calendar))
	}

	func testChoosingTodayPreservesOldDraftAndCanResumeIt() throws {
		try withStore { store, defaults in
			store.beginWorkout(.lowerB)
			var checked = try XCTUnwrap(store.activeWorkout?.sets.first)
			checked.isComplete = true
			store.updateWorkoutSet(checked)
			let old = try XCTUnwrap(store.activeWorkout)
			store.startScheduledWorkout(.upperA)
			XCTAssertEqual(store.activeWorkout?.template.id, "upper-a")
			XCTAssertEqual(store.pausedWorkouts, [old])
			let reopened = AppStore(defaults: defaults)
			XCTAssertEqual(reopened.pausedWorkouts, [old])
			reopened.resumeWorkout(old.id)
			XCTAssertEqual(reopened.activeWorkout, old)
			XCTAssertEqual(reopened.pausedWorkouts.first?.template.id, "upper-a")
			let finished = try XCTUnwrap(reopened.finishWorkout())
			XCTAssertEqual(finished.templateID, "lower-b")
			XCTAssertEqual(finished.completedSetCount, 1)
			XCTAssertEqual(reopened.activeWorkout?.template.id, "upper-a")
		}
	}

	func testInterruptedFinishRestoresPausedDraftWithoutDuplicatingHistory() throws {
		try withStore { store, defaults in
			store.beginWorkout(.lowerB)
			let old = try XCTUnwrap(store.activeWorkout)
			store.startScheduledWorkout(.upperA)
			let today = try XCTUnwrap(store.activeWorkout)
			let completed = WorkoutEntry(id: today.id, templateID: today.template.id, startedAt: today.startedAt)
			store.workouts.append(completed)
			let recovered = AppStore(defaults: defaults)
			XCTAssertEqual(recovered.workouts, [completed])
			XCTAssertEqual(recovered.unfinishedWorkouts, [old])
			XCTAssertEqual(AppStore(defaults: defaults).unfinishedWorkouts, [old])
		}
	}

	func testStartingSameTemplateOnNewDayDoesNotContinuePreviousWeeksDraft() throws {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
		let oldMonday = calendar.date(from: DateComponents(year: 2026, month: 9, day: 21, hour: 10))!
		let newMonday = calendar.date(from: DateComponents(year: 2026, month: 9, day: 28, hour: 10))!
		try withStore { _, defaults in
			let draft = WorkoutDraft(template: .upperA, startedAt: oldMonday)
			defaults.set(try JSONEncoder().encode(draft), forKey: "active-workout-v1")
			let reopened = AppStore(defaults: defaults)
			reopened.startScheduledWorkout(.upperA, on: newMonday, calendar: calendar)
			XCTAssertNotEqual(reopened.activeWorkout?.id, draft.id)
			XCTAssertEqual(reopened.pausedWorkouts, [draft])
		}
	}

	func testTuesdayIsNotAGymDayAndNextSessionIsLowerA() {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
		let tuesday = calendar.date(from: DateComponents(year: 2026, month: 9, day: 15, hour: 9))!
		XCTAssertFalse(WorkoutSchedule.isDue(workouts: [], now: tuesday, calendar: calendar))
		XCTAssertEqual(WorkoutSchedule.nextScheduledWorkout(from: tuesday, calendar: calendar).workout.templateID, "lower-a")
	}

	func testSevenDayTrendUsesRollingDailyAverage() {
		let suite = "CutLogTests-\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suite)!
		defer { defaults.removePersistentDomain(forName: suite) }
		let store = AppStore(defaults: defaults)
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
		let start = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1, hour: 8))!
		store.weights = (0..<7).map { day in
			WeightEntry(kilograms: 97 - Double(day) * 0.2, date: calendar.date(byAdding: .day, value: day, to: start)!)
		}
		XCTAssertEqual(store.sevenDayWeightTrend.count, 7)
		XCTAssertEqual(store.sevenDayWeightTrend.last?.kilograms ?? 0, 96.4, accuracy: 0.001)
	}

	func testLoggedSetDefaultsRIRForOldRecords() throws {
		let oldData = "{\"exerciseName\":\"Bench Press\",\"setNumber\":1,\"weightKilograms\":80,\"repetitions\":8}".data(using: .utf8)!
		let set = try JSONDecoder().decode(LoggedSet.self, from: oldData)
		XCTAssertEqual(set.rir, 2)
	}

	func testDraftPersistsEveryEditAndCheckmark() throws {
		try withStore { store, defaults in
			store.beginWorkout(.upperA)
			var set = try XCTUnwrap(store.activeWorkout?.sets.first)
			set.weight = "82,5"
			set.reps = "8"
			set.isComplete = true
			store.updateWorkoutSet(set)
			let reopened = AppStore(defaults: defaults)
			XCTAssertEqual(reopened.activeWorkout, store.activeWorkout)
			XCTAssertEqual(reopened.activeWorkout?.sets.first?.rir, "")
			XCTAssertTrue(reopened.workouts.isEmpty)
			set.isComplete = false
			reopened.updateWorkoutSet(set)
			XCTAssertEqual(AppStore(defaults: defaults).activeWorkout?.completedSetCount, 0)
		}
	}

	func testFinishKeepsPartialFieldsAndSkippedSets() throws {
		try withStore { store, defaults in
			store.beginWorkout(.upperA)
			var set = try XCTUnwrap(store.activeWorkout?.sets.first)
			set.isComplete = true
			set.weight = "80"
			store.updateWorkoutSet(set)
			let expected = store.activeWorkout?.sets
			let finished = try XCTUnwrap(store.finishWorkout())
			XCTAssertEqual(finished.completedSetCount, 1)
			XCTAssertTrue(finished.sets.isEmpty)
			XCTAssertEqual(finished.setRecords, expected)
			XCTAssertEqual(finished.setRecords?.first?.reps, "")
			let reopened = AppStore(defaults: defaults)
			XCTAssertNil(reopened.activeWorkout)
			XCTAssertEqual(reopened.workouts, [finished])
			XCTAssertNil(store.finishWorkout())
			XCTAssertEqual(store.workouts.count, 1)
		}
	}

	func testEmptyWorkoutCanFinishWithoutInventedNumbers() throws {
		try withStore { store, _ in
			store.beginWorkout(.lowerB)
			let workout = try XCTUnwrap(store.finishWorkout())
			XCTAssertEqual(workout.completedSetCount, 0)
			XCTAssertTrue(workout.sets.isEmpty)
			XCTAssertTrue(workout.setRecords!.allSatisfy { $0.weight.isEmpty && $0.reps.isEmpty && $0.rir.isEmpty && !$0.isComplete })
		}
	}

	func testActiveTemplateSurvivesPlanChangesAndDifferentSessionOpen() throws {
		try withStore { store, defaults in
			store.beginWorkout(.upperA)
			let original = store.activeWorkout
			var modified = WorkoutTemplate.upperA
			modified.title = "Edited later"
			modified.exercises.removeAll()
			store.updateTemplate(modified)
			store.beginWorkout(.lowerA)
			let reopened = AppStore(defaults: defaults)
			XCTAssertEqual(reopened.activeWorkout, original)
			XCTAssertEqual(reopened.nextWorkout, original?.template)
		}
	}

	func testCheckedCompleteSetParsesCommaAndBodyweight() throws {
		var set = WorkoutSetDraft(id: "set", exerciseName: "Press", setNumber: 1, weight: "82,5", reps: "8", rir: "1,5", isComplete: true)
		XCTAssertEqual(try XCTUnwrap(set.loggedSet).weightKilograms, 82.5)
		XCTAssertEqual(try XCTUnwrap(set.loggedSet).rir, 1.5)
		set.weight = "0"
		XCTAssertEqual(set.loggedSet?.weightKilograms, 0)
		set.isComplete = false
		XCTAssertNil(set.loggedSet)
	}

	func testInvalidOrMissingSetValuesAreNotInvented() {
		var set = WorkoutSetDraft(id: "set", exerciseName: "Press", setNumber: 1, weight: "80", reps: "8", rir: "2", isComplete: true)
		for value in ["", "NaN", "inf", "-5", "nope"] {
			set.weight = value
			XCTAssertNil(set.loggedSet)
		}
		set.weight = "80"
		set.reps = "0"
		XCTAssertNil(set.loggedSet)
		set.reps = "8"
		set.rir = ""
		XCTAssertNil(set.loggedSet)
	}

	func testOldWorkoutRecordStillDecodes() throws {
		let data = Data(#"{"templateID":"upper-a","sets":[]}"#.utf8)
		let workout = try JSONDecoder().decode(WorkoutEntry.self, from: data)
		XCTAssertNil(workout.setRecords)
		XCTAssertNil(workout.startedAt)
		XCTAssertEqual(workout.completedSetCount, 0)
	}

	func testWeightHistoryIsNotTruncatedToSevenPoints() throws {
		try withStore { store, _ in
			let calendar = Calendar.current
			let start = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 8))!
			store.weights = (0..<100).map { day in
				WeightEntry(kilograms: 100 - Double(day) * 0.1, date: calendar.date(byAdding: .day, value: day, to: start)!)
			}
			let end = store.weights.last!.date
			XCTAssertEqual(store.sevenDayWeightTrend.count, 100)
			XCTAssertEqual(store.weightTrend(days: 90, endingAt: end).count, 90)
			XCTAssertEqual(store.weightTrend(days: 30, endingAt: end).count, 30)
			XCTAssertEqual(store.weightTrend(days: nil, endingAt: end).count, 100)
			XCTAssertEqual(store.weightTrend(days: 90, endingAt: end).first!.kilograms, 99.3, accuracy: 0.001)
		}
	}

	func testWeightTrendUsesLatestDailyReadingAndCalendarGaps() throws {
		try withStore { store, _ in
			let calendar = Calendar.current
			let day = calendar.startOfDay(for: .now)
			store.weights = [
				WeightEntry(kilograms: 100, date: day.addingTimeInterval(3600)),
				WeightEntry(kilograms: 98, date: day.addingTimeInterval(7200)),
				WeightEntry(kilograms: 90, date: calendar.date(byAdding: .day, value: 10, to: day)!)
			]
			XCTAssertEqual(store.sevenDayWeightTrend.map(\.kilograms), [98, 90])
			XCTAssertEqual(store.weightTrend(days: 7, endingAt: day).map(\.kilograms), [98])
		}
	}

	func testWidgetOverGoalAndMidnightRollover() {
		let calendar = Calendar.current
		let today = calendar.startOfDay(for: .now)
		let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
		let data = CutLogWidgetData(calorieGoal: 2450, days: [CalorieDay(date: today, calories: 2700)])
		XCTAssertEqual(data.caloriesLeft(on: today), -250)
		XCTAssertEqual(data.caloriesLeft(on: tomorrow), 2450)
		XCTAssertEqual(data.week(endingAt: tomorrow).count, 7)
		XCTAssertNil(data.week(endingAt: tomorrow).last?.calories)
		XCTAssertEqual(data.week(endingAt: tomorrow)[5].calories, 2700)
	}

	func testWidgetMissingDaysRemainMissingAndOldSnapshotIsRejected() {
		let data = CutLogWidgetData(calorieGoal: 2450, days: [])
		XCTAssertTrue(data.week(endingAt: .now).allSatisfy { $0.calories == nil })
		let old = Data(#"{"caloriesLeft":1420,"calorieGoal":2200,"protein":96,"proteinGoal":180,"workoutTitle":"Upper A","workoutDue":true}"#.utf8)
		XCTAssertThrowsError(try JSONDecoder().decode(CutLogWidgetData.self, from: old))
	}

	func testWidgetWeekUsesCalendarDaysAcrossDaylightSaving() {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
		let end = calendar.date(from: DateComponents(year: 2026, month: 10, day: 27, hour: 12))!
		let week = CutLogWidgetData(calorieGoal: 2450, days: []).week(endingAt: end, calendar: calendar)
		XCTAssertEqual(week.map { calendar.component(.day, from: $0.date) }, [21, 22, 23, 24, 25, 26, 27])
		XCTAssertTrue(week.allSatisfy { calendar.component(.hour, from: $0.date) == 0 })
	}

	// Recents are replaced by the searchable catalog; pins stay a separate concept.
	func testPinnedFoodsArePersistedIndependentlyOfCatalog() throws {
		try withStore { store, defaults in
			let pinned = FoodEntry(name: "Greek yogurt", calories: 180, protein: 20, carbs: 8, fat: 6)
			let other = FoodEntry(name: "Oats", calories: 370, protein: 13, carbs: 60, fat: 7, date: Date.now.addingTimeInterval(-60))
			store.addFood(pinned)
			store.addFood(other)
			store.togglePinned(pinned)

			XCTAssertEqual(store.quickLogFoods.map(\.name), ["Greek yogurt"])
			XCTAssertTrue(store.isPinned(pinned))
			XCTAssertFalse(store.isPinned(other))
			// Both are searchable, including the pinned one.
			XCTAssertEqual(Set(store.searchFoods(query: "greek").map(\.name)), ["Greek yogurt"])
			XCTAssertEqual(Set(store.searchFoods(query: "oats").map(\.name)), ["Oats"])

			let reopened = AppStore(defaults: defaults)
			XCTAssertEqual(reopened.quickLogFoods.map(\.name), ["Greek yogurt"])
			reopened.togglePinned(FoodEntry(name: "Greek yogurt", calories: 180, protein: 20, carbs: 8, fat: 6))
			XCTAssertTrue(reopened.quickLogFoods.isEmpty)
			XCTAssertEqual(reopened.foodCatalog.count, 2)
		}
	}

	func testInjectedDefaultsPersistSettingsAndFoodWithoutTouchingStandard() throws {
		let original = UserDefaults.standard.data(forKey: "foods")
		try withStore { store, defaults in
			store.settings.calorieGoal = 2500
			store.addFood(FoodEntry(name: "Test", calories: 500, protein: 30, carbs: 50, fat: 10))
			let reopened = AppStore(defaults: defaults)
			XCTAssertEqual(reopened.foods, store.foods)
			XCTAssertEqual(reopened.settings.calorieGoal, 2500)
			XCTAssertEqual(UserDefaults.standard.data(forKey: "foods"), original)
		}
	}

	func testInterruptedFinishDoesNotRestoreCompletedDraft() throws {
		try withStore { store, defaults in
			store.beginWorkout(.upperA)
			let draft = try XCTUnwrap(store.activeWorkout)
			store.workouts.append(WorkoutEntry(id: draft.id, templateID: draft.template.id))
			let reopened = AppStore(defaults: defaults)
			XCTAssertNil(reopened.activeWorkout)
			XCTAssertNil(reopened.finishWorkout())
			XCTAssertEqual(reopened.workouts.count, 1)
		}
	}

	func testDraftSurvivesDayChange() throws {
		try withStore { _, defaults in
			let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
			let draft = WorkoutDraft(template: .lowerA, startedAt: yesterday)
			defaults.set(try JSONEncoder().encode(draft), forKey: "active-workout-v1")
			let reopened = AppStore(defaults: defaults)
			XCTAssertEqual(reopened.activeWorkout, draft)
			XCTAssertEqual(reopened.nextWorkout.id, "lower-a")
		}
	}

	func testFreshSessionStartsEmptyAfterPreviousFinish() throws {
		try withStore { store, _ in
			store.beginWorkout(.upperA)
			let oldID = store.activeWorkout?.id
			_ = store.finishWorkout()
			store.beginWorkout(.lowerA)
			XCTAssertNotEqual(store.activeWorkout?.id, oldID)
			XCTAssertEqual(store.activeWorkout?.template.id, "lower-a")
			XCTAssertEqual(store.activeWorkout?.completedSetCount, 0)
		}
	}

	func testSavedDefaultPlanGainsCoreAndMatAlternativesWithoutOverwritingEdits() throws {
		try withStore { _, defaults in
			var savedUpperA = WorkoutTemplate.upperA
			savedUpperA.exercises.removeAll { $0.name == "Dead Bug" }
			let benchIndex = try XCTUnwrap(savedUpperA.exercises.firstIndex { $0.name == "Bench Press / Chest Press" })
			savedUpperA.exercises[benchIndex].sets = 4
			savedUpperA.exercises[benchIndex].matAlternative = ""
			savedUpperA.exercises[benchIndex].exerciseDBQuery = ""
			let legacyPlan = TrainingPlan(templates: [savedUpperA, .lowerA, .upperB, .lowerB])
			defaults.set(try JSONEncoder().encode(legacyPlan), forKey: "training-plan-v2")

			let reopened = AppStore(defaults: defaults)
			let upgraded = try XCTUnwrap(reopened.template(for: "upper-a"))
			let bench = try XCTUnwrap(upgraded.exercises.first { $0.name == "Bench Press / Chest Press" })
			XCTAssertEqual(bench.sets, 4)
			XCTAssertFalse(bench.matAlternative.isEmpty)
			XCTAssertEqual(bench.exerciseDBQuery, "bench press")
			XCTAssertNotNil(upgraded.exercises.first { $0.name == "Dead Bug" })
		}
	}

	func testLoggingStreakCountsOneCalendarDayOnceAndAllowsLoggingLaterToday() throws {
		try withStore { store, _ in
			var calendar = Calendar(identifier: .gregorian)
			calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
			let today = calendar.date(from: DateComponents(year: 2026, month: 9, day: 24, hour: 12))!
			let dates = [
				calendar.date(byAdding: .day, value: -3, to: today)!,
				calendar.date(byAdding: .day, value: -2, to: today)!,
				calendar.date(byAdding: .day, value: -1, to: today)!,
				calendar.date(byAdding: .hour, value: -2, to: today)!,
				calendar.date(byAdding: .hour, value: -1, to: today)!
			]
			XCTAssertEqual(store.loggingStreak(for: dates, now: today, calendar: calendar), 4)
			XCTAssertEqual(store.loggingStreak(for: Array(dates.dropLast(2)), now: today, calendar: calendar), 3)
			XCTAssertEqual(store.loggingStreak(for: [calendar.date(byAdding: .day, value: -4, to: today)!], now: today, calendar: calendar), 0)
		}
	}

	func testSingleLoggingStreakCountsEitherFoodOrWeightOncePerDayAndUpdatesAfterDeletion() throws {
		try withStore { store, _ in
			let calendar = Calendar.current
			let today = calendar.startOfDay(for: .now)
			let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
			let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
			let food = FoodEntry(name: "Meal", calories: 400, protein: 30, carbs: 40, fat: 10, date: today)
			let yesterdayFood = FoodEntry(name: "Yesterday meal", calories: 400, protein: 30, carbs: 40, fat: 10, date: yesterday)
			store.foods = [food, yesterdayFood]
			store.weights = [WeightEntry(kilograms: 97, date: twoDaysAgo), WeightEntry(kilograms: 96.8, date: yesterday)]
			XCTAssertEqual(store.loggingStreak, 3)
			store.deleteFood(food)
			XCTAssertEqual(store.loggingStreak, 2)
			store.deleteFood(yesterdayFood)
			store.weights.removeAll { calendar.isDate($0.date, inSameDayAs: yesterday) }
			XCTAssertEqual(store.loggingStreak, 1)
		}
	}

	func testEveryDefaultExerciseHasItsIntendedTutorialQuery() {
		let expected: [String: String] = [
			"Bench Press / Chest Press": "bench press", "Lat Pulldown": "lat pulldown",
			"Seated Cable Row": "seated cable row", "Incline Dumbbell Press": "incline dumbbell press",
			"Cable Lateral Raise": "cable lateral raise", "Triceps Pushdown": "triceps pushdown",
			"Dumbbell Curl": "dumbbell curl", "Dead Bug": "dead bug",
			"Back Squat / Hack Squat": "back squat", "Romanian Deadlift": "romanian deadlift",
			"Leg Press": "leg press", "Leg Curl": "leg curl", "Standing Calf Raise": "standing calf raise",
			"Cable Crunch": "cable crunch", "Side Plank": "side plank",
			"Overhead Press / Shoulder Press": "shoulder press", "Pull-Up / Assisted Pull-Up": "pull up",
			"Dumbbell Bench Press": "dumbbell bench press", "Chest-Supported Row": "chest supported row",
			"Rear Delt Fly": "rear delt fly", "Triceps Extension": "triceps extension",
			"Hammer Curl": "hammer curl", "Hollow Body Hold": "hollow body hold",
			"Deadlift Variation / Trap Bar Deadlift": "trap bar deadlift", "Bulgarian Split Squat": "bulgarian split squat",
			"Hip Thrust": "hip thrust", "Leg Extension": "leg extension", "Seated Leg Curl": "seated leg curl",
			"Seated Calf Raise": "seated calf raise", "Hanging Knee Raise": "hanging knee raise"
		]
		let exercises = TrainingPlan.default.templates.flatMap(\.exercises)
		XCTAssertEqual(exercises.count, expected.count)
		XCTAssertEqual(Set(exercises.map(\.name)).count, exercises.count)
		for exercise in exercises {
			XCTAssertEqual(exercise.exerciseDBQuery, expected[exercise.name], "Wrong tutorial mapping for \(exercise.name)")
			XCTAssertFalse(exercise.matAlternative.isEmpty, "Missing mat alternative: \(exercise.name)")
		}
	}

	func testExerciseDBRefusesWrongFirstResultAndNormalizesPunctuation() throws {
		func result(_ id: String, _ name: String) -> ExerciseDBExercise {
			ExerciseDBExercise(exerciseID: id, name: name, imageURL: nil, imageURLs: nil, equipments: [], bodyParts: [], exerciseType: nil, targetMuscles: [], secondaryMuscles: [], videoURL: nil, overview: nil, instructions: [], exerciseTips: [], variations: [])
		}
		let misleading = [result("arnold", "Arnold Press"), result("leg-press", "Leg Press")]
		XCTAssertEqual(ExerciseDBService.exactMatch(in: misleading, for: "Leg Press")?.exerciseID, "leg-press")
		XCTAssertNil(ExerciseDBService.exactMatch(in: [result("arnold", "Arnold Press")], for: "Leg Press"))
		XCTAssertEqual(ExerciseDBService.exactMatch(in: [result("bench", "Bench-Press")], for: "bench press")?.exerciseID, "bench")
	}

	func testExerciseDBDetailDecodesTutorialMedia() throws {
		let data = Data(#"{"exerciseId":"exr_bench","name":"Bench Press","imageUrl":"https://cdn.example/image.jpg","imageUrls":{"480p":"https://cdn.example/480.jpg"},"targetMuscles":["PECTORALIS MAJOR"],"secondaryMuscles":["TRICEPS"],"videoUrl":"https://cdn.example/video.mp4","overview":"Chest press.","instructions":["Set up.","Press."],"exerciseTips":["Control it."],"variations":["Dumbbell bench press"]}"#.utf8)
		let exercise = try JSONDecoder().decode(ExerciseDBExercise.self, from: data)
		XCTAssertEqual(exercise.exerciseID, "exr_bench")
		XCTAssertEqual(exercise.preferredImageURL?.absoluteString, "https://cdn.example/480.jpg")
		XCTAssertEqual(exercise.videoURL?.absoluteString, "https://cdn.example/video.mp4")
		XCTAssertEqual(exercise.instructions.count, 2)
		XCTAssertEqual(exercise.targetMuscles, ["PECTORALIS MAJOR"])
	}

	func testHealthErrorRetainsDiagnosisInsteadOfGenericFailure() {
		let error = NSError(domain: "HealthKit", code: 4, userInfo: [NSLocalizedDescriptionKey: "Missing com.apple.developer.healthkit entitlement"])
		XCTAssertTrue(HealthKitStore.message(for: error).contains("Signing & Capabilities"))
		let unknown = NSError(domain: "TestHealth", code: 123, userInfo: [NSLocalizedDescriptionKey: "Connection interrupted"])
		XCTAssertTrue(HealthKitStore.message(for: unknown).contains("TestHealth, 123"))
		XCTAssertTrue(HealthKitStore.Access(writableTypes: 0, requestedTypes: 6).summary.contains("0/6"))
	}

	func testCutScoreUsesSevenCompletedDaysAndScheduledWorkoutMatches() throws {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
		let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 28, hour: 12))!
		let dates = [
			calendar.date(from: DateComponents(year: 2026, month: 9, day: 21, hour: 10))!,
			calendar.date(from: DateComponents(year: 2026, month: 9, day: 23, hour: 10))!,
			calendar.date(from: DateComponents(year: 2026, month: 9, day: 25, hour: 10))!
		]
		let foods = dates.map { FoodEntry(name: "Meal", calories: 2_450, protein: 190, carbs: 250, fat: 70, date: $0) }
		let sunday = calendar.date(from: DateComponents(year: 2026, month: 9, day: 27, hour: 10))!
		let workouts = [
			WorkoutEntry(templateID: "upper-a", sets: [LoggedSet(exerciseName: "Bench Press", setNumber: 1, weightKilograms: 80, repetitions: 8)], completedAt: dates[0], startedAt: dates[0]),
			WorkoutEntry(templateID: "lower-a", sets: [LoggedSet(exerciseName: "Squat", setNumber: 1, weightKilograms: 80, repetitions: 8)], completedAt: dates[1], startedAt: dates[1]),
			WorkoutEntry(templateID: "upper-b", sets: [LoggedSet(exerciseName: "Press", setNumber: 1, weightKilograms: 40, repetitions: 8)], completedAt: dates[2], startedAt: dates[2]),
			WorkoutEntry(templateID: "lower-b", sets: [LoggedSet(exerciseName: "Deadlift", setNumber: 1, weightKilograms: 100, repetitions: 8)], completedAt: sunday, startedAt: sunday)
		]
		let score = try XCTUnwrap(CutScore.calculate(foods: foods, workouts: workouts, calorieGoal: 2_450, proteinGoal: 190, now: now, calendar: calendar))
		XCTAssertEqual(score.score, 100)
		XCTAssertEqual(score.calorieAdherence, 100)
		XCTAssertEqual(score.proteinProgress, 100)
		XCTAssertEqual(score.trainingConsistency, 100)
		XCTAssertEqual(score.scheduledTrainingDays, 4)
	}

	func testCutScoreRequiresThreeCompletedFoodLogDaysAndIgnoresToday() {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
		let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 28, hour: 12))!
		let dates = [21, 23, 28].map { calendar.date(from: DateComponents(year: 2026, month: 9, day: $0, hour: 10))! }
		let foods = dates.map { FoodEntry(name: "Meal", calories: 2_450, protein: 190, carbs: 250, fat: 70, date: $0) }
		XCTAssertNil(CutScore.calculate(foods: foods, workouts: [], calorieGoal: 2_450, proteinGoal: 190, now: now, calendar: calendar))
	}

	func testCutScoreAveragesOnlyLoggedDaysAndCorrectlyScoresMissedSessions() throws {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
		let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 28, hour: 12))!
		let dates = [21, 23, 25].map { calendar.date(from: DateComponents(year: 2026, month: 9, day: $0, hour: 10))! }
		let foods = dates.map { FoodEntry(name: "Meal", calories: 2_450, protein: 190, carbs: 250, fat: 70, date: $0) }
		let workout = WorkoutEntry(templateID: "upper-a", sets: [LoggedSet(exerciseName: "Bench Press", setNumber: 1, weightKilograms: 80, repetitions: 8)], completedAt: dates[0], startedAt: dates[0])
		let score = try XCTUnwrap(CutScore.calculate(foods: foods, workouts: [workout], calorieGoal: 2_450, proteinGoal: 190, now: now, calendar: calendar))
		XCTAssertEqual(score.calorieAdherence, 100)
		XCTAssertEqual(score.proteinProgress, 100)
		XCTAssertEqual(score.trainingConsistency, 25)
		XCTAssertEqual(score.score, 81)
	}

	func testMealEstimateRejectsUnrelatedAndImplausibleResults() {
		let banana = MealEstimate(name: "Banana", calories: 105, protein: 1, carbs: 27, fat: 0)
		XCTAssertTrue(MealEstimateService.isPlausible(banana, describedAs: "1 banana"))
		XCTAssertFalse(MealEstimateService.isPlausible(MealEstimate(name: "Chicken stir fry", calories: 520, protein: 38, carbs: 45, fat: 18), describedAs: "banana"))
		XCTAssertTrue(MealEstimateService.matchesDescription("Pizza Diavola", describedAs: "3 Stücke Pizza Diavola"))
		XCTAssertFalse(MealEstimateService.isPlausibleNutrition(MealEstimate(name: "Banana", calories: 900, protein: 5, carbs: 10, fat: 3)))
		XCTAssertFalse(MealEstimateService.isPlausibleNutrition(MealEstimate(name: "Banana", calories: -1, protein: 1, carbs: 27, fat: 0)))
	}

	private func withStore(_ body: (AppStore, UserDefaults) throws -> Void) throws {
		let suite = "CutLogTests-\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suite)!
		defer { defaults.removePersistentDomain(forName: suite) }
		try body(AppStore(defaults: defaults), defaults)
	}

	func testTotalsOnlyIncludeToday() {
		let suite = "CutLogTests-\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suite)!
		defer { defaults.removePersistentDomain(forName: suite) }
		let store = AppStore(defaults: defaults)
		store.foods = [
			FoodEntry(name: "Today", calories: 500, protein: 40, carbs: 30, fat: 20, date: .now),
			FoodEntry(name: "Yesterday", calories: 999, protein: 99, carbs: 99, fat: 99, date: Calendar.current.date(byAdding: .day, value: -1, to: .now)!)
		]
		XCTAssertEqual(store.todayTotals, DailyTotals(calories: 500, protein: 40, carbs: 30, fat: 20))
	}

	// MARK: - Food search

	func testExactMatchOutranksPrefixPrefixAndSubstring() {
		let items = [
			item("banana bread", useCount: 9),
			item("banana", useCount: 1),
			item("banana protein shake", useCount: 5),
			item("bread", useCount: 7)
		]
		XCTAssertEqual(FoodSearch.search(items, query: "banana").first?.name, "banana")
		XCTAssertFalse(FoodSearch.search(items, query: "banana").contains { $0.name == "bread" })
	}

	func testQueryTokensMatchNameTokensInAnyOrder() {
		let items = [item("chicken breast"), item("breast chicken")]
		XCTAssertEqual(FoodSearch.search(items, query: "breast chicken").count, 2)
		XCTAssertEqual(FoodSearch.search(items, query: "chicken breast").count, 2)
	}

	func testEditDistanceToleratesOneTypoButNotAnUnrelatedWord() {
		let items = [item("chicken breast"), item("greek yogurt")]
		XCTAssertEqual(FoodSearch.search(items, query: "chikn").map(\.name), ["chicken breast"])
		XCTAssertTrue(FoodSearch.search(items, query: "banana").isEmpty)
		XCTAssertTrue(FoodSearch.search([item("banana")], query: "bar").isEmpty,
		              "a 3-character query must never fuzzy-hit an unrelated food")
	}

	func testExactQualifierBeatsBuriedMidNameMatch() {
		let items = [item("banana bread", useCount: 9), item("banana"),
		             item("banana protein shake", useCount: 5), item("bread", useCount: 7)]
		XCTAssertEqual(FoodSearch.search(items, query: "banana").map(\.name),
		               ["banana", "banana bread", "banana protein shake"])
		XCTAssertEqual(FoodSearch.search(items, query: "bread").map(\.name), ["bread", "banana bread"])
		XCTAssertEqual(FoodSearch.search(items, query: "banana shake").first?.name, "banana protein shake")
	}

	func testSearchIgnoresCaseDiacriticsAndPunctuation() {
		let items = [item("Crème fraîche"), item("Plain Yogurt")]
		XCTAssertEqual(FoodSearch.search(items, query: "creme fraiche").first?.name, "Crème fraîche")
		XCTAssertEqual(FoodSearch.search(items, query: "yogurt").first?.name, "Plain Yogurt")
	}

	func testEmptyQueryReturnsMostUsedFirstAndCapsResults() {
		let items = (0..<40).map { index in item("food \(index)", useCount: index) }
		let results = FoodSearch.search(items, query: "")
		XCTAssertEqual(results.first?.useCount, 39)
		XCTAssertEqual(results.count, FoodSearch.limit)
	}

	func testSearchResultsAreCappedAtLimit() {
		let items = (0..<60).map { item("oats \($0)") }
		XCTAssertEqual(FoodSearch.search(items, query: "oats").count, FoodSearch.limit)
	}

	func testEditDistanceRespectsLimitAndShortStrings() {
		XCTAssertEqual(FoodSearch.editDistance("abc", "abc", limit: 2), 0)
		XCTAssertEqual(FoodSearch.editDistance("abc", "abd", limit: 2), 1)
		XCTAssertNil(FoodSearch.editDistance("abc", "xyz", limit: 2))
		XCTAssertNil(FoodSearch.editDistance("", "abcdef", limit: 2))
		XCTAssertEqual(FoodSearch.editDistance("", "ab", limit: 2), 2)
	}

	// MARK: - Food catalog

	func testLoggingFoodCreatesCatalogItemAndCountsRepeatedUse() throws {
		try withStore { store, _ in
			store.addFood(FoodEntry(name: "Oats", calories: 370, protein: 13, carbs: 60, fat: 7))
			store.addFood(FoodEntry(name: "Oats", calories: 370, protein: 13, carbs: 60, fat: 7))
			XCTAssertEqual(store.foodCatalog.count, 1)
			XCTAssertEqual(store.foodCatalog.first?.useCount, 2)
			XCTAssertEqual(store.foodCatalog.first?.name, "Oats")
		}
	}

	func testCatalogSurvivesRelaunchAndKeepsCounters() throws {
		try withStore { store, defaults in
			store.addFood(FoodEntry(name: "Oats", calories: 370, protein: 13, carbs: 60, fat: 7))
			store.addFood(FoodEntry(name: "Eggs", calories: 155, protein: 13, carbs: 1, fat: 11))
			let reopened = AppStore(defaults: defaults)
			XCTAssertEqual(Set(reopened.foodCatalog.map(\.name)), ["Oats", "Eggs"])
			reopened.addFood(FoodEntry(name: "Oats", calories: 370, protein: 13, carbs: 60, fat: 7))
			XCTAssertEqual(reopened.foodCatalog.first { $0.name == "Oats" }?.useCount, 2)
		}
	}

	func testCatalogBackfillsFromExistingLogWithoutKey() throws {
		let suite = "CutLogTests-\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suite)!
		defer { defaults.removePersistentDomain(forName: suite) }
		let foods = [
			FoodEntry(name: "Oats", calories: 370, protein: 13, carbs: 60, fat: 7),
			FoodEntry(name: "Oats", calories: 370, protein: 13, carbs: 60, fat: 7, date: Date.now.addingTimeInterval(-60)),
			FoodEntry(name: "Eggs", calories: 155, protein: 13, carbs: 1, fat: 11)
		]
		defaults.set(try JSONEncoder().encode(foods), forKey: "foods")
		XCTAssertNil(defaults.data(forKey: "food-catalog-v1"))

		let store = AppStore(defaults: defaults)
		XCTAssertEqual(store.foodCatalog.count, 2)
		XCTAssertEqual(store.foodCatalog.first { $0.name == "Oats" }?.useCount, 2)
		XCTAssertNotNil(defaults.data(forKey: "food-catalog-v1"))
	}

	func testSameNameDifferentPortionAreDistinctCatalogItems() throws {
		try withStore { store, _ in
			store.addFood(FoodEntry(name: "Protein bar", calories: 190, protein: 20, carbs: 15, fat: 6, servingGrams: 45))
			store.addFood(FoodEntry(name: "Protein bar", calories: 380, protein: 40, carbs: 30, fat: 12, servingGrams: 90))
			XCTAssertEqual(store.foodCatalog.count, 2)
		}
	}

	func testRelabeledFoodDoesNotSplitCatalogItem() throws {
		try withStore { store, _ in
			store.addFood(FoodEntry(name: "Oats", calories: 370, protein: 13, carbs: 60, fat: 7))
			store.addFood(FoodEntry(name: "oats", calories: 380, protein: 14, carbs: 62, fat: 7))
			XCTAssertEqual(store.foodCatalog.count, 1)
			XCTAssertEqual(store.foodCatalog.first?.useCount, 2)
			XCTAssertEqual(store.foodCatalog.first?.calories, 380)
		}
	}

	func testDeletingALogKeepsTheCatalogItem() throws {
		try withStore { store, _ in
			let food = FoodEntry(name: "Oats", calories: 370, protein: 13, carbs: 60, fat: 7)
			store.addFood(food)
			store.deleteFood(food)
			XCTAssertTrue(store.foods.isEmpty)
			XCTAssertEqual(store.foodCatalog.first?.name, "Oats")
			XCTAssertEqual(store.searchFoods(query: "oats").count, 1)
		}
	}

	func testRelogNeverReusesTheOriginalDate() throws {
		try withStore { store, _ in
			let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
			store.togglePinned(FoodEntry(name: "Greek yogurt", calories: 180, protein: 20, carbs: 8, fat: 6, date: yesterday))
			let pinned = try XCTUnwrap(store.quickLogFoods.first)
			XCTAssertEqual(pinned.date, yesterday, "the pin keeps its original date")
			store.addFood(FoodCatalog.entry(from: pinned))
			let logged = try XCTUnwrap(store.foods.first)
			XCTAssertEqual(logged.calories, 180, "quick log copies macros")
			XCTAssertTrue(Calendar.current.isDateInToday(logged.date), "quick log must log today, not the pin's date")
			XCTAssertEqual(store.todayFoods.count, 1)
		}
	}

	func testReloggingACatalogItemLogsTheSamePortion() throws {
		try withStore { store, _ in
			store.addFood(FoodEntry(name: "Protein bar", calories: 190, protein: 20, carbs: 15, fat: 6, servingGrams: 45, barcode: "123"))
			let hit = try XCTUnwrap(store.searchFoods(query: "protein bar").first)
			store.addFood(hit.entry())
			let logged = try XCTUnwrap(store.foods.last)
			XCTAssertEqual(logged.servingGrams, 45)
			XCTAssertEqual(logged.barcode, "123")
			XCTAssertEqual(logged.calories, 190)
		}
	}

	func testDeletingBarcodeFoodRemovesOnlyThatCatalogItem() throws {
		try withStore { store, _ in
			store.addFood(FoodEntry(name: "Yogurt", calories: 150, protein: 15, carbs: 10, fat: 3, barcode: "111"))
			store.addFood(FoodEntry(name: "Yogurt", calories: 150, protein: 15, carbs: 10, fat: 3, barcode: "222"))
			store.togglePinned(FoodEntry(name: "Yogurt", calories: 150, protein: 15, carbs: 10, fat: 3, barcode: "111"))
			XCTAssertEqual(store.foodCatalog.count, 2)
			XCTAssertEqual(store.quickLogFoods.count, 1)
			XCTAssertEqual(store.quickLogFoods.first?.barcode, "111")
		}
	}

	// MARK: - Consistency chart

	func testConsistencyWindowIsThirtyDaysEndingToday() throws {
		try withStore { store, _ in
			let days = store.consistencyDays()
			XCTAssertEqual(days.count, 30)
			let today = Calendar.current.startOfDay(for: .now)
			XCTAssertEqual(days.last?.date, today)
			XCTAssertEqual(days.first?.date, Calendar.current.date(byAdding: .day, value: -29, to: today))
		}
	}

	func testDayCountsAsLoggedFromWeightAloneAndFoodAlone() throws {
		try withStore { store, _ in
			store.addFood(FoodEntry(name: "Oats", calories: 370, protein: 13, carbs: 60, fat: 7))
			store.addWeight(97.2)
			let days = store.consistencyDays()
			XCTAssertEqual(days.last?.logged, true, "both food and weight on today count once")
			XCTAssertEqual(days.filter(\.logged).count, 1)
		}
	}

	func testMultipleLogsOneDayProduceOneCell() throws {
		try withStore { store, _ in
			store.addFood(FoodEntry(name: "A", calories: 100, protein: 1, carbs: 1, fat: 1))
			store.addFood(FoodEntry(name: "B", calories: 100, protein: 1, carbs: 1, fat: 1))
			store.addFood(FoodEntry(name: "C", calories: 100, protein: 1, carbs: 1, fat: 1))
			XCTAssertEqual(store.consistencyDays().filter(\.logged).count, 1)
		}
	}

	func testDeletingLastLogFlipsTheCellToUnlogged() throws {
		try withStore { store, _ in
			let food = FoodEntry(name: "Oats", calories: 370, protein: 13, carbs: 60, fat: 7)
			store.addFood(food)
			store.addWeight(97.2)
			store.deleteFood(food)
			XCTAssertEqual(store.consistencyDays().last?.logged, true, "weight keeps the day logged")

			let weight = try XCTUnwrap(store.weights.last)
			store.weights.removeAll { $0.id == weight.id }
			XCTAssertEqual(store.consistencyDays().last?.logged, false)
		}
	}

	func testStreakAndChartAgreeOnTheSameInput() throws {
		try withStore { store, _ in
			let calendar = Calendar.current
			for offset in 0..<5 {
				let date = calendar.date(byAdding: .day, value: -offset, to: .now)!
				if offset.isMultiple(of: 2) {
					store.addFood(FoodEntry(name: "Meal \(offset)", calories: 500, protein: 30, carbs: 40, fat: 10, date: date))
				} else {
					store.addWeight(97 - Double(offset) * 0.1)
					if offset == 3 {
						store.weights[store.weights.count - 1].date = date
					}
				}
			}
			// Weight entries all land today, so the chart shows today plus the three food days.
			let loggedDays = store.consistencyDays().filter(\.logged).count
			XCTAssertEqual(store.loggingStreak, loggedDays)
		}
	}

	func testFutureDaysAreNotIncluded() throws {
		try withStore { store, _ in
			store.addFood(FoodEntry(name: "Tomorrow", calories: 500, protein: 30, carbs: 40, fat: 10,
			                        date: Calendar.current.date(byAdding: .day, value: 1, to: .now)!))
			XCTAssertEqual(store.consistencyDays().filter(\.logged).count, 0)
		}
	}

	// MARK: - Weight window

	func testWeightTrendIgnoresEntriesOlderThanThirtyDays() throws {
		try withStore { store, _ in
			let calendar = Calendar.current
			store.weights = (0..<40).map { offset in
				WeightEntry(kilograms: 97 - Double(offset) * 0.05,
				            date: calendar.date(byAdding: .day, value: -offset, to: .now)!)
			}
			// A stale outlier 100+ days back must not reach the dashboard window.
			store.weights.append(WeightEntry(kilograms: 130,
			                                date: calendar.date(byAdding: .day, value: -110, to: .now)!))
			let trend = store.weightTrend(days: 30)
			XCTAssertEqual(trend.count, 30)
			XCTAssertTrue(trend.allSatisfy { $0.kilograms < 100 })
			XCTAssertEqual(store.sevenDayWeightTrend.count, 40, "full history stays available")
		}
	}

	func testEmptyAndSingleEntryWindowsAreHandled() throws {
		try withStore { store, _ in
			XCTAssertTrue(store.weightTrend(days: 30).isEmpty)
			store.weights = [WeightEntry(kilograms: 97, date: .now)]
			XCTAssertEqual(store.weightTrend(days: 30).count, 1)
			store.weights = [WeightEntry(kilograms: 97, date: Calendar.current.date(byAdding: .day, value: -90, to: .now)!)]
			XCTAssertTrue(store.weightTrend(days: 30).isEmpty, "no entry in window means no line")
		}
	}

	func testSevenDayAverageStillSmoothsInsideTheWindow() throws {
        try withStore { store, _ in
			let calendar = Calendar.current
			let today = calendar.startOfDay(for: .now)
			store.weights = (0..<10).map { offset in
				WeightEntry(kilograms: 100 - Double(offset) * 0.1, date: calendar.date(byAdding: .day, value: offset, to: today)!)
			}
			let trend = store.weightTrend(days: 10)
			XCTAssertEqual(trend.count, 10)
			XCTAssertEqual(try XCTUnwrap(trend.last).kilograms, 99.1, accuracy: 0.001)
		}
	}

	// MARK: - Widget data

	func testWidgetShowsDashWhenNothingLogged() {
		let data = CutLogWidgetData(calorieGoal: 2450, days: [])
		XCTAssertNil(data.calories(on: .now), "no log means a dash, never a fake zero")
		XCTAssertNil(data.week(endingAt: .now).first?.calories)
	}

	func testWidgetUnloggedDayStaysNilNotZero() {
		let today = Calendar.current.startOfDay(for: .now)
		let data = CutLogWidgetData(calorieGoal: 2450, days: [CalorieDay(date: today, calories: 0)])
		XCTAssertEqual(data.calories(on: today), 0, "a real zero stays a real zero")
		XCTAssertNil(data.calories(on: Calendar.current.date(byAdding: .day, value: -1, to: today)!))
	}

	func testWidgetProteinIsAbsentUntilTheAppWritesIt() {
		XCTAssertNil(CutLogWidgetData(calorieGoal: 2450, days: []).protein)
		let data = CutLogWidgetData(calorieGoal: 2450, days: [], proteinGoal: 190, proteinToday: 154)
		XCTAssertEqual(data.protein?.current, 154)
		XCTAssertEqual(data.protein?.goal, 190)
		XCTAssertNil(CutLogWidgetData(calorieGoal: 2450, days: [], proteinGoal: 0, proteinToday: 10).protein,
		             "a zero goal would divide by zero")
	}

	func testWidgetCarriesAllThreeMacros() {
		let data = CutLogWidgetData(calorieGoal: 2450, days: [], proteinGoal: 190, proteinToday: 154,
		                            carbsToday: 198, fatToday: 61)
		XCTAssertEqual(data.protein?.current, 154)
		XCTAssertEqual(data.carbsToday, 198)
		XCTAssertEqual(data.fatToday, 61)
	}

	func testWidgetMissingMacrosStayNilNotZero() {
		let legacy = CutLogWidgetData(calorieGoal: 2450, days: [])
		XCTAssertNil(legacy.carbsToday)
		XCTAssertNil(legacy.fatToday)
		XCTAssertNil(legacy.protein)
	}

	func testWidgetSnapshotWrittenBeforeProteinStillDecodes() throws {
		// An App Group snapshot from the previous app version carries no protein fields.
		let legacy = CutLogWidgetData(calorieGoal: 2450, days: [CalorieDay(date: .now, calories: 1200)])
		let decoded = try JSONDecoder().decode(CutLogWidgetData.self, from: JSONEncoder().encode(legacy))
		XCTAssertEqual(decoded.calorieGoal, 2450)
		XCTAssertNil(decoded.proteinToday)
		XCTAssertNil(decoded.protein, "no protein data means no protein row")
	}

	func testWidgetWeekScalesAgainstGoalNotJustTheBusiestDay() {
		let today = Calendar.current.startOfDay(for: .now)
		let data = CutLogWidgetData(calorieGoal: 2400, days: [
			CalorieDay(date: Calendar.current.date(byAdding: .day, value: -1, to: today)!, calories: 1200),
			CalorieDay(date: today, calories: 2400)
		])
		let week = data.week(endingAt: today)
		let scale = max(data.calorieGoal, week.compactMap(\.calories).max() ?? 0, 1)
		XCTAssertEqual(scale, 2400, "goal sets the bar height, so half-goal days read as half")
	}

	func testPersistedKeysUnchangedAfterRedesign() throws {
		let suite = "CutLogTests-\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suite)!
		defer { defaults.removePersistentDomain(forName: suite) }
		let store = AppStore(defaults: defaults)
		store.settings.calorieGoal = 2300
		store.addFood(FoodEntry(name: "Oats", calories: 370, protein: 13, carbs: 60, fat: 7))
		store.addWeight(97.4)
		store.updateTemplate(.upperA)
		for key in ["foods", "weights", "settings", "training-plan-v2", "pinned-foods-v1", "workouts",
		            "active-workout-v1", "paused-workouts-v1", "food-catalog-v1"] {
			XCTAssertNotNil(defaults.data(forKey: key), "\(key) must persist under its stable name")
		}
		let reopened = AppStore(defaults: defaults)
		XCTAssertEqual(reopened.foods.count, 1)
		XCTAssertEqual(reopened.weights.count, 1)
		XCTAssertEqual(reopened.settings.calorieGoal, 2300)
	}

	func testDesignTokensAvoidRoundedFontDesign() {
		XCTAssertEqual(CutLogStyle.Number.design, .default)
	}

	func testCalorieHeadlineShowsConsumedTotalAndOverGoalState() {
		let under = CalorieHeadline(totals: DailyTotals(calories: 1200, protein: 100), goal: 2450)
		XCTAssertEqual(under.consumed, 1200, "hero shows consumed, not remaining")
		XCTAssertEqual(under.goal, 2450)
		XCTAssertFalse(under.isOverGoal)
		XCTAssertEqual(under.progress, 1200.0 / 2450, accuracy: 0.0001)

		let over = CalorieHeadline(totals: DailyTotals(calories: 2600), goal: 2450)
		XCTAssertTrue(over.isOverGoal)
		XCTAssertEqual(over.consumed, 2600, "never a negative remaining number")
		XCTAssertGreaterThan(over.progress, 1)
	}

	func testCalorieHeadlineSurvivesNonPositiveGoal() {
		let headline = CalorieHeadline(totals: DailyTotals(calories: 500), goal: 0)
		XCTAssertEqual(headline.goal, 0)
		XCTAssertEqual(headline.progress, 0)
		XCTAssertTrue(headline.isOverGoal)
	}

	// MARK: - Consistency levels

	private func levels(foods: [FoodEntry] = [], weights: [WeightEntry] = [], workouts: [WorkoutEntry] = [],
	                    days: Int = 30, now: Date = .now) -> [ConsistencyDay] {
		Consistency.levels(foods: foods, weights: weights, workouts: workouts, days: days, now: now)
	}

	/// A fixed Monday so weekday fixtures are deterministic. 5 October 2026 was a Monday.
	private var monday: Date {
		Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 5))!
	}

	/// The given weekday inside the window that ends at `now`.
	private func weekday(_ weekday: Int, now: Date, calendar: Calendar = .current) -> Date {
		let today = calendar.startOfDay(for: now)
		return calendar.date(byAdding: .day, value: (weekday - calendar.component(.weekday, from: today) + 7) % 7, to: today)!
	}

	private func calendarDayBefore(_ date: Date, days: Int = 1) -> Date {
		Calendar.current.date(byAdding: .day, value: -days, to: date)!
	}

	private func level(on date: Date, in result: [ConsistencyDay]) -> ConsistencyDay.Level? {
		result.first { Calendar.current.isDate($0.date, inSameDayAs: date) }?.level
	}

	private func completedWorkout(_ templateID: String, on date: Date) -> WorkoutEntry {
		WorkoutEntry(templateID: templateID, sets: [LoggedSet(exerciseName: "Bench Press", setNumber: 1, weightKilograms: 80, repetitions: 8)],
		             completedAt: date, startedAt: date)
	}

	func testLevelIsNoneForUnloggedDay() {
		XCTAssertEqual(levels().first?.level, ConsistencyDay.Level.none)
	}

	func testLevelIsWeightOnlyForWeightAlone() {
		let result = levels(weights: [WeightEntry(kilograms: 97)])
		XCTAssertEqual(result.last?.level, .weightOnly)
	}

	func testLevelIsFoodWhenOnlyFoodLogged() {
		let result = levels(foods: [FoodEntry(name: "Oats", calories: 370, protein: 13, carbs: 60, fat: 7)])
		XCTAssertEqual(result.last?.level, .food)
	}

	func testLevelIsTrainedWhenWorkoutOnly() {
		let day = weekday(2, now: monday)
		XCTAssertEqual(WorkoutSchedule.scheduledWorkout(on: day)?.templateID, "upper-a")
		let result = levels(workouts: [completedWorkout("upper-a", on: day)], now: monday)
		XCTAssertEqual(level(on: day, in: result), .trained)
	}

	func testLevelIsFullWhenFoodAndScheduledWorkoutBothComplete() {
		let day = weekday(2, now: monday)
		let food = FoodEntry(name: "Oats", calories: 370, protein: 13, carbs: 60, fat: 7, date: day)
		let result = levels(foods: [food], workouts: [completedWorkout("upper-a", on: day)], now: monday)
		XCTAssertEqual(level(on: day, in: result), .full, "owner-confirmed: more complete means a higher level")
	}

	func testWeightOnATrainedDayDoesNotOverrideTraining() {
		let day = weekday(2, now: monday)
		let result = levels(weights: [WeightEntry(kilograms: 97, date: day)],
		                    workouts: [completedWorkout("upper-a", on: day)], now: monday)
		XCTAssertEqual(level(on: day, in: result), .trained)
	}

	func testUnscheduledWorkoutDoesNotRaiseLevel() {
		// The Tuesday before the Monday, so it lands inside the 30-day window ending on the
		// Monday. A day outside the window would compare nil and pass vacuously.
		let tuesday = calendarDayBefore(monday, days: 6)
		XCTAssertEqual(Calendar.current.component(.weekday, from: tuesday), 3, "fixture must be a Tuesday")
		XCTAssertNil(WorkoutSchedule.scheduledWorkout(on: tuesday), "fixture must be an unscheduled weekday")
		let result = levels(workouts: [completedWorkout("upper-a", on: tuesday)], now: monday)
		XCTAssertNotNil(level(on: tuesday, in: result), "the fixture day must be inside the window")
		XCTAssertEqual(level(on: tuesday, in: result), ConsistencyDay.Level.none)
	}

	func testWrongTemplateOnAScheduledDayDoesNotCountAsTrained() {
		let day = weekday(2, now: monday) // Monday is upper-a
		let result = levels(workouts: [completedWorkout("lower-a", on: day)], now: monday)
		XCTAssertEqual(level(on: day, in: result), ConsistencyDay.Level.none)
	}

	func testWorkoutWithNoCompletedSetsDoesNotCountAsTrained() {
		let day = weekday(2, now: monday)
		let empty = WorkoutEntry(templateID: "upper-a", sets: [], completedAt: day, startedAt: day)
		let result = levels(workouts: [empty], now: monday)
		XCTAssertEqual(level(on: day, in: result), ConsistencyDay.Level.none)
	}

	func testLevelsAreOrderedAndEveryLevelExists() {
		XCTAssertEqual(ConsistencyDay.Level.allCases.map(\.rawValue), [0, 1, 2, 3, 4])
		XCTAssertLessThan(ConsistencyDay.Level.weightOnly, ConsistencyDay.Level.food)
		XCTAssertLessThan(ConsistencyDay.Level.food, ConsistencyDay.Level.trained)
		XCTAssertLessThan(ConsistencyDay.Level.trained, ConsistencyDay.Level.full)
	}

	func testWeightOnlyDayStillCountsForStreak() throws {
		try withStore { store, _ in
			store.addWeight(97.2)
			XCTAssertEqual(store.loggingStreak, 1, "levels change color only, never streak semantics")
			XCTAssertEqual(store.consistencyLevels().last?.level, .weightOnly)
			XCTAssertEqual(store.consistencyDays().last?.logged, true)
		}
	}

	func testStoreExposesThirtyLeveledDays() throws {
		try withStore { store, _ in
			XCTAssertEqual(store.consistencyLevels().count, 30)
			XCTAssertEqual(store.consistencyLevels().map(\.id), store.consistencyDays().map(\.date))
		}
	}

	// MARK: - Palette

	func testPaletteHasNoMossRemaining() throws {
		let palette = try String(contentsOf: sourceURL("Shared/CutLogPalette.swift"), encoding: .utf8)
		XCTAssertFalse(palette.contains("0.39, green: 0.45, blue: 0.35"),
		               "the old moss accent must not come back")
		let style = try String(contentsOf: sourceURL("Shared/CutLogStyle.swift"), encoding: .utf8)
		XCTAssertFalse(style.contains("CutLogStyle.accent"))
		XCTAssertFalse(style.contains("design: .rounded"), "the rounded font look stays gone")
	}

	func testSemanticRedIsNotUsedForDecoration() throws {
		let source = try String(contentsOf: sourceURL("CutLog/TodayView.swift"), encoding: .utf8)
		// Red may tint the over-goal numeral and the over-goal bar, never a surface or fill.
		XCTAssertFalse(source.contains("background(Color.red"))
		XCTAssertFalse(source.contains("fill(Color.red"))
		XCTAssertFalse(source.contains("foregroundStyle(Color.red).background"))
		XCTAssertTrue(source.contains("Color.red"), "over goal still signals with red")
	}

	func testConsistencyGridUsesOnlyTwoHues() throws {
		let source = try String(contentsOf: sourceURL("Shared/CutLogPalette.swift"), encoding: .utf8)
		let ramp = source.components(separatedBy: "static func consistency")[1]
		XCTAssertTrue(ramp.contains("apricot"))
		XCTAssertTrue(ramp.contains("sage"))
		XCTAssertFalse(ramp.contains("periwinkle"),
		               "periwinkle is protein-only and must not enter the grid")
	}

	// MARK: - History

	func testRangeChipsCoverThirtyNinetyAndAll() {
		XCTAssertEqual(WeightRange.allCases.map(\.title), ["30 days", "90 days", "All"])
		XCTAssertEqual(WeightRange.thirtyDays.days, 30)
		XCTAssertEqual(WeightRange.ninetyDays.days, 90)
		XCTAssertNil(WeightRange.all.days, "All means no lower bound")
	}

	func testThirtyDayRangeExcludesOlderWeighIns() {
		let calendar = Calendar.current
		let start = WeightRange.thirtyDays.start(endingAt: .now)
		XCTAssertEqual(start, calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: .now)))
		let stale = calendar.date(byAdding: .day, value: -110, to: .now)!
		XCTAssertLessThan(stale, start!, "the >100-day entry stays out of the 30-day range")
		XCTAssertNil(WeightRange.all.start(endingAt: .now))
	}

	func testWorkoutRowUsesLoggedSetsNotTemplateCount() {
		let day = Calendar.current.startOfDay(for: .now)
		let partial = WorkoutEntry(templateID: "upper-a", sets: [
			LoggedSet(exerciseName: "Bench", setNumber: 1, weightKilograms: 80, repetitions: 8)
		], completedAt: day, startedAt: day, templateTitle: "Upper A",
		 setRecords: [WorkoutSetDraft(id: "a", exerciseName: "Bench", setNumber: 1, weight: "80", reps: "8", rir: "2", isComplete: true),
		             WorkoutSetDraft(id: "b", exerciseName: "Bench", setNumber: 2, isComplete: false)])
		XCTAssertEqual(partial.completedSetCount, 1, "one ticked set is one set, not two template sets")
		XCTAssertEqual(partial.templateTitle, "Upper A")
	}

	func testWorkoutRowOmitsMissingFieldsRatherThanShowingZero() {
		let empty = WorkoutEntry(templateID: "upper-a", sets: [], completedAt: .now, startedAt: .now)
		XCTAssertEqual(empty.completedSetCount, 0)
		XCTAssertTrue(empty.sets.isEmpty, "no invented numbers")
	}

	// MARK: - Helpers

	private func sourceURL(_ path: String) -> URL {
		URL(fileURLWithPath: #filePath)
			.deletingLastPathComponent()   // CutLogTests
			.deletingLastPathComponent()   // repo root
			.appendingPathComponent(path)
	}

	private func item(_ name: String, useCount: Int = 1) -> FoodCatalogItem {
		let food = FoodEntry(name: name, calories: 200, protein: 10, carbs: 20, fat: 5)
		var catalogItem = FoodCatalogItem(food: food, id: FoodCatalog.key(for: food))
		catalogItem.useCount = useCount
		return catalogItem
	}
}
