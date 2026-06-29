import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import UIKit

@MainActor
enum NativeAuthCallbackHandler {
    @discardableResult
    static func handle(_ url: URL) -> Bool {
        if Auth.auth().canHandle(url) {
            return true
        }
        return GIDSignIn.sharedInstance.handle(url)
    }
}

@MainActor
final class FirebasePhoneAuthAPNsBridge {
    static let shared = FirebasePhoneAuthAPNsBridge()

    private var didRequestRemoteNotifications = false
    private var hasAPNSToken = false

    private init() {}

    @discardableResult
    func prepareFirebaseAuth() -> Auth {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        let auth = Auth.auth()
        _ = auth.currentUser
        return auth
    }

    func registerForRemoteNotificationsIfNeeded(application: UIApplication = .shared) {
#if targetEnvironment(simulator)
        debugLog("skipped remote notification registration on simulator")
#else
        _ = prepareFirebaseAuth()

        guard !didRequestRemoteNotifications else {
            return
        }

        didRequestRemoteNotifications = true
        application.registerForRemoteNotifications()
        debugLog("requested remote notifications")
#endif
    }

    func setAPNSToken(_ deviceToken: Data) {
#if targetEnvironment(simulator)
        debugLog("ignored simulator APNs token callback")
#else
        let auth = prepareFirebaseAuth()

#if DEBUG
        auth.setAPNSToken(deviceToken, type: .sandbox)
        debugLog("set sandbox APNs token (\(deviceToken.count) bytes)")
#else
        auth.setAPNSToken(deviceToken, type: .prod)
        debugLog("set production APNs token (\(deviceToken.count) bytes)")
#endif
        hasAPNSToken = true
#endif
    }

    func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) -> Bool {
#if targetEnvironment(simulator)
        debugLog("ignored simulator remote notification callback")
        return false
#else
        let handled = prepareFirebaseAuth().canHandleNotification(userInfo)
        debugLog("received remote notification; firebaseHandled=\(handled)")
        return handled
#endif
    }

    func waitForAPNSTokenIfNeeded(timeoutNanoseconds: UInt64 = 2_000_000_000) async {
#if targetEnvironment(simulator)
        debugLog("skipped APNs token wait on simulator")
#else
        guard !hasAPNSToken else {
            return
        }

        registerForRemoteNotificationsIfNeeded()

        let interval: UInt64 = 100_000_000
        var elapsed: UInt64 = 0
        while !hasAPNSToken, elapsed < timeoutNanoseconds {
            try? await Task.sleep(nanoseconds: interval)
            elapsed += interval
        }

        debugLog("APNs token wait finished; hasToken=\(hasAPNSToken)")
#endif
    }

    private func debugLog(_ message: String) {
#if DEBUG
        print("FirebasePhoneAuthAPNsBridge: \(message)")
#endif
    }
}

final class NewMoneyAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebasePhoneAuthAPNsBridge.shared.registerForRemoteNotificationsIfNeeded(application: application)

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        FirebasePhoneAuthAPNsBridge.shared.setAPNSToken(deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // App can still continue, but phone auth may fail without APNs on this device.
        print("Failed to register for remote notifications: \(error.localizedDescription)")
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        if FirebasePhoneAuthAPNsBridge.shared.handleRemoteNotification(userInfo) {
            completionHandler(.noData)
            return
        }

        completionHandler(.noData)
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        NativeAuthCallbackHandler.handle(url)
    }
}
