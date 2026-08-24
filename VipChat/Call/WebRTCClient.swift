import Foundation
import WebRTC

/// Audio-only WebRTC, customer-as-offerer (matches backend/socket/call.js and the
/// web client): on call:accepted THIS side creates the offer; the admin answers.
final class WebRTCClient: NSObject, RTCPeerConnectionDelegate {
    private static let factory: RTCPeerConnectionFactory = {
        RTCInitializeSSL()
        return RTCPeerConnectionFactory(encoderFactory: RTCDefaultVideoEncoderFactory(),
                                        decoderFactory: RTCDefaultVideoDecoderFactory())
    }()

    private var pc: RTCPeerConnection?
    private var localAudioTrack: RTCAudioTrack?

    var onIceCandidate: ((RTCIceCandidate) -> Void)?
    var onIceState: ((RTCIceConnectionState) -> Void)?

    func start(iceServers: [RTCIceServer]) {
        let config = RTCConfiguration()
        config.iceServers = iceServers
        config.sdpSemantics = .unifiedPlan
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        pc = WebRTCClient.factory.peerConnection(with: config, constraints: constraints, delegate: self)

        let audioConstraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        let source = WebRTCClient.factory.audioSource(with: audioConstraints)
        let track = WebRTCClient.factory.audioTrack(with: source, trackId: "vipchat-audio0")
        pc?.add(track, streamIds: ["vipchat-stream0"])
        localAudioTrack = track
    }

    func createOffer(_ completion: @escaping (String) -> Void) {
        let constraints = RTCMediaConstraints(mandatoryConstraints: ["OfferToReceiveAudio": "true"], optionalConstraints: nil)
        pc?.offer(for: constraints) { [weak self] sdp, _ in
            guard let self, let sdp else { return }
            self.pc?.setLocalDescription(sdp) { _ in completion(sdp.sdp) }
        }
    }

    func setRemoteAnswer(_ sdp: String, _ done: @escaping () -> Void) {
        let desc = RTCSessionDescription(type: .answer, sdp: sdp)
        pc?.setRemoteDescription(desc) { _ in done() }
    }

    func addRemoteCandidate(_ candidate: String, sdpMid: String?, sdpMLineIndex: Int) {
        pc?.add(RTCIceCandidate(sdp: candidate, sdpMLineIndex: Int32(sdpMLineIndex), sdpMid: sdpMid)) { _ in }
    }

    func setMuted(_ muted: Bool) { localAudioTrack?.isEnabled = !muted }

    func close() {
        pc?.close(); pc = nil; localAudioTrack = nil
    }

    // MARK: RTCPeerConnectionDelegate
    func peerConnection(_ pc: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) { onIceCandidate?(candidate) }
    func peerConnection(_ pc: RTCPeerConnection, didChange newState: RTCIceConnectionState) { onIceState?(newState) }
    func peerConnection(_ pc: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {}
    func peerConnection(_ pc: RTCPeerConnection, didAdd stream: RTCMediaStream) {}
    func peerConnection(_ pc: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    func peerConnectionShouldNegotiate(_ pc: RTCPeerConnection) {}
    func peerConnection(_ pc: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}
    func peerConnection(_ pc: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
    func peerConnection(_ pc: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}
}
