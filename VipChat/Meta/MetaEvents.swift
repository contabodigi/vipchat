import Foundation
import FacebookCore

/// Meta App Events, initialized PROGRAMMATICALLY from remote config (not Info.plist)
/// so the Facebook App ID / Client Token can change server-side with no app update.
/// Mirrors the Android MetaEvents: the Lead event fires only after a successful login.
enum MetaEvents {
    private static var initialized = false

    static func initFrom(_ meta: MetaConfig) {
        guard !initialized else { return }
        let id = meta.appId.trimmingCharacters(in: .whitespaces)
        guard meta.enabled, !id.isEmpty, !id.hasPrefix("0000") else { return }
        Settings.shared.appID = id
        if !meta.clientToken.isEmpty { Settings.shared.clientToken = meta.clientToken }
        ApplicationDelegate.shared.initializeSDK()
        initialized = true
    }

    static func logLead(eventId: String?) {
        guard initialized else { return }
        var params: [AppEvents.ParameterName: Any] = [:]
        if let eventId { params[AppEvents.ParameterName("event_id")] = eventId }
        AppEvents.shared.logEvent(AppEvents.Name("Lead"), parameters: params)
    }
}
