import Foundation
import FirebaseMessaging
import UIKit

/// FCM push registration against POST/DELETE /api/users/me/device-token.
/// On iOS, Firebase routes through APNs — the AppDelegate registers for remote
/// notifications and hands the APNs token to Firebase, which returns an FCM token.
final class PushManager: NSObject, MessagingDelegate {
    static let shared = PushManager()

    func register() {
        Messaging.messaging().delegate = self
        Messaging.messaging().token { token, _ in
            guard let token else { return }
            Task { await APIClient.shared.registerDeviceToken(token) }
        }
    }

    func unregister() {
        Messaging.messaging().token { token, _ in
            guard let token else { return }
            Task { await APIClient.shared.unregisterDeviceToken(token) }
        }
    }

    /// FCM rotates tokens — re-register whenever a new one arrives.
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken, KeychainStore.shared.isLoggedIn else { return }
        Task { await APIClient.shared.registerDeviceToken(fcmToken) }
    }

    /// Ask the user for notification permission, then register with APNs.
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async { UIApplication.shared.registerForRemoteNotifications() }
        }
    }
}
