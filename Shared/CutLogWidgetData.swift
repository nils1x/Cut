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

    func caloriesLeft(on date: Date, calendar: Calendar = .current) -> Int {
        calorieGoal - (days.first { calendar.isDate($0.date, inSameDayAs: date) }?.calories ?? 0)
    }

    func week(endingAt date: Date, calendar: Calendar = .current) -> [CalorieDay] {
        let end = calendar.startOfDay(for: date)
        return (-6...0).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: end) else { return nil }
            return CalorieDay(date: day, calories: days.first { calendar.isDate($0.date, inSameDayAs: day) }?.calories)
        }
    }
}

enum CutLogWidgetStore {
    static let suiteName = "group.com.nils.CutLog"
    static let key = "widget-data"
}
