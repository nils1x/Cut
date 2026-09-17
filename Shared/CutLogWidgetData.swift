import Foundation

struct CutLogWidgetData: Codable {
    let caloriesLeft: Int
    let calorieGoal: Int
    let protein: Int
    let proteinGoal: Int
    let workoutTitle: String
    let workoutDue: Bool
}

enum CutLogWidgetStore {
    static let suiteName = "group.com.nils.CutLog"
    static let key = "widget-data"
}
