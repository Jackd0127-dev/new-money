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
    private var lastStatusMessage = "Remote notifications not requested yet"

    private init() {}

    var debugStatus: String {
#if targetEnvironment(simulator)
        return "Simulator build; APNs phone-auth callback is not available."
#else
        let tokenStatus = hasAPNSToken ? "APNs token received" : "APNs token missing"
        return "\(tokenStatus). \(lastStatusMessage)"
#endif
    }

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
        _ = prepareFirebaseAuth()

#if targetEnvironment(simulator)
        debugLog("skipped remote notification registration on simulator")
#else
        guard !didRequestRemoteNotifications else {
            return
        }

        didRequestRemoteNotifications = true
        application.registerForRemoteNotifications()
        lastStatusMessage = "Remote notifications requested"
        debugLog("requested remote notifications")
#endif
    }

    func setAPNSToken(_ deviceToken: Data) {
#if targetEnvironment(simulator)
        debugLog("ignored simulator APNs token callback")
#else
        let auth = prepareFirebaseAuth()

        auth.setAPNSToken(deviceToken, type: .unknown)
        debugLog("set APNs token (\(deviceToken.count) bytes); Firebase will detect token environment")
        hasAPNSToken = true
        lastStatusMessage = "APNs token set with Firebase Auth; token environment is auto-detected"
#endif
    }

    func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) -> Bool {
#if targetEnvironment(simulator)
        debugLog("ignored simulator remote notification callback")
        return false
#else
        let handled = prepareFirebaseAuth().canHandleNotification(userInfo)
        debugLog("received remote notification; firebaseHandled=\(handled)")
        lastStatusMessage = "Remote notification callback received; Firebase handled=\(handled)"
        return handled
#endif
    }

    func recordRemoteNotificationRegistrationFailure(_ error: Error) {
#if !targetEnvironment(simulator)
        lastStatusMessage = "APNs registration failed: \(error.localizedDescription)"
        debugLog(lastStatusMessage)
#endif
    }

    func waitForAPNSTokenIfNeeded(timeoutNanoseconds: UInt64 = 8_000_000_000) async {
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
        if !hasAPNSToken {
            lastStatusMessage = "APNs token wait timed out before Firebase phone-auth request"
        }
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
        FirebasePhoneAuthAPNsBridge.shared.recordRemoteNotificationRegistrationFailure(error)
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
