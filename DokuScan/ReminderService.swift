import Foundation
import UserNotifications

enum ReminderService {
    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])) ?? false
    }

    static func schedule(for record: SavedRecord) async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
        for (label, date) in [("Rückgabefrist", record.returnDeadline), ("Garantieende", record.warrantyEnd)] {
            guard let date, date > Date() else { continue }
            let offsetDays = label == "Rückgabefrist" ? -3 : -30
            let advance = Calendar.current.date(byAdding: .day, value: offsetDays, to: date) ?? date
            let alertDate = advance > Date() ? advance : date
            let content = UNMutableNotificationContent()
            content.title = "Scanchris: \(label)"
            content.body = "\(record.filename) – Termin: \(FileNaming.format(date, pattern: "dd.MM.yyyy"))"
            content.sound = .default
            var parts = Calendar.current.dateComponents([.year, .month, .day], from: alertDate)
            parts.hour = 9
            parts.minute = 0
            let request = UNNotificationRequest(identifier: record.id.uuidString + "-" + label,
                                                 content: content,
                                                 trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false))
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    static func cancel(for record: SavedRecord) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
            record.id.uuidString + "-Rückgabefrist", record.id.uuidString + "-Garantieende"
        ])
    }
}
