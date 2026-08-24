import SwiftUI

struct AuthView: View {
    @EnvironmentObject var session: SessionState
    @StateObject private var vm = AuthViewModel()

    var body: some View {
        ZStack {
            LinearGradient(colors: [.vipBgTop, .vipBgBottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack {
                marquee
                Spacer()
                card
                Spacer()
            }
            .padding(.horizontal, 28)
        }
        .onAppear { vm.loadOtpStatus() }
        .onChange(of: vm.loggedIn) { if $0 { session.loggedIn = true } }
    }

    private var marquee: some View {
        Text("24×7 Chat Support   •   24×7 Chat Support")
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(Color(hex: 0x1A1509))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(LinearGradient(colors: [.vipGold1, .vipGold2, .vipGold3], startPoint: .leading, endPoint: .trailing))
    }

    private var card: some View {
        VStack(spacing: 0) {
            if vm.skipOtp == nil {
                ProgressView().tint(.vipGold3).padding(40)
            } else if vm.step == .phone {
                phoneStep
            } else {
                otpStep
            }
        }
        .padding(28)
        .background(LinearGradient(colors: [.vipCardTop, .vipCardBottom], startPoint: .top, endPoint: .bottom))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.vipCardBorder, lineWidth: 1))
        .cornerRadius(20)
    }

    private var phoneStep: some View {
        VStack(spacing: 14) {
            Text("Chat Support").font(.system(size: 24, weight: .bold)).foregroundColor(.vipTextHeading)
            Text("Enter your mobile number to start chatting")
                .font(.system(size: 14)).foregroundColor(.vipTextSecondary).multilineTextAlignment(.center)
            HStack {
                Text("+91").foregroundColor(.vipTextAccent).bold()
                TextField("", text: $vm.phone, prompt: Text("Enter 10-digit mobile").foregroundColor(Color(hex: 0x6B5C3D)))
                    .keyboardType(.numberPad)
                    .foregroundColor(.white)              // white typed text (not gold)
                    .tint(.white)                          // white caret
            }
            .padding(12)
            .background(Color.vipInputBg)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.vipGold3, lineWidth: 1))
            .cornerRadius(12)

            if let e = vm.error { Text(e).foregroundColor(.vipError).font(.system(size: 13)) }
            goldButton(vm.skipOtp == true ? "Start Chat" : "Get OTP") { vm.submitPhone() }
            if vm.skipOtp == false {
                Text("OTP will be sent to your WhatsApp").font(.system(size: 12)).foregroundColor(.vipTextSecondary)
            }
        }
    }

    private var otpStep: some View {
        VStack(spacing: 14) {
            Text("Verify OTP").font(.system(size: 24, weight: .bold)).foregroundColor(.vipTextHeading)
            Text("Sent to WhatsApp +91 \(vm.phone)").font(.system(size: 14)).foregroundColor(.vipTextSecondary)
            TextField("", text: $vm.otp, prompt: Text("● ● ● ● ● ●").foregroundColor(Color(hex: 0x6B5C3D)))
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .tint(.white)
                .padding(12)
                .background(Color.vipInputBg)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.vipInputBorder, lineWidth: 2))
                .cornerRadius(10)
                .onChange(of: vm.otp) { if $0.filter(\.isNumber).count == 6 { vm.submitOtp() } }

            if let e = vm.error { Text(e).foregroundColor(.vipError).font(.system(size: 13)) }
            goldButton("Verify & Start Chat") { vm.submitOtp() }
            HStack(spacing: 8) {
                if vm.resendSeconds > 0 {
                    Text("Resend in \(vm.resendSeconds)s").foregroundColor(.vipTextSecondary)
                } else {
                    Button("Resend OTP") { vm.resend() }.foregroundColor(.vipTextAccent).bold()
                }
                Text("|").foregroundColor(Color(hex: 0x4A3A18))
                Button("Change Number") { vm.changeNumber() }.foregroundColor(.vipTextSecondary)
            }.font(.system(size: 13))
        }
    }

    private func goldButton(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                LinearGradient(colors: [.vipGold1, .vipGold2, .vipGold3], startPoint: .top, endPoint: .bottom)
                if vm.loading { ProgressView().tint(Color(hex: 0x1A1509)) }
                else { Text(title).font(.system(size: 15, weight: .bold)).foregroundColor(Color(hex: 0x1A1509)) }
            }
            .frame(height: 48).cornerRadius(12)
        }
        .disabled(vm.loading)
    }
}
