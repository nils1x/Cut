import Foundation

enum WidgetSnapshot {

    static func write(from store: AppStore) {
        let totals = store.todayTotals
        let data = CutLogWidgetData(
            caloriesLeft: store.settings.calorieGoal - totals.calories,
            calorieGoal: store.settings.calorieGoal,
            protein: totals.protein,
            proteinGoal: store.settings.proteinGoal,
            workoutTitle: store.nextWorkout.title,
            workoutDue: store.workoutIsDue
        )
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        UserDefaults(suiteName: CutLogWidgetStore.suiteName)?.set(encoded, forKey: CutLogWidgetStore.key)
    }
}
