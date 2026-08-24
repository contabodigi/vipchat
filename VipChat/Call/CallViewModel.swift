import Foundation
import WebRTC
import AVFoundation

@MainActor
final class CallViewModel: ObservableObject {
    enum State { case calling, connecting, connected, ended, unavailable, rejected, missed, failed }

    @Published var state: State = .calling
    @Published var statusText = "Calling…"
    @Published var muted = false
    @Published var speakerOn = false
    @Published var seconds = 0

    private let socket = SocketManager.shared
    private let webrtc = WebRTCClient()
    private var conversationId: String?
    private var adminSocket: String?
    private var remoteSet = false
    private var pendingCandidates: [(String, String?, Int)] = []
    private var timer: Timer?
    private var started = false

    private var iceServers: [RTCIceServer] {
        var list = [RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"])]
        let remote = RemoteConfig.shared.current.turn
        if !remote.isEmpty {
            for t in remote where !t.urls.isEmpty {
                list.append(RTCIceServer(urlStrings: [t.urls], username: t.username, credential: t.credential))
            }
        } else {
            list.append(RTCIceServer(urlStrings: [AppEnv.turnUrl, AppEnv.turnUrl + "?transport=tcp"],
                                     username: AppEnv.turnUser, credential: AppEnv.turnCredential))
        }
        return list
    }

    func start(conversationId: String) {
        guard !started else { return }
        started = true
        self.conversationId = conversationId
        wire()
        configureAudio()
        socket.startCall(conversationId)
    }

    private func wire() {
        socket.onCallAccepted = { [weak self] target in
            guard let self, let target else { return }
            Task { @MainActor in
                self.adminSocket = target
                self.state = .connecting; self.statusText = "Connecting…"
                self.webrtc.onIceCandidate = { c in
                    self.socket.sendIce(target: target, candidate: c.sdp, sdpMid: c.sdpMid, sdpMLineIndex: Int(c.sdpMLineIndex))
                }
                self.webrtc.onIceState = { st in Task { @MainActor in self.onIce(st) } }
                self.webrtc.start(iceServers: self.iceServers)
                self.webrtc.createOffer { sdp in self.socket.sendOffer(target: target, sdp: sdp) }
            }
        }
        socket.onCallAnswer = { [weak self] sdp in
            Task { @MainActor in
                self?.webrtc.setRemoteAnswer(sdp) {
                    Task { @MainActor in
                        self?.remoteSet = true
                        self?.pendingCandidates.forEach { self?.webrtc.addRemoteCandidate($0.0, sdpMid: $0.1, sdpMLineIndex: $0.2) }
                        self?.pendingCandidates.removeAll()
                    }
                }
            }
        }
        socket.onCallIceCandidate = { [weak self] cand, mid, idx in
            Task { @MainActor in
                if self?.remoteSet == true { self?.webrtc.addRemoteCandidate(cand, sdpMid: mid, sdpMLineIndex: idx) }
                else { self?.pendingCandidates.append((cand, mid, idx)) }
            }
        }
        socket.onCallUnavailable = { [weak self] m in Task { @MainActor in self?.end(.unavailable, m ?? "No agents available") } }
        socket.onCallMissed = { [weak self] m in Task { @MainActor in self?.end(.missed, m ?? "No answer") } }
        socket.onCallRejected = { [weak self] m in Task { @MainActor in self?.end(.rejected, m ?? "Agent is busy") } }
        socket.onCallEnded = { [weak self] in Task { @MainActor in self?.end(.ended, "Call ended") } }
    }

    private func onIce(_ st: RTCIceConnectionState) {
        switch st {
        case .connected, .completed:
            if state != .connected { state = .connected; statusText = "Connected"; startTimer() }
        case .failed: state = .failed; statusText = "Connection failed — check network"
        case .disconnected: statusText = "Reconnecting…"
        default: break
        }
    }

    private func configureAudio() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth])
        try? session.setActive(true)
    }

    func toggleMute() { muted.toggle(); webrtc.setMuted(muted) }
    func toggleSpeaker() {
        speakerOn.toggle()
        try? AVAudioSession.sharedInstance().overrideOutputAudioPort(speakerOn ? .speaker : .none)
    }

    func hangUp() {
        if let cid = conversationId { socket.endCall(target: adminSocket, conversationId: cid) }
        end(.ended, "Call ended")
    }

    private func end(_ s: State, _ text: String) {
        state = s; statusText = text
        cleanup()
    }

    private func cleanup() {
        timer?.invalidate(); timer = nil
        webrtc.close()
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.seconds += 1 }
        }
    }

    var isTerminal: Bool { [.ended, .unavailable, .rejected, .missed, .failed].contains(state) }
    var durationText: String { String(format: "%d:%02d", seconds / 60, seconds % 60) }

    deinit { timer?.invalidate() }
}
