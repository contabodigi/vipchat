import SwiftUI

@main
struct VipChatApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var session = SessionState()

    init() {
        // Instant cached remote config, init Meta from it, then refresh in background.
        RemoteConfig.shared.loadCached()
        MetaEvents.initFrom(RemoteConfig.shared.current.meta)
        Task {
            await RemoteConfig.shared.refresh()
            MetaEvents.initFrom(RemoteConfig.shared.current.meta)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(session)
        }
    }
}

/// Tracks login state so the root can switch between auth and chat.
final class SessionState: ObservableObject {
    @Published var loggedIn = KeychainStore.shared.isLoggedIn
    func logout() {
        PushManager.shared.unregister()
        SocketManager.shared.disconnect()
        KeychainStore.shared.clear()
        loggedIn = false
    }
}

struct RootView: View {
    @EnvironmentObject var session: SessionState
    @State private var forceUpdate = RemoteConfig.shared.needsForceUpdate

    var body: some View {
        Group {
            if forceUpdate {
                ForceUpdateView()
            } else if session.loggedIn {
                ChatView()
            } else {
                AuthView()
            }
        }
        .task {
            // Re-check after the background config refresh completes.
            await RemoteConfig.shared.refresh()
            forceUpdate = RemoteConfig.shared.needsForceUpdate
        }
    }
}

struct ForceUpdateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Update required").font(.title2).bold().foregroundColor(.vipTextHeading)
            Text("A newer version of the app is needed to continue. Please update from the App Store.")
                .multilineTextAlignment(.center).foregroundColor(.vipTextSecondary)
            Button("Open App Store") {
                if let url = URL(string: "itms-apps://apple.com/app") { UIApplication.shared.open(url) }
            }
            .padding(.horizontal, 20).padding(.vertical, 11)
            .background(Color.vipGold3).foregroundColor(Color(hex: 0x1A1509)).cornerRadius(10)
        }
        .padding(32).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.vipBgBottom)
    }
}
