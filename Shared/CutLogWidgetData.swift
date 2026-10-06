import Foundation

struct CalorieDay: Codable, Identifiable, Equatable {
	let date: Date
	// nil means nothing logged, not a measured zero-calorie day.
	let calories: Int?
	var id: Date { date }
}

struct CutLogWidgetData: Codable {
	let calorieGoal: Int
	let days: [CalorieDay]
	// Optional so snapshots written before these existed still decode.
	let proteinGoal: Int?
	let proteinToday: Int?
	let carbsToday: Int?
	let fatToday: Int?

	init(calorieGoal: Int, days: [CalorieDay], proteinGoal: Int? = nil, proteinToday: Int? = nil,
	     carbsToday: Int? = nil, fatToday: Int? = nil) {
		self.calorieGoal = calorieGoal
		self.days = days
		self.proteinGoal = proteinGoal
		self.proteinToday = proteinToday
		self.carbsToday = carbsToday
		self.fatToday = fatToday
	}

	func caloriesLeft(on date: Date, calendar: Calendar = .current) -> Int {
		calorieGoal - (days.first { calendar.isDate($0.date, inSameDayAs: date) }?.calories ?? 0)
	}

	func calories(on date: Date, calendar: Calendar = .current) -> Int? {
		days.first { calendar.isDate($0.date, inSameDayAs: date) }?.calories
	}

	func week(endingAt date: Date, calendar: Calendar = .current) -> [CalorieDay] {
		let end = calendar.startOfDay(for: date)
		return (-6...0).compactMap { offset in
			guard let day = calendar.date(byAdding: .day, value: offset, to: end) else { return nil }
			return CalorieDay(date: day, calories: days.first { calendar.isDate($0.date, inSameDayAs: day) }?.calories)
		}
	}

	/// Protein for the medium widget. nil when the app has not written it yet.
	var protein: (current: Int, goal: Int)? {
		guard let proteinGoal, let proteinToday, proteinGoal > 0 else { return nil }
		return (proteinToday, proteinGoal)
	}
}

enum CutLogWidgetStore {
	static let suiteName = "group.com.nils.CutLog"
	static let key = "widget-data"
}
