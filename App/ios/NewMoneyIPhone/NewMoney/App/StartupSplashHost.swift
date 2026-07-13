import SwiftUI

enum StartupSplashTransitionPolicy {
    static let fallbackDuration = 5
    static let crossFadeDuration: TimeInterval = 0.42
    static let hidesMainContentUntilVideoCompletes = true
}

struct StartupSplashHost<Content: View>: View {
    @ViewBuilder let content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShowingSplash = true

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            content
                .opacity(isShowingSplash && StartupSplashTransitionPolicy.hidesMainContentUntilVideoCompletes ? 0 : 1)

            if isShowingSplash {
                StartupSplashVideoPlayer(onFinished: dismissSplash)
                    .transition(.opacity)
                    .ignoresSafeArea()
            }
        }
        .task(id: reduceMotion) {
            if reduceMotion {
                dismissSplash()
                return
            }

            do {
                try await Task.sleep(for: .seconds(StartupSplashTransitionPolicy.fallbackDuration))
                dismissSplash()
            } catch {
                // The view disappeared before the fallback was needed.
            }
        }
    }

    private func dismissSplash() {
        guard isShowingSplash else { return }

        let animation: Animation? = reduceMotion
            ? nil
            : .easeInOut(duration: StartupSplashTransitionPolicy.crossFadeDuration)

        withAnimation(animation) {
            isShowingSplash = false
        }
    }
}
