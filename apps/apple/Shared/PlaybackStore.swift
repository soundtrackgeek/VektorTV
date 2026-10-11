import AVKit
import Observation
import SwiftUI
import VLCKit

@MainActor @Observable
final class PlaybackStore {
    let player = AVPlayer()
    var fallbackPlayer: VLCMediaPlayer?
    var usesFallbackSurface = false
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
    @ObservationIgnored private var browsingScope: ChannelQuery?
    @ObservationIgnored private var navigationGeneration = 0
    @ObservationIgnored private var navigationRequest = 0
    @ObservationIgnored private var navigationTask: Task<Channel?, Error>?

    func play(_ channel: Channel, library: LibraryStore, keepingScope: Bool = false) async {
        navigationGeneration += 1
        navigationTask?.cancel()
        navigationTask = nil
        if !keepingScope { browsingScope = library.channelQuery }
        await tune(channel, library: library)
    }

    /// Chain only the local neighbour lookups. Stream startup can be superseded,
    /// so every rapid swipe advances from the previous requested channel.
    func zap(_ direction: Int, library: LibraryStore) async -> Bool {
        guard let scope = browsingScope, let current = channel else { return false }
        let epoch = navigationGeneration
        navigationRequest += 1
        let request = navigationRequest
        let previous = navigationTask
        let lookup = Task { @MainActor () throws -> Channel? in
            let anchor = try await previous?.value ?? current
            guard epoch == navigationGeneration, !Task.isCancelled else { throw CancellationError() }
            let neighbour: ChannelNeighbour = try await library.call(CoreRequest(command: "adjacent", query: scope, id: anchor.id, direction: direction))
            return neighbour.channel
        }
        navigationTask = lookup
        do {
            guard let next = try await lookup.value, epoch == navigationGeneration else { return false }
            if request == navigationRequest { await tune(next, library: library, preservingSurface: true) }
            return epoch == navigationGeneration
        } catch {
            if epoch == navigationGeneration, request == navigationRequest {
                navigationTask = nil
                library.message = error.localizedDescription
            }
            return false
        }
    }

    private func tune(_ channel: Channel, library: LibraryStore, preservingSurface: Bool = false) async {
        let fullScreen = isPresented
        generation += 1
        clearPlayers(keepingNativeItem: preservingSurface)
        recordedID = nil
        error = nil
        isPaused = false
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
        usesFallbackSurface = true
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
        usesFallbackSurface = fallbackPlayer != nil
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
    private func clearPlayers(keepingNativeItem: Bool = false) {
        monitorTask?.cancel()
        monitorTask = nil
        itemObservation = nil
        player.pause()
        // Retain the paused live item during AVKit channel flipping so the
        // system continues accepting swipes while the next stream resolves.
        if !keepingNativeItem { player.replaceCurrentItem(with: nil) }
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
        navigationGeneration += 1
        navigationTask?.cancel()
        navigationTask = nil
        browsingScope = nil
        usesFallbackSurface = false
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
    var onZap: ((Int) -> Void)? = nil
    func makeUIView(context: Context) -> UIView {
        #if os(tvOS)
        let container = RemotePlayerSurface()
        container.isUserInteractionEnabled = onZap != nil
        if onZap != nil {
            for direction in [-1, 1] {
                let swipe = UISwipeGestureRecognizer(target: context.coordinator, action: direction == 1 ? #selector(Coordinator.nextChannel) : #selector(Coordinator.previousChannel))
                swipe.direction = direction == 1 ? .right : .left
                swipe.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.indirect.rawValue)]
                container.addGestureRecognizer(swipe)
                let press = UITapGestureRecognizer(target: context.coordinator, action: direction == 1 ? #selector(Coordinator.nextChannel) : #selector(Coordinator.previousChannel))
                press.allowedPressTypes = [NSNumber(value: direction == 1 ? UIPress.PressType.rightArrow.rawValue : UIPress.PressType.leftArrow.rawValue)]
                container.addGestureRecognizer(press)
            }
        }
        #else
        let container = UIView()
        container.isUserInteractionEnabled = false
        #endif
        container.backgroundColor = .black
        attach(to: container)
        return container
    }
    func updateUIView(_ container: UIView, context: Context) {
        context.coordinator.onZap = onZap
        attach(to: container)
    }
    private func attach(to container: UIView) {
        guard videoView.superview !== container else { return }
        videoView.removeFromSuperview()
        videoView.frame = container.bounds
        videoView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.addSubview(videoView)
    }
    func makeCoordinator() -> Coordinator { Coordinator(videoView, onZap: onZap) }
    final class Coordinator: NSObject {
        let videoView: UIView
        var onZap: ((Int) -> Void)?
        init(_ videoView: UIView, onZap: ((Int) -> Void)?) { self.videoView = videoView; self.onZap = onZap }
        @objc func nextChannel() { onZap?(1) }
        @objc func previousChannel() { onZap?(-1) }
    }
    static func dismantleUIView(_ container: UIView, coordinator: Coordinator) {
        if coordinator.videoView.superview === container { coordinator.videoView.removeFromSuperview() }
    }
}

#if os(tvOS)
private final class RemotePlayerSurface: UIView {
    override var canBecomeFocused: Bool { isUserInteractionEnabled }
}
#endif

struct NativePlayer: UIViewControllerRepresentable {
    let player: AVPlayer
    var onExit: () -> Void = {}
    var onZap: (Int) async -> Bool = { _ in false }
    func makeCoordinator() -> Coordinator { Coordinator(onExit: onExit, onZap: onZap) }
    final class Coordinator: NSObject, AVPlayerViewControllerDelegate {
        var onExit: () -> Void
        var onZap: (Int) async -> Bool
        init(onExit: @escaping () -> Void, onZap: @escaping (Int) async -> Bool) { self.onExit = onExit; self.onZap = onZap }
        #if os(tvOS)
        func playerViewController(_ playerViewController: AVPlayerViewController, skipToNextChannel completion: @escaping (Bool) -> Void) {
            // AVKit dismisses its channel interstitial from this completion.
            // An unisolated Task resumes off the main thread after onZap returns.
            Task { @MainActor in completion(await onZap(1)) }
        }
        func playerViewController(_ playerViewController: AVPlayerViewController, skipToPreviousChannel completion: @escaping (Bool) -> Void) {
            Task { @MainActor in completion(await onZap(-1)) }
        }
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
        context.coordinator.onZap = onZap
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
