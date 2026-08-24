import Foundation

// Base URL for the vipchat.live backend (same contract as Android/web).
enum AppEnv {
    static let apiBase = "https://vipchat.live"
    // TURN fallback if remote config has none (mirrors Android BuildConfig defaults).
    static let turnUrl = "turn:72.62.212.246:3478"
    static let turnUser = "chat247turn"
    static let turnCredential = "340cb88f018f3a762425f67818caa1e4"
}

// MARK: - Auth (mirrors backend/routes/auth.js: { ...user.toPublic(), ...tokens })
struct AuthResponse: Codable {
    let id: String
    let name: String?
    let email: String?
    let role: String?
    let branch: String?
    let access: String
    let refresh: String
}

struct OtpStatusResponse: Codable { let enabled: Bool }
struct SendOtpResponse: Codable { let success: Bool?; let message: String? }
struct RefreshResponse: Codable { let access: String; let refresh: String }
struct ErrorResponse: Codable { let error: String? }
struct UploadResponse: Codable {
    let url: String
    let name: String?
    let size: Int?
    let mimeType: String?
    let msgType: String?
}

// MARK: - Remote config (GET /api/public/app-config)
struct MetaConfig: Codable {
    var appId: String = ""
    var clientToken: String = ""
    var enabled: Bool = false
}
struct TurnServer: Codable {
    var urls: String = ""
    var username: String = ""
    var credential: String = ""
}
struct AppConfig: Codable {
    var meta: MetaConfig = MetaConfig()
    var minVersion: Int = 1
    var turn: [TurnServer] = []
    var features: [String: Bool] = [:]
}
