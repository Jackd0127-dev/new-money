import AVFoundation
import SwiftUI
import UIKit

@MainActor
struct StartupSplashVideoPlayer: UIViewRepresentable {
    let onFinished: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinished: onFinished)
    }

    func makeUIView(context: Context) -> StartupSplashPlayerView {
        let view = StartupSplashPlayerView()
        context.coordinator.start(in: view)
        return view
    }

    func updateUIView(_ uiView: StartupSplashPlayerView, context: Context) {}

    static func dismantleUIView(_ uiView: StartupSplashPlayerView, coordinator: Coordinator) {
        coordinator.stop()
    }

    @MainActor
    final class Coordinator {
        private let onFinished: () -> Void
        private var player: AVPlayer?
        private weak var playerView: StartupSplashPlayerView?
        private var endObserver: NSObjectProtocol?
        private var statusObservation: NSKeyValueObservation?
        private var didFinish = false

        init(onFinished: @escaping () -> Void) {
            self.onFinished = onFinished
        }

        func start(in view: StartupSplashPlayerView) {
            guard let url = Bundle.main.url(forResource: "StartupSplash", withExtension: "mp4") else {
                finish()
                return
            }

            let player = AVPlayer(url: url)
            player.isMuted = true
            player.actionAtItemEnd = .pause
            self.player = player
            playerView = view

            view.playerLayer.player = player
            view.alpha = 0

            endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.finish()
                }
            }

            statusObservation = player.currentItem?.observe(\.status, options: [.new]) { [weak self] item, _ in
                let status = item.status

                Task { @MainActor in
                    self?.handleStatus(status)
                }
            }
        }

        func stop() {
            player?.pause()
            player = nil
            playerView = nil
            statusObservation = nil

            if let endObserver {
                NotificationCenter.default.removeObserver(endObserver)
                self.endObserver = nil
            }
        }

        private func finish() {
            guard !didFinish else { return }
            didFinish = true
            onFinished()
        }

        private func handleStatus(_ status: AVPlayerItem.Status) {
            guard !didFinish else { return }

            switch status {
            case .readyToPlay:
                player?.play()
                UIView.animate(withDuration: 0.08) { [weak playerView] in
                    playerView?.alpha = 1
                }
            case .failed:
                finish()
            default:
                break
            }
        }
    }
}

@MainActor
final class StartupSplashPlayerView: UIView {
    override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        playerLayer.videoGravity = .resizeAspectFill
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
