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
        stop()
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
            #if os(tvOS)
            isPresented = true
            #endif
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
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        #if os(iOS)
        controller.allowsPictureInPicturePlayback = true
        #endif
        return controller
    }
    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        if controller.player !== player { controller.player = player }
    }
}
