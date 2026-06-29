import FirebaseAuth
import FirebaseCore
import SwiftUI

@main
struct NewMoneyApp: App {
    @UIApplicationDelegateAdaptor(NewMoneyAppDelegate.self) private var appDelegate

    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        _ = Auth.auth()
    }

    var body: some Scene {
        WindowGroup {
            AuthenticatedRootView()
                .onOpenURL { url in
                    NativeAuthCallbackHandler.handle(url)
                }
        }
    }
}
