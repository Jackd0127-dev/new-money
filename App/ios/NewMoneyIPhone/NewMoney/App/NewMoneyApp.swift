import SwiftUI

@main
struct NewMoneyApp: App {
    @UIApplicationDelegateAdaptor(NewMoneyAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            MUNOSplashHost {
                AuthenticatedRootView()
            }
            .onOpenURL { url in
                NativeAuthCallbackHandler.handle(url)
            }
        }
    }
}
