import Foundation
import Security

/// Secure session storage in the iOS Keychain — the direct analog of Android's
/// EncryptedSharedPreferences. Access + refresh tokens are bearer secrets and
/// must never sit in plain UserDefaults.
final class KeychainStore {
    static let shared = KeychainStore()
    private let service = "live.vipchat.app.session"

    private func set(_ key: String, _ value: String?) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                     kSecAttrService as String: service,
                                     kSecAttrAccount as String: key]
        SecItemDelete(query as CFDictionary)
        guard let value, let data = value.data(using: .utf8) else { return }
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }

    private func get(_ key: String) -> String? {
        var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                     kSecAttrService as String: service,
                                     kSecAttrAccount as String: key,
                                     kSecReturnData as String: true,
                                     kSecMatchLimit as String: kSecMatchLimitOne]
        var out: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    var accessToken: String? {
        get { get("access") } set { set("access", newValue) }
    }
    var refreshToken: String? {
        get { get("refresh") } set { set("refresh", newValue) }
    }
    var userId: String? {
        get { get("userId") } set { set("userId", newValue) }
    }
    var branchId: String? {
        get { get("branchId") } set { set("branchId", newValue) }
    }

    var isLoggedIn: Bool { !(accessToken ?? "").isEmpty }

    func saveSession(access: String, refresh: String, userId: String, branchId: String?) {
        self.accessToken = access
        self.refreshToken = refresh
        self.userId = userId
        self.branchId = branchId
    }

    func clear() {
        accessToken = nil; refreshToken = nil; userId = nil; branchId = nil
    }
}
