import Foundation

/// URLSession-based API client. Attaches the bearer token, and on a 401 performs
/// a single silent refresh via /api/auth/refresh then retries — the same pattern
/// as Android's OkHttp AuthInterceptor + Authenticator.
final class APIClient {
    static let shared = APIClient()
    private let base = AppEnv.apiBase
    private let session = URLSession(configuration: .default)
    private let store = KeychainStore.shared

    enum APIError: Error, LocalizedError {
        case http(Int, String?)
        case network
        var errorDescription: String? {
            switch self {
            case .http(_, let msg): return msg ?? "Something went wrong. Try again."
            case .network: return "Network error. Try again."
            }
        }
    }

    // MARK: Core request
    private func request(_ method: String, _ path: String, body: Data? = nil, auth: Bool = false, retryOn401: Bool = true) async throws -> Data {
        guard let url = URL(string: base + path) else { throw APIError.network }
        var req = URLRequest(url: url)
        req.httpMethod = method
        if let body { req.httpBody = body; req.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        if auth, let token = store.accessToken { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }

        let (data, resp): (Data, URLResponse)
        do { (data, resp) = try await session.data(for: req) }
        catch { throw APIError.network }
        guard let http = resp as? HTTPURLResponse else { throw APIError.network }

        if http.statusCode == 401 && auth && retryOn401 {
            if try await refresh() {
                return try await request(method, path, body: body, auth: true, retryOn401: false)
            }
        }
        if !(200...299).contains(http.statusCode) {
            let msg = (try? JSONDecoder().decode(ErrorResponse.self, from: data))?.error
            throw APIError.http(http.statusCode, msg)
        }
        return data
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: Auth
    func otpStatus() async -> Bool {
        guard let d = try? await request("GET", "/api/public/otp-status"),
              let r: OtpStatusResponse = try? decode(d) else { return true } // fail safe → require OTP
        return r.enabled
    }

    func appConfig() async -> AppConfig? {
        guard let d = try? await request("GET", "/api/public/app-config") else { return nil }
        return try? decode(d)
    }

    func phoneLogin(phone: String) async throws -> AuthResponse {
        let body = try JSONSerialization.data(withJSONObject: ["phone": phone])
        return try decode(try await request("POST", "/api/auth/phone-login", body: body))
    }

    func sendOtp(phone: String) async throws -> SendOtpResponse {
        let body = try JSONSerialization.data(withJSONObject: ["phone": phone])
        return try decode(try await request("POST", "/api/auth/send-otp", body: body))
    }

    func verifyOtp(phone: String, otp: String, eventId: String) async throws -> AuthResponse {
        let body = try JSONSerialization.data(withJSONObject: [
            "phone": phone, "otp": otp, "eventId": eventId, "sourceUrl": "ios:live.vipchat.app",
        ])
        return try decode(try await request("POST", "/api/auth/verify-otp", body: body))
    }

    @discardableResult
    func refresh() async throws -> Bool {
        guard let token = store.refreshToken else { return false }
        let body = try JSONSerialization.data(withJSONObject: ["refresh": token])
        do {
            let d = try await request("POST", "/api/auth/refresh", body: body, auth: false, retryOn401: false)
            let r: RefreshResponse = try decode(d)
            store.accessToken = r.access
            store.refreshToken = r.refresh
            return true
        } catch {
            store.clear()
            return false
        }
    }

    /// Cheap authenticated call to trip the 401→refresh before the socket handshake,
    /// so the socket always connects with a live JWT (mirrors Android's /api/auth/me use).
    func warmToken() async { _ = try? await request("POST", "/api/auth/me", auth: true) }

    // MARK: Messages
    func getMessages(_ conversationId: String, before: String?) async throws -> [ChatMessage] {
        var path = "/api/messages/\(conversationId)"
        if let before { path += "?before=\(before)" }
        return try decode(try await request("GET", path, auth: true))
    }

    // MARK: Device token (push)
    func registerDeviceToken(_ token: String) async {
        let body = try? JSONSerialization.data(withJSONObject: ["token": token])
        _ = try? await request("POST", "/api/users/me/device-token", body: body, auth: true)
    }
    func unregisterDeviceToken(_ token: String) async {
        let body = try? JSONSerialization.data(withJSONObject: ["token": token])
        // DELETE with body
        guard let url = URL(string: base + "/api/users/me/device-token") else { return }
        var req = URLRequest(url: url); req.httpMethod = "DELETE"
        req.httpBody = body; req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let t = store.accessToken { req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        _ = try? await session.data(for: req)
    }

    // MARK: Upload (multipart)
    func upload(fileURL: URL, mimeType: String) async throws -> UploadResponse {
        guard let url = URL(string: base + "/api/upload") else { throw APIError.network }
        var req = URLRequest(url: url); req.httpMethod = "POST"
        if let t = store.accessToken { req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        let boundary = "Boundary-\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var data = Data()
        let filename = fileURL.lastPathComponent
        let fileData = try Data(contentsOf: fileURL)
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        data.append(fileData)
        data.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = data
        let (respData, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.http((resp as? HTTPURLResponse)?.statusCode ?? 0, "Upload failed")
        }
        return try decode(respData)
    }
}
