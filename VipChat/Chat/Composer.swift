import SwiftUI
import PhotosUI

struct Composer: View {
    @ObservedObject var vm: ChatViewModel
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        VStack(spacing: 0) {
            if let reply = vm.replyingTo { replyBar(reply) }
            HStack(spacing: 8) {
                PhotosPicker(selection: $photoItem, matching: .any(of: [.images, .videos])) {
                    Image(systemName: "paperclip").font(.system(size: 20)).foregroundColor(.waMuted)
                }
                .onChange(of: photoItem) { item in Task { await pickMedia(item) } }

                TextField("", text: $vm.composerText,
                          prompt: Text(vm.recording ? "Recording…" : "Message").foregroundColor(.waMuted))
                    .foregroundColor(.waText)          // black typed text
                    .tint(.waText)                      // black caret
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Color.waInput).cornerRadius(24)
                    .disabled(vm.recording)
                    .onChange(of: vm.composerText) { _ in vm.onTextChange() }

                if !vm.composerText.trimmingCharacters(in: .whitespaces).isEmpty {
                    circleButton("paperplane.fill", .waGreen) { vm.sendText() }
                } else {
                    circleButton(vm.recording ? "stop.fill" : "mic.fill", vm.recording ? .vipError : .waGreen) {
                        vm.recording ? vm.stopRecordingAndSend() : vm.startRecording()
                    }
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 7)
        }
        .background(Color.waPanel)
    }

    private func replyBar(_ m: ChatMessage) -> some View {
        HStack {
            Rectangle().fill(Color.waGreen).frame(width: 3, height: 34).cornerRadius(2)
            VStack(alignment: .leading, spacing: 1) {
                Text(m.senderRole == "customer" ? "Replying to yourself" : "Replying to support")
                    .font(.system(size: 11)).foregroundColor(.waGreen)
                Text(m.text ?? m.fileName ?? m.type).font(.system(size: 12)).foregroundColor(.waMuted).lineLimit(1)
            }
            Spacer()
            Button { vm.setReply(nil) } label: { Image(systemName: "xmark").foregroundColor(.waMuted) }
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
    }

    private func circleButton(_ system: String, _ bg: Color, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system).foregroundColor(.white)
                .frame(width: 44, height: 44).background(bg).clipShape(Circle())
        }.disabled(vm.uploading)
    }

    private func pickMedia(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return }
        let isVideo = item.supportedContentTypes.contains { $0.conforms(to: .movie) }
        let ext = isVideo ? "mp4" : "jpg"
        let mime = isVideo ? "video/mp4" : "image/jpeg"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("pick_\(Int(Date().timeIntervalSince1970)).\(ext)")
        try? data.write(to: url)
        vm.sendMedia(url: url, mimeType: mime)
        photoItem = nil
    }
}
