import XCTest
@testable import CutLog

final class CutLogTests: XCTestCase {
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
