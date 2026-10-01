import AVKit
import Observation
import SwiftUI

@MainActor @Observable
final class PlaybackStore {
    let player = AVPlayer()
    var channel: Channel?
    var isLoading = false
    var error: String?
    var isPresented = false
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var itemObservation: NSKeyValueObservation?
    @ObservationIgnored private var playbackObservation: NSKeyValueObservation?
    @ObservationIgnored private var timeoutTask: Task<Void, Never>?
    @ObservationIgnored private var recordedID: String?

    func play(_ channel: Channel, library: LibraryStore) async {
        let fullScreen = isPresented
        stop()
        isPresented = fullScreen
        generation += 1
        let requestGeneration = generation
        self.channel = channel
        isLoading = true
        do {
            let address: String = try await library.call(CoreRequest(command: "stream", id: channel.id))
            guard requestGeneration == generation else { return }
            guard let url = URL(string: address) else { throw AppFailure(message: "The provider returned an invalid stream address.") }
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
            let item = AVPlayerItem(url: url)
            itemObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
                let failed = item.status == .failed
                Task { @MainActor [weak self] in
                    guard let self, requestGeneration == self.generation else { return }
                    if failed { self.fail("This stream could not be played. Retry or choose another channel. AVPlayer requires a compatible HLS stream.") }
                }
            }
            playbackObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
                let playing = player.timeControlStatus == .playing
                Task { @MainActor [weak self] in
                    guard let self, requestGeneration == self.generation, playing else { return }
                    self.isLoading = false
                    self.timeoutTask?.cancel()
                    if self.recordedID != channel.id {
                        self.recordedID = channel.id
                        do { let _: Bool = try await library.call(CoreRequest(command: "watched", id: channel.id)) }
                        catch { library.message = error.localizedDescription }
                    }
                }
            }
            player.replaceCurrentItem(with: item)
            player.play()
            timeoutTask = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(30)) } catch { return }
                guard let self, requestGeneration == self.generation, self.isLoading else { return }
                self.fail("The stream did not start within 30 seconds. Retry or choose another channel.")
            }
        } catch {
            guard requestGeneration == generation else { return }
            fail((error as? AppFailure)?.message ?? "Playback could not start. Check your audio output and try again.")
        }
    }
    private func fail(_ message: String) {
        isLoading = false
        error = message
        timeoutTask?.cancel()
        player.pause()
        player.replaceCurrentItem(with: nil)
    }
    func stop() {
        generation += 1
        timeoutTask?.cancel()
        timeoutTask = nil
        itemObservation = nil
        playbackObservation = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
        channel = nil
        recordedID = nil
        isLoading = false
        error = nil
        isPresented = false
    }
}

struct NativePlayer: UIViewControllerRepresentable {
    let player: AVPlayer
    var onExit: () -> Void = {}
    func makeCoordinator() -> Coordinator { Coordinator(onExit: onExit) }
    final class Coordinator: NSObject, AVPlayerViewControllerDelegate {
        var onExit: () -> Void
        init(onExit: @escaping () -> Void) { self.onExit = onExit }
        #if os(tvOS)
        func playerViewControllerShouldDismiss(_ playerViewController: AVPlayerViewController) -> Bool {
            // SwiftUI owns the presentation. AVKit must not dismiss the hosting controller itself.
            onExit()
            return false
        }
        #endif
    }
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.delegate = context.coordinator
        controller.view.accessibilityIdentifier = "full-screen-player"
        #if os(iOS)
        controller.allowsPictureInPicturePlayback = true
        #endif
        return controller
    }
    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        context.coordinator.onExit = onExit
        if controller.player !== player { controller.player = player }
    }
    static func dismantleUIViewController(_ controller: AVPlayerViewController, coordinator: Coordinator) {
        controller.delegate = nil
        controller.player = nil
    }
}

// A noninteractive AVPlayerLayer keeps remote focus in the channel browser and controls.
// Only one player surface is attached at a time when entering or leaving full screen.
struct InlinePlayer: UIViewRepresentable {
    let player: AVPlayer
    func makeUIView(context: Context) -> InlinePlayerView {
        let view = InlinePlayerView()
        view.isUserInteractionEnabled = false
        view.playerLayer.videoGravity = .resizeAspect
        view.playerLayer.player = player
        return view
    }
    func updateUIView(_ view: InlinePlayerView, context: Context) {
        if view.playerLayer.player !== player { view.playerLayer.player = player }
    }
    static func dismantleUIView(_ view: InlinePlayerView, coordinator: ()) {
        view.playerLayer.player = nil
    }
}
final class InlinePlayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}
