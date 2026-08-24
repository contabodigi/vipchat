import Foundation
import FirebaseCore
import FirebaseMessaging
import UIKit

/// FCM push registration against POST/DELETE /api/users/me/device-token.
/// On iOS, Firebase routes through APNs — the AppDelegate registers for remote
/// notifications and hands the APNs token to Firebase, which returns an FCM token.
///
/// Every entry point checks FirebaseApp.app() first: until a real
/// GoogleService-Info.plist is bundled, Firebase never configures and calling
/// Messaging.messaging() would CRASH — so push is a silent no-op until then
/// (mirrors the Android FirebaseApp.getApps() gating).
final class PushManager: NSObject, MessagingDelegate {
    static let shared = PushManager()

    private var firebaseReady: Bool { FirebaseApp.app() != nil }

    func register() {
        guard firebaseReady else { return }
        Messaging.messaging().delegate = self
        Messaging.messaging().token { token, _ in
            guard let token else { return }
            Task { await APIClient.shared.registerDeviceToken(token) }
        }
    }

    func unregister() {
        guard firebaseReady else { return }
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
    /// Skipped entirely until Firebase is configured, so the app doesn't prompt
    /// for notifications it can't yet deliver.
    func requestAuthorization() {
        guard firebaseReady else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async { UIApplication.shared.registerForRemoteNotifications() }
        }
    }
}
