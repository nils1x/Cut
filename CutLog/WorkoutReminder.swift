import Foundation
import UserNotifications

@MainActor
enum WorkoutReminder {
    static let identifier = "workout-due"

    static func refresh(isDue: Bool, enabled: Bool) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard enabled, isDue else { return }

        let allowed = try? await center.requestAuthorization(options: [.alert, .sound])
        guard allowed == true else { return }

        var components = DateComponents()
        components.hour = 18
        let content = UNMutableNotificationContent()
        content.title = "Training is due"
        content.body = "Full body. In, out, done."
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        try? await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }
}
