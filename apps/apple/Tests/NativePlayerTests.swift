import AVKit
import XCTest
@testable import VektorTV_tvOS

final class NativePlayerTests: XCTestCase {
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
