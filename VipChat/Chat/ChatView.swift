import SwiftUI

struct ChatView: View {
    @EnvironmentObject var session: SessionState
    @StateObject private var vm = ChatViewModel()
    @State private var showCall = false

    var body: some View {
        Group {
            if let blocked = vm.blockedMessage {
                Text(blocked).foregroundColor(.waText).padding(32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.waChatBg)
            } else {
                chat
            }
        }
        .onAppear {
            vm.start()
            PushManager.shared.requestAuthorization()
        }
        .onChange(of: vm.sessionExpired) { if $0 { session.logout() } }
        .fullScreenCover(isPresented: $showCall) {
            if let cid = vm.conversationId { CallView(conversationId: cid, isPresented: $showCall) }
        }
    }

    private var chat: some View {
        VStack(spacing: 0) {
            header
            messageList
            if let e = vm.error { errorBar(e) }
            Composer(vm: vm)
        }
        .background(Color.waChatBg)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Circle().fill(Color(hex: 0x0E3A4C)).frame(width: 40, height: 40)
                .overlay(Image(systemName: "person.fill").foregroundColor(.white))
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text("Chat Support").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 13)).foregroundColor(.waBlueRead)
                }
                Text(statusText).font(.system(size: 12)).foregroundColor(vm.connected ? Color(hex: 0xD7FFF1) : Color(hex: 0xFFCC02))
            }
            Spacer()
            Button { showCall = true } label: { Image(systemName: "phone.fill").foregroundColor(.white) }
            Menu {
                Button("Log out", role: .destructive) { vm.logout(); session.logout() }
            } label: { Image(systemName: "ellipsis").foregroundColor(.white) }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(Color.waGreenDeep)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(vm.messages) { m in
                        MessageBubble(message: m,
                                      onReply: { vm.setReply($0) },
                                      onReact: { vm.react($0, $1) },
                                      onRetry: { vm.retry($0) },
                                      onBotButton: { vm.onBotButton($0) })
                            .id(m.id)
                            .onAppear { if m.id == vm.messages.first?.id { vm.loadOlder() } }
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 8)
            }
            .background(
                Image("chat_wallpaper").resizable().scaledToFill().opacity(0.5).ignoresSafeArea()
            )
            .onChange(of: vm.messages.last?.id) { id in
                if let id { withAnimation { proxy.scrollTo(id, anchor: .bottom) } }
            }
        }
    }

    private func errorBar(_ e: String) -> some View {
        HStack {
            Text(e).font(.system(size: 13)).foregroundColor(.vipError)
            Spacer()
            Button("Dismiss") { vm.error = nil }.font(.system(size: 13)).foregroundColor(.waMuted)
        }.padding(.horizontal, 12).padding(.vertical, 8).background(Color.waPanel)
    }

    private var statusText: String {
        if let t = vm.typingUser { return "\(t) is typing…" }
        if vm.connected { return "Online" }
        return vm.everConnected ? "Reconnecting…" : "Connecting…"
    }
}
