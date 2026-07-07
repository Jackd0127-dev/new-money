import SwiftUI

@main
struct NewMoneyApp: App {
    @UIApplicationDelegateAdaptor(NewMoneyAppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var splashReplayRevision = 0
    @State private var didEnterBackground = false

    var body: some Scene {
        WindowGroup {
            MUNOSplashHost(replayRevision: splashReplayRevision) {
                AuthenticatedRootView()
            }
            .onOpenURL { url in
                NativeAuthCallbackHandler.handle(url)
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .background:
                    didEnterBackground = true
                case .active where didEnterBackground:
                    didEnterBackground = false
                    splashReplayRevision += 1
                default:
                    break
                }
            }
        }
    }
}
