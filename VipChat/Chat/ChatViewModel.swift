import Foundation
import AVFoundation
import UIKit

@MainActor
final class ChatViewModel: NSObject, ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var composerText = ""
    @Published var connected = false
    @Published var everConnected = false
    @Published var typingUser: String?
    @Published var handoverAdminName: String?
    @Published var blockedMessage: String?
    @Published var uploading = false
    @Published var recording = false
    @Published var replyingTo: ChatMessage?
    @Published var conversationId: String?
    @Published var sessionExpired = false
    @Published var error: String?

    private let socket = SocketManager.shared
    private let api = APIClient.shared
    private let store = KeychainStore.shared
    private var pushRegistered = false
    private var typingTask: Task<Void, Never>?
    private var isTyping = false
    private var lastAuthRetry = Date.distantPast

    private var recorder: AVAudioRecorder?
    private var voiceURL: URL?

    private let staffRoles: Set<String> = ["agent", "branch_admin", "superadmin", "bot"]

    func start() {
        wireSocket()
        Task {
            guard store.accessToken != nil, store.userId != nil else { sessionExpired = true; return }
            await api.warmToken()                       // trip refresh before handshake
            guard let token = store.accessToken else { sessionExpired = true; return }
            socket.connect(token: token)
        }
    }

    private func wireSocket() {
        socket.onConnected = { [weak self] up in
            guard let self else { return }
            Task { @MainActor in
                self.connected = up
                if up { self.everConnected = true }
                guard up, let cid = self.store.userId else { return }
                self.socket.initConversation(customerId: cid, branchId: self.store.branchId)
                if !self.pushRegistered { self.pushRegistered = true; PushManager.shared.register() }
            }
        }
        socket.onAuthError = { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                if Date().timeIntervalSince(self.lastAuthRetry) < 15 { return }
                self.lastAuthRetry = Date()
                await self.api.warmToken()
                if let token = self.store.accessToken { self.socket.reconnect(token: token) }
                else { self.sessionExpired = true }
            }
        }
        socket.onConversationCreated = { [weak self] conv, msgs in
            Task { @MainActor in self?.conversationId = conv.id; self?.messages = msgs }
        }
        socket.onMessagesInitial = { [weak self] cid, msgs in
            Task { @MainActor in
                if let cid { self?.conversationId = cid }
                self?.messages = msgs
                if let c = self?.conversationId { self?.socket.markRead(c) }
            }
        }
        socket.onMessageNew = { [weak self] m in
            Task { @MainActor in self?.receive(m) }
        }
        socket.onMessageEdited = { [weak self] id, text in
            Task { @MainActor in self?.patch(id) { $0.text = text; $0.edited = true } }
        }
        socket.onMessageDeleted = { [weak self] id in
            Task { @MainActor in self?.patch(id) { $0.deleted = true; $0.text = "" } }
        }
        socket.onMessageReacted = { [weak self] id, reactions in
            Task { @MainActor in self?.patch(id) { $0.reactions = reactions } }
        }
        socket.onMessagesRead = { [weak self] by in
            Task { @MainActor in
                guard by != "customer" else { return }
                self?.messages = self?.messages.map { m in
                    var m = m; if m.senderRole == "customer" && m.status != "read" { m.status = "read" }; return m
                } ?? []
            }
        }
        socket.onTyping = { [weak self] typing, user in
            Task { @MainActor in self?.typingUser = typing ? (user ?? "Support") : nil }
        }
        socket.onHandover = { [weak self] assigned, name in
            Task { @MainActor in if assigned { self?.handoverAdminName = name } }
        }
        socket.onBlocked = { [weak self] msg in
            Task { @MainActor in self?.blockedMessage = msg ?? "You have been blocked from this service." }
        }
    }

    private func receive(_ m: ChatMessage) {
        if let cid = m.clientId, let idx = messages.firstIndex(where: { $0.localId == cid }) {
            messages[idx] = m                                   // reconcile optimistic bubble
        } else if !messages.contains(where: { $0.id == m.id }) {
            messages.append(m)
        }
        if staffRoles.contains(m.senderRole ?? ""), let c = conversationId { socket.markRead(c) }
    }

    private func patch(_ id: String, _ change: (inout ChatMessage) -> Void) {
        messages = messages.map { var m = $0; if m.id == id { change(&m) }; return m }
    }

    // MARK: send
    func sendText() {
        guard let cid = conversationId else { return }
        let text = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let reply = replyingTo?.id
        composerText = ""; replyingTo = nil
        stopTypingNow(cid)
        dispatch(cid, text: text, replyTo: reply)
    }

    private func dispatch(_ cid: String, text: String, replyTo: String?) {
        let clientId = UUID().uuidString
        var msg = ChatMessage(id: clientId)
        msg.conversation = cid; msg.senderRole = "customer"; msg.text = text; msg.type = "text"
        msg.replyTo = replyTo; msg.status = "sent"; msg.localId = clientId; msg.pending = true
        msg.createdAt = ISO8601DateFormatter().string(from: Date())
        messages.append(msg)

        guard socket.isConnected else { markFailed(clientId); return }
        socket.sendMessage(conversationId: cid, text: text, replyTo: replyTo, clientId: clientId)
        scheduleTimeout(clientId)
    }

    private func scheduleTimeout(_ clientId: String) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 12_000_000_000)
            if messages.contains(where: { $0.localId == clientId && $0.pending }) { markFailed(clientId) }
        }
    }
    private func markFailed(_ clientId: String) {
        messages = messages.map { var m = $0; if m.localId == clientId { m.pending = false; m.failed = true }; return m }
    }
    func retry(_ m: ChatMessage) {
        guard let cid = conversationId, let clientId = m.localId else { return }
        messages = messages.map { var x = $0; if x.localId == clientId { x.pending = true; x.failed = false }; return x }
        guard socket.isConnected else { markFailed(clientId); return }
        socket.sendMessage(conversationId: cid, text: m.text, replyTo: m.replyTo, clientId: clientId)
        scheduleTimeout(clientId)
    }

    func react(_ messageId: String, _ emoji: String) { socket.react(messageId: messageId, emoji: emoji) }
    func setReply(_ m: ChatMessage?) { replyingTo = m }

    func onBotButton(_ b: BotButton) {
        guard let cid = conversationId else { return }
        switch b.action {
        case "human": socket.requestHuman(cid)
        case "text": if let v = b.value { socket.sendMessage(conversationId: cid, text: v) }
        case "url": if let v = b.value, let url = URL(string: v) { UIApplication.shared.open(url) }
        default: break
        }
    }

    // MARK: typing
    func onTextChange() {
        guard let cid = conversationId else { return }
        if !isTyping { isTyping = true; socket.startTyping(cid) }
        typingTask?.cancel()
        typingTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if Task.isCancelled { return }
            isTyping = false; socket.stopTyping(cid)
        }
    }
    private func stopTypingNow(_ cid: String) { typingTask?.cancel(); isTyping = false; socket.stopTyping(cid) }

    func onForeground() { if let c = conversationId { socket.markRead(c) } }

    func loadOlder() {
        guard let cid = conversationId, let oldest = messages.first?.id else { return }
        Task {
            if let older = try? await api.getMessages(cid, before: oldest), !older.isEmpty {
                messages = older + messages
            }
        }
    }

    // MARK: media
    func sendMedia(url: URL, mimeType: String) {
        guard let cid = conversationId else { return }
        uploading = true
        Task {
            defer { uploading = false }
            do {
                let r = try await api.upload(fileURL: url, mimeType: mimeType)
                socket.sendMessage(conversationId: cid, type: r.msgType ?? "file",
                                   fileUrl: r.url, fileName: r.name, fileSize: r.size, mimeType: r.mimeType)
            } catch { self.error = "Upload failed. Try again." }
        }
    }

    // MARK: voice notes
    func startRecording() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default)
        try? session.setActive(true)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("voice_\(Int(Date().timeIntervalSince1970)).m4a")
        let settings: [String: Any] = [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1]
        recorder = try? AVAudioRecorder(url: url, settings: settings)
        if recorder?.record() == true { voiceURL = url; recording = true }
    }
    func stopRecordingAndSend() {
        recorder?.stop(); recording = false
        guard let url = voiceURL, let cid = conversationId else { return }
        uploading = true
        Task {
            defer { uploading = false }
            do {
                let r = try await api.upload(fileURL: url, mimeType: "audio/mp4")
                socket.sendMessage(conversationId: cid, type: "voice", fileUrl: r.url, fileName: r.name, fileSize: r.size, mimeType: r.mimeType)
            } catch { self.error = "Voice note upload failed." }
        }
    }
    func cancelRecording() { recorder?.stop(); recording = false; voiceURL = nil }

    func logout() { socket.disconnect() }
}
