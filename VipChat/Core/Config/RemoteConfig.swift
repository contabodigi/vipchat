import Foundation

/// Remote configuration from GET /api/public/app-config — lets Meta App ID,
/// force-update floor, and TURN servers change server-side with no app update.
/// Cached in UserDefaults for instant/offline startup, then refreshed.
final class RemoteConfig {
    static let shared = RemoteConfig()
    private let key = "app_config_json"

    private(set) var current = AppConfig()

    func loadCached() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let cfg = try? JSONDecoder().decode(AppConfig.self, from: data) else { return }
        current = cfg
    }

    func refresh() async {
        guard let cfg = await APIClient.shared.appConfig() else { return }
        current = cfg
        if let data = try? JSONEncoder().encode(cfg) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    /// True when the server requires a newer build than this one.
    var needsForceUpdate: Bool {
        let build = Int(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1") ?? 1
        return current.minVersion > build
    }
}
