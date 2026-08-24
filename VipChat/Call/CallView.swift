import SwiftUI

struct CallView: View {
    let conversationId: String
    @Binding var isPresented: Bool
    @StateObject private var vm = CallViewModel()

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x0B3D36), Color(hex: 0x0B141A)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer().frame(height: 90)
                Circle().fill(Color(hex: 0x0E3A4C)).frame(width: 110, height: 110)
                    .overlay(Image(systemName: "headphones").font(.system(size: 44)).foregroundColor(.white))
                Text("Support Agent").font(.system(size: 26, weight: .semibold)).foregroundColor(.white).padding(.top, 22)
                Text(vm.state == .connected ? vm.durationText : vm.statusText)
                    .font(.system(size: 15)).foregroundColor(Color(hex: 0xD7FFF1)).padding(.top, 8)
                Spacer()
                if !vm.isTerminal { controls }
            }
        }
        .onAppear { vm.start(conversationId: conversationId) }
        .onChange(of: vm.state) { _ in
            if vm.isTerminal {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { isPresented = false }
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 28) {
            control(vm.speakerOn ? "speaker.wave.2.fill" : "speaker.slash.fill", "Speaker", active: vm.speakerOn) { vm.toggleSpeaker() }
            Button { vm.hangUp() } label: {
                Image(systemName: "phone.down.fill").font(.system(size: 32)).foregroundColor(.white)
                    .frame(width: 72, height: 72).background(Color(hex: 0xEB5757)).clipShape(Circle())
            }
            control(vm.muted ? "mic.slash.fill" : "mic.fill", vm.muted ? "Unmute" : "Mute", active: vm.muted) { vm.toggleMute() }
        }
        .padding(.bottom, 56)
    }

    private func control(_ icon: String, _ label: String, active: Bool, _ action: @escaping () -> Void) -> some View {
        VStack(spacing: 6) {
            Button(action: action) {
                Image(systemName: icon).font(.system(size: 26))
                    .foregroundColor(active ? Color(hex: 0x0B141A) : .white)
                    .frame(width: 60, height: 60)
                    .background(active ? Color.white.opacity(0.9) : Color.white.opacity(0.2)).clipShape(Circle())
            }
            Text(label).font(.system(size: 12)).foregroundColor(.white.opacity(0.7))
        }
    }
}
