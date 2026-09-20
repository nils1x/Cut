import Foundation
import WidgetKit

@MainActor
enum WidgetSnapshot {
    static func write(from store: AppStore) {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: .now))!
        let groups = Dictionary(grouping: store.foods.filter { $0.date >= start }) { calendar.startOfDay(for: $0.date) }
        let data = CutLogWidgetData(calorieGoal: store.settings.calorieGoal,
            days: groups.map { day, foods in CalorieDay(date: day, calories: foods.reduce(0) { $0 + $1.calories }) }.sorted { $0.date < $1.date })
        guard let encoded = try? JSONEncoder().encode(data),
              let defaults = UserDefaults(suiteName: CutLogWidgetStore.suiteName) else { return }
        defaults.set(encoded, forKey: CutLogWidgetStore.key)
        WidgetCenter.shared.reloadTimelines(ofKind: "CutLogWidget")
    }
}
