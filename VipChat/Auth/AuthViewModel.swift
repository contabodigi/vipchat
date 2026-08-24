import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    enum Step { case phone, otp }

    @Published var step: Step = .phone
    @Published var phone = ""
    @Published var otp = ""
    @Published var loading = false
    @Published var error: String?
    @Published var skipOtp: Bool?          // nil until /otp-status resolves
    @Published var resendSeconds = 0
    @Published var loggedIn = false

    private let api = APIClient.shared
    private let store = KeychainStore.shared
    private var resendTask: Task<Void, Never>?

    func loadOtpStatus() {
        Task { skipOtp = !(await api.otpStatus()) }
    }

    private func isValid(_ p: String) -> Bool {
        p.range(of: "^[6-9][0-9]{9}$", options: .regularExpression) != nil
    }

    func submitPhone() {
        let clean = phone.filter(\.isNumber)
        guard isValid(clean) else {
            error = "Enter a valid 10-digit mobile number starting with 6, 7, 8 or 9"; return
        }
        error = nil
        if skipOtp == true { directLogin(clean) } else { sendOtp(clean) }
    }

    private func directLogin(_ phone: String) {
        loading = true
        Task {
            defer { loading = false }
            do { complete(try await api.phoneLogin(phone: phone), eventId: nil) }
            catch { self.error = (error as? APIClient.APIError)?.errorDescription ?? "Try again." }
        }
    }

    private func sendOtp(_ phone: String) {
        loading = true
        Task {
            defer { loading = false }
            do {
                let r = try await api.sendOtp(phone: phone)
                if r.success == true { step = .otp; otp = ""; startResend() }
                else { error = r.message ?? "Failed to send OTP." }
            } catch { self.error = (error as? APIClient.APIError)?.errorDescription ?? "Try again." }
        }
    }

    func resend() { guard resendSeconds == 0 else { return }; sendOtp(phone.filter(\.isNumber)) }

    func submitOtp() {
        let code = otp.filter(\.isNumber)
        guard code.count == 6 else { error = "Enter all 6 digits"; return }
        let clean = phone.filter(\.isNumber)
        let eventId = UUID().uuidString
        loading = true
        Task {
            defer { loading = false }
            do { complete(try await api.verifyOtp(phone: clean, otp: code, eventId: eventId), eventId: eventId) }
            catch {
                self.error = (error as? APIClient.APIError)?.errorDescription ?? "Invalid OTP. Try again."
                otp = ""
            }
        }
    }

    func changeNumber() { step = .phone; error = nil; otp = ""; resendTask?.cancel() }

    private func complete(_ r: AuthResponse, eventId: String?) {
        store.saveSession(access: r.access, refresh: r.refresh, userId: r.id, branchId: r.branch)
        MetaEvents.logLead(eventId: eventId)   // only after successful login, like the web
        loggedIn = true
    }

    private func startResend() {
        resendTask?.cancel()
        resendSeconds = 60
        resendTask = Task {
            while resendSeconds > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                resendSeconds -= 1
            }
        }
    }
}
