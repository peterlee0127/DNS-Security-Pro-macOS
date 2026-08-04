import Foundation
import UserNotifications

final class AppNotificationService {
  static let shared = AppNotificationService()

  private init() {}

  func requestAuthorization() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
  }

  func notifyDNSFailure(title: String, message: String) {
    guard UserDefaults.standard.bool(forKey: AppPreferenceKey.notifiesDNSFailures) else {
      return
    }

    let content = UNMutableNotificationContent()
    content.title = title
    content.body = message
    content.sound = .default
    let request = UNNotificationRequest(
      identifier: "dns-failure-\(UUID().uuidString)",
      content: content,
      trigger: nil
    )
    UNUserNotificationCenter.current().add(request)
  }
}
