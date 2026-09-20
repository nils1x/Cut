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

	func testPinnedFoodsArePersistedAndExcludedFromRecents() throws {
		try withStore { store, defaults in
			let pinned = FoodEntry(name: "Greek yogurt", calories: 180, protein: 20, carbs: 8, fat: 6)
			let recent = FoodEntry(name: "Oats", calories: 370, protein: 13, carbs: 60, fat: 7, date: Date.now.addingTimeInterval(-60))
			store.addFood(pinned)
			store.addFood(recent)
			store.togglePinned(pinned)

			XCTAssertEqual(store.quickLogFoods.map(\.name), ["Greek yogurt"])
			XCTAssertEqual(store.recentFoods.map(\.name), ["Oats"])
			XCTAssertTrue(store.isPinned(pinned))

			let reopened = AppStore(defaults: defaults)
			XCTAssertEqual(reopened.quickLogFoods.map(\.name), ["Greek yogurt"])
			reopened.togglePinned(FoodEntry(name: "Greek yogurt", calories: 180, protein: 20, carbs: 8, fat: 6))
			XCTAssertTrue(reopened.quickLogFoods.isEmpty)
			XCTAssertEqual(reopened.recentFoods.map(\.name), ["Greek yogurt", "Oats"])
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
}
