import Foundation
import SocketIO

/// Single shared Socket.IO connection (mirrors Android's SocketManager singleton
/// and the web's SocketContext). Same event contract as backend/socket/chat.js
/// and call.js. Emits typed Combine-style callbacks via closures the ViewModels set.
final class SocketManager {
    static let shared = SocketManager()

    private var manager: SocketIO.SocketManager?
    private var socket: SocketIOClient?

    // Chat callbacks
    var onConnected: ((Bool) -> Void)?
    var onAuthError: (() -> Void)?
    var onConversationCreated: ((ConversationDto, [ChatMessage]) -> Void)?
    var onMessagesInitial: ((String?, [ChatMessage]) -> Void)?
    var onMessageNew: ((ChatMessage) -> Void)?
    var onMessageEdited: ((String, String) -> Void)?
    var onMessageDeleted: ((String) -> Void)?
    var onMessageReacted: ((String, [Reaction]) -> Void)?
    var onMessagesRead: ((String?) -> Void)?
    var onTyping: ((Bool, String?) -> Void)?
    var onHandover: ((Bool, String?) -> Void)?
    var onBlocked: ((String?) -> Void)?

    // Call callbacks
    var onCallAccepted: ((String?) -> Void)?
    var onCallUnavailable: ((String?) -> Void)?
    var onCallMissed: ((String?) -> Void)?
    var onCallRejected: ((String?) -> Void)?
    var onCallEnded: (() -> Void)?
    var onCallAnswer: ((String) -> Void)?           // remote sdp
    var onCallIceCandidate: ((String, String?, Int) -> Void)? // candidate, sdpMid, sdpMLineIndex

    private let decoder = JSONDecoder()

    var isConnected: Bool { socket?.status == .connected }

    func connect(token: String) {
        if socket != nil { return }
        guard let url = URL(string: AppEnv.apiBase) else { return }
        // socket.io-client-swift sends the token via connectParams (handshake QUERY).
        // The backend's socketAuth currently reads handshake.auth.token only, so a
        // 1-line backward-compatible shim is added there to also accept
        // handshake.query.token (see README "Backend shim"). Web keeps using auth.
        let mgr = SocketIO.SocketManager(socketURL: url, config: [
            .log(false),
            .compress,
            .reconnects(true),
            .reconnectAttempts(10),
            .reconnectWait(1),
            .connectParams(["token": token]),
        ])
        let sock = mgr.defaultSocket
        register(sock)
        manager = mgr
        socket = sock
        sock.connect()
    }

    func reconnect(token: String) { disconnect(); connect(token: token) }

    func disconnect() {
        socket?.disconnect()
        socket?.removeAllHandlers()
        socket = nil
        manager = nil
        onConnected?(false)
    }

    // MARK: parsing helper
    private func obj<T: Decodable>(_ any: Any, _ type: T.Type) -> T? {
        guard let data = try? JSONSerialization.data(withJSONObject: any) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    private func register(_ s: SocketIOClient) {
        s.on(clientEvent: .connect) { [weak self] _, _ in self?.onConnected?(true) }
        s.on(clientEvent: .disconnect) { [weak self] _, _ in self?.onConnected?(false) }
        s.on(clientEvent: .error) { [weak self] data, _ in
            let msg = (data.first as? String) ?? ""
            if msg.lowercased().contains("token") { self?.onAuthError?() }
        }

        s.on("conversation:created") { [weak self] data, _ in
            guard let self, let d = data.first as? [String: Any] else { return }
            let conv = self.obj(d["conversation"] ?? [:], ConversationDto.self)
            let msgs = (d["messages"] as? [[String: Any]])?.compactMap { self.obj($0, ChatMessage.self) } ?? []
            if let conv { self.onConversationCreated?(conv, msgs) }
        }
        s.on("messages:initial") { [weak self] data, _ in
            guard let self, let d = data.first as? [String: Any] else { return }
            let convId = d["convId"] as? String
            let msgs = (d["messages"] as? [[String: Any]])?.compactMap { self.obj($0, ChatMessage.self) } ?? []
            self.onMessagesInitial?(convId, msgs)
        }
        s.on("message:new") { [weak self] data, _ in
            guard let self, let d = data.first, let m = self.obj(d, ChatMessage.self) else { return }
            self.onMessageNew?(m)
        }
        s.on("message:edited") { [weak self] data, _ in
            guard let d = data.first as? [String: Any], let id = d["_id"] as? String, let text = d["text"] as? String else { return }
            self?.onMessageEdited?(id, text)
        }
        s.on("message:deleted") { [weak self] data, _ in
            guard let d = data.first as? [String: Any], let id = d["_id"] as? String else { return }
            self?.onMessageDeleted?(id)
        }
        s.on("message:reacted") { [weak self] data, _ in
            guard let self, let d = data.first as? [String: Any], let id = d["_id"] as? String else { return }
            let reactions = (d["reactions"] as? [[String: Any]])?.compactMap { self.obj($0, Reaction.self) } ?? []
            self.onMessageReacted?(id, reactions)
        }
        s.on("messages:read") { [weak self] data, _ in
            let by = (data.first as? [String: Any])?["by"] as? String
            self?.onMessagesRead?(by)
        }
        s.on("typing:update") { [weak self] data, _ in
            guard let d = data.first as? [String: Any] else { return }
            self?.onTyping?((d["typing"] as? Bool) ?? false, d["user"] as? String)
        }
        s.on("handover:status") { [weak self] data, _ in
            guard let d = data.first as? [String: Any] else { return }
            self?.onHandover?((d["assigned"] as? Bool) ?? false, d["adminName"] as? String)
        }
        s.on("blocked") { [weak self] data, _ in
            self?.onBlocked?((data.first as? [String: Any])?["message"] as? String)
        }

        // Calls
        s.on("call:accepted") { [weak self] data, _ in
            self?.onCallAccepted?((data.first as? [String: Any])?["adminSocket"] as? String)
        }
        s.on("call:unavailable") { [weak self] data, _ in
            self?.onCallUnavailable?((data.first as? [String: Any])?["message"] as? String)
        }
        s.on("call:missed") { [weak self] data, _ in
            self?.onCallMissed?((data.first as? [String: Any])?["message"] as? String)
        }
        s.on("call:rejected") { [weak self] data, _ in
            self?.onCallRejected?((data.first as? [String: Any])?["message"] as? String)
        }
        s.on("call:ended") { [weak self] _, _ in self?.onCallEnded?() }
        s.on("call:answer") { [weak self] data, _ in
            guard let ans = (data.first as? [String: Any])?["answer"] as? [String: Any],
                  let sdp = ans["sdp"] as? String else { return }
            self?.onCallAnswer?(sdp)
        }
        s.on("call:ice-candidate") { [weak self] data, _ in
            guard let c = (data.first as? [String: Any])?["candidate"] as? [String: Any],
                  let cand = c["candidate"] as? String else { return }
            self?.onCallIceCandidate?(cand, c["sdpMid"] as? String, (c["sdpMLineIndex"] as? Int) ?? 0)
        }
    }

    // socket.io payloads are [String: Any]; use this for nullable fields so a nil
    // becomes JSON null (NSNull) instead of tripping Swift's dictionary inference.
    private func orNull(_ v: String?) -> Any { if let v { return v } else { return NSNull() } }

    // MARK: emits
    func initConversation(customerId: String, branchId: String?) {
        let payload: [String: Any] = ["customerId": customerId, "branchId": orNull(branchId)]
        socket?.emit("conversation:init", payload)
    }
    func sendMessage(conversationId: String, text: String? = nil, type: String = "text",
                     fileUrl: String? = nil, fileName: String? = nil, fileSize: Int? = nil,
                     mimeType: String? = nil, replyTo: String? = nil, clientId: String? = nil) {
        var p: [String: Any] = ["conversationId": conversationId, "type": type]
        if let text { p["text"] = text }
        if let fileUrl { p["fileUrl"] = fileUrl }
        if let fileName { p["fileName"] = fileName }
        if let fileSize { p["fileSize"] = fileSize }
        if let mimeType { p["mimeType"] = mimeType }
        if let replyTo { p["replyTo"] = replyTo }
        if let clientId { p["clientId"] = clientId }
        socket?.emit("message:send", p)
    }
    func react(messageId: String, emoji: String) { socket?.emit("message:react", ["messageId": messageId, "emoji": emoji]) }
    func markRead(_ conversationId: String) { socket?.emit("messages:mark-read", conversationId) }
    func startTyping(_ conversationId: String) { socket?.emit("typing:start", conversationId) }
    func stopTyping(_ conversationId: String) { socket?.emit("typing:stop", conversationId) }
    func requestHuman(_ conversationId: String) { socket?.emit("bot:human-request", ["conversationId": conversationId]) }

    // Calls
    func startCall(_ conversationId: String) { socket?.emit("call:start", ["conversationId": conversationId]) }
    func sendOffer(target: String, sdp: String) { socket?.emit("call:offer", ["targetSocket": target, "offer": ["type": "offer", "sdp": sdp]]) }
    func sendIce(target: String, candidate: String, sdpMid: String?, sdpMLineIndex: Int) {
        let cand: [String: Any] = ["candidate": candidate, "sdpMid": orNull(sdpMid), "sdpMLineIndex": sdpMLineIndex]
        let payload: [String: Any] = ["targetSocket": target, "candidate": cand]
        socket?.emit("call:ice-candidate", payload)
    }
    func endCall(target: String?, conversationId: String) {
        let payload: [String: Any] = ["targetSocket": orNull(target), "conversationId": conversationId]
        socket?.emit("call:end", payload)
    }
}
