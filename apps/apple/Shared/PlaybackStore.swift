import AVKit
import Observation
import SwiftUI
import VLCKit

@MainActor @Observable
final class PlaybackStore {
    let player = AVPlayer()
    var fallbackPlayer: VLCMediaPlayer?
    @ObservationIgnored let fallbackSurface = UIView()
    var channel: Channel?
    var isLoading = false
    var error: String?
    var isPresented = false
    var isPaused = false
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var itemObservation: NSKeyValueObservation?
    @ObservationIgnored private var monitorTask: Task<Void, Never>?
    @ObservationIgnored private var recordedID: String?

    func play(_ channel: Channel, library: LibraryStore) async {
        let fullScreen = isPresented
        stop()
        isPresented = fullScreen
        let requestGeneration = generation
        self.channel = channel
        isLoading = true
        do {
            let source: PlaybackSource = try await library.call(CoreRequest(command: "stream", id: channel.id))
            guard requestGeneration == generation, !Task.isCancelled else { return }
            guard let url = URL(string: source.url), let fallbackURL = URL(string: source.fallbackUrl) else {
                throw AppFailure(message: "The provider returned an invalid stream address.")
            }
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
            let item = AVPlayerItem(url: url)
            let output = AVPlayerItemVideoOutput(pixelBufferAttributes: nil)
            item.add(output)
            itemObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
                let failed = item.status == .failed
                Task { @MainActor [weak self] in
                    guard let self, requestGeneration == self.generation, failed else { return }
                    self.startFallback(fallbackURL, generation: requestGeneration, channel: channel, library: library)
                }
            }
            player.replaceCurrentItem(with: item)
            player.play()
            monitorTask = Task { [weak self] in
                let deadline = Date.now.addingTimeInterval(20)
                var lastProgress = Date.now
                var lastTime = CMTime.invalid
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
                    guard let self, requestGeneration == self.generation, self.fallbackPlayer == nil else { return }
                    let time = item.currentTime()
                    // The player's clock can advance while neither decoder produces output.
                    // Confirm an actual decoded video frame before reporting LIVE/history.
                    if output.copyPixelBuffer(forItemTime: time, itemTimeForDisplay: nil) != nil {
                        lastProgress = .now
                        await self.didStart(channel, library: library)
                        guard requestGeneration == self.generation else { return }
                    } else if !self.isLoading && time != lastTime && self.player.timeControlStatus == .playing {
                        lastProgress = .now
                    }
                    lastTime = time
                    if !self.isLoading && self.player.timeControlStatus == .paused { lastProgress = .now }
                    if (self.isLoading && Date.now >= deadline) || Date.now.timeIntervalSince(lastProgress) >= 30 {
                        self.startFallback(fallbackURL, generation: requestGeneration, channel: channel, library: library)
                        return
                    }
                    if !self.isLoading, item.duration.isNumeric, time >= item.duration {
                        self.fail("The provider ended this broadcast. Retry later or choose another channel.")
                        return
                    }
                }
            }
        } catch {
            guard requestGeneration == generation else { return }
            fail((error as? AppFailure)?.message ?? "Playback could not start. Check your audio output and try again.")
        }
    }

    private func startFallback(_ url: URL, generation requestGeneration: Int, channel: Channel, library: LibraryStore) {
        guard requestGeneration == generation, fallbackPlayer == nil, error == nil else { return }
        monitorTask?.cancel()
        itemObservation = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
        isLoading = true
        let fallback = VLCMediaPlayer(options: ["--quiet", "--no-video-title-show", "--network-caching=1200"])
        fallback.media = VLCMedia(url: url)
        fallback.drawable = fallbackSurface
        fallbackPlayer = fallback
        fallback.play()
        monitorTask = Task { [weak self] in
            let deadline = Date.now.addingTimeInterval(30)
            var lastProgress = Date.now
            var lastVideo: UInt64 = 0
            var lastAudio: UInt64 = 0
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
                guard let self, requestGeneration == self.generation, self.fallbackPlayer === fallback else { return }
                let stats = fallback.media?.statistics
                let video = stats?.decodedVideo ?? 0
                let audio = stats?.decodedAudio ?? 0
                if video > lastVideo || audio > lastAudio {
                    lastProgress = .now
                    if fallback.state == .playing {
                        #if DEBUG
                        if self.isLoading { print("Fallback output: video=\(video), audio=\(audio)") }
                        #endif
                        await self.didStart(channel, library: library)
                        guard requestGeneration == self.generation else { return }
                    }
                }
                lastVideo = video
                lastAudio = audio
                if fallback.state == .paused { lastProgress = .now }
                if fallback.state == .error {
                    self.fail("The provider's stream could not be decoded by either player. Retry later or choose another channel.")
                    return
                }
                if !self.isLoading && fallback.state == .stopped {
                    self.fail("The provider ended this broadcast. Retry later or choose another channel.")
                    return
                }
                if (self.isLoading && Date.now >= deadline) || Date.now.timeIntervalSince(lastProgress) >= 30 {
                    self.fail("The stream produced no picture or sound for 30 seconds. The channel may be offline. Retry or choose another channel.")
                    return
                }
            }
        }
    }

    private func didStart(_ channel: Channel, library: LibraryStore) async {
        isLoading = false
        guard recordedID != channel.id else { return }
        recordedID = channel.id
        do { let _: Bool = try await library.call(CoreRequest(command: "watched", id: channel.id)) }
        catch { library.message = error.localizedDescription }
    }
    func togglePause() {
        if let fallback = fallbackPlayer {
            if fallback.state == .paused { fallback.play(); isPaused = false }
            else { fallback.pause(); isPaused = true }
        } else {
            if player.timeControlStatus == .paused { player.play() }
            else { player.pause() }
        }
    }
    private func clearPlayers() {
        monitorTask?.cancel()
        monitorTask = nil
        itemObservation = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
        fallbackPlayer?.stop()
        fallbackPlayer?.drawable = nil
        fallbackPlayer = nil
    }
    private func fail(_ message: String) {
        clearPlayers()
        isLoading = false
        error = message
    }
    func stop() {
        generation += 1
        clearPlayers()
        channel = nil
        recordedID = nil
        isLoading = false
        error = nil
        isPresented = false
        isPaused = false
    }
}

/// Keep VLC's drawable stable while reparenting its view between inline and
/// fullscreen containers. Replacing the drawable can leave an existing vout black.
struct FallbackPlayer: UIViewRepresentable {
    let videoView: UIView
    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .black
        container.isUserInteractionEnabled = false
        attach(to: container)
        return container
    }
    func updateUIView(_ container: UIView, context: Context) { attach(to: container) }
    private func attach(to container: UIView) {
        guard videoView.superview !== container else { return }
        videoView.removeFromSuperview()
        videoView.frame = container.bounds
        videoView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.addSubview(videoView)
    }
    func makeCoordinator() -> Coordinator { Coordinator(videoView) }
    final class Coordinator {
        let videoView: UIView
        init(_ videoView: UIView) { self.videoView = videoView }
    }
    static func dismantleUIView(_ container: UIView, coordinator: Coordinator) {
        if coordinator.videoView.superview === container { coordinator.videoView.removeFromSuperview() }
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
