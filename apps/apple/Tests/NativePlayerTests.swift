import AVKit
import XCTest
import VLCKit
@testable import VektorTV_tvOS

final class NativePlayerTests: XCTestCase {
    @MainActor
    func testFallbackCallbacksAndActiveTeardown() async throws {
        // Local PCM audio makes this independent of provider availability/codecs.
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
        var wav = Data()
        func word(_ value: UInt32, bytes: Int = 4) {
            for byte in 0..<bytes { wav.append(UInt8(truncatingIfNeeded: value >> (byte * 8))) }
        }
        let sampleRate: UInt32 = 44100
        let samples = sampleRate * 3
        wav.append(Data("RIFF".utf8)); word(36 + samples * 2)
        wav.append(Data("WAVEfmt ".utf8)); word(16); word(1, bytes: 2); word(1, bytes: 2)
        word(sampleRate); word(sampleRate * 2); word(2, bytes: 2); word(16, bytes: 2)
        wav.append(Data("data".utf8)); word(samples * 2)
        for sample in 0..<samples {
            let amplitude = Int16(sin(Double(sample) * 440 * 2 * .pi / Double(sampleRate)) * 8000)
            word(UInt32(UInt16(bitPattern: amplitude)), bytes: 2)
        }
        try wav.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let store = PlaybackStore()
        for _ in 0..<5 {
            let playing = expectation(description: "VLC reached playing on main queue")
            playing.assertForOverFulfill = false
            var fallback: VLCMediaPlayer? = VLCMediaPlayer(options: ["--quiet", "--no-video-title-show"])
            weak var released = fallback
            let observer = NotificationCenter.default.addObserver(forName: VLCMediaPlayer.stateChangedNotification,
                                                                  object: fallback, queue: nil) { notification in
                XCTAssertTrue(Thread.isMainThread, "VLC callbacks must leave the locked decoder thread")
                if (notification.object as? VLCMediaPlayer)?.state == .playing { playing.fulfill() }
            }
            fallback?.media = VLCMedia(url: url)
            fallback?.drawable = store.fallbackSurface
            store.fallbackPlayer = fallback
            fallback?.play()
            await fulfillment(of: [playing], timeout: 10)
            let deadline = Date.now.addingTimeInterval(5)
            while (fallback?.media?.statistics.decodedAudio ?? 0) == 0 && Date.now < deadline {
                try await Task.sleep(for: .milliseconds(25))
            }
            XCTAssertGreaterThan(fallback?.media?.statistics.decodedAudio ?? 0, 0)
            // This is the same stop/release path used for channel changes and errors.
            store.stop()
            fallback = nil
            let releaseDeadline = Date.now.addingTimeInterval(5)
            while released != nil && Date.now < releaseDeadline { try await Task.sleep(for: .milliseconds(25)) }
            XCTAssertNil(released, "Stopping must release the player after pending callbacks")
            NotificationCenter.default.removeObserver(observer)
        }
    }

    @MainActor
    func testChannelFlipCompletionsReturnToMainThreadAfterAsyncLookup() async {
        let controller = AVPlayerViewController()
        for direction in [1, -1] {
            for succeeded in [true, false] {
                let completed = expectation(description: "Channel flip \(direction), success \(succeeded)")
                let coordinator = NativePlayer.Coordinator(onExit: {}, onZap: { requestedDirection in
                    XCTAssertEqual(requestedDirection, direction)
                    // Neighbour lookup and stream preflight suspend before AVKit dismisses its UI.
                    try? await Task.sleep(for: .milliseconds(10))
                    return succeeded
                })
                let completion: (Bool) -> Void = { result in
                    XCTAssertTrue(Thread.isMainThread, "AVKit dismisses its swipe interstitial in this callback")
                    XCTAssertEqual(result, succeeded)
                    completed.fulfill()
                }
                if direction == 1 {
                    coordinator.playerViewController(controller, skipToNextChannel: completion)
                } else {
                    coordinator.playerViewController(controller, skipToPreviousChannel: completion)
                }
                await fulfillment(of: [completed], timeout: 5)
            }
        }
    }
}
