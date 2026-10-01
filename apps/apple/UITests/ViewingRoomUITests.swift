import XCTest

/// Integration smoke tests use the simulator's explicitly configured account and cached catalog.
/// No credentials or service data are embedded in the test bundle.
@MainActor
final class ViewingRoomUITests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
        try XCTSkipUnless(app.staticTexts["Your channels"].waitForExistence(timeout: 15),
                          "Configure the simulator account with run-development.py before these integration tests.")
    }

    func testSearchPlaybackAndReturnFromFullScreen() throws {
        let search = app.textFields["Find a channel"]
        #if os(tvOS)
        focus(search)
        XCUIRemote.shared.press(.select)
        app.typeText("NOR| NRK1")
        XCUIRemote.shared.press(.menu)
        #else
        search.tap()
        search.typeText("NOR| NRK1\n")
        #endif
        let channel = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Watch ' AND label CONTAINS[c] 'NRK1'")).firstMatch
        XCTAssertTrue(channel.waitForExistence(timeout: 15))
        activate(channel)
        let fullScreen = app.buttons["Full screen"]
        XCTAssertTrue(fullScreen.waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Your channels"].exists, "Channel selection must stay inline")
        XCTAssertTrue(app.staticTexts["LIVE"].waitForExistence(timeout: 35), "The configured test channel must start live playback")
        let originalFavoriteAction = app.buttons["Add to favorites"].exists ? "Add to favorites" : "Remove from favorites"
        let oppositeFavoriteAction = originalFavoriteAction == "Add to favorites" ? "Remove from favorites" : "Add to favorites"
        activate(app.buttons[originalFavoriteAction])
        XCTAssertTrue(app.buttons[oppositeFavoriteAction].waitForExistence(timeout: 10))
        activate(app.buttons[oppositeFavoriteAction])
        XCTAssertTrue(app.buttons[originalFavoriteAction].waitForExistence(timeout: 10))
        capture("Inline viewing room")
        activate(fullScreen)
        let player = app.descendants(matching: .any)["full-screen-player"]
        XCTAssertTrue(player.waitForExistence(timeout: 10))
        capture("Full-screen player")
        #if os(tvOS)
        XCUIRemote.shared.press(.menu)
        #else
        let close = app.buttons["Close full screen"]
        XCTAssertTrue(close.waitForExistence(timeout: 10))
        close.tap()
        #endif
        XCTAssertTrue(player.waitForNonExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Your channels"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Stop playback"].waitForExistence(timeout: 10), "Returning from full screen must retain the selected stream")
        activate(app.buttons["Stop playback"])
        XCTAssertFalse(app.buttons["Stop playback"].exists)
        capture("Returned to channels after stop")
    }

    #if os(tvOS)
    func testRemoteScrollingRetainsVisibleFocus() {
        let channel = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Watch '")).firstMatch
        XCTAssertTrue(channel.waitForExistence(timeout: 10))
        focus(channel)
        for _ in 0..<15 {
            XCUIRemote.shared.press(.down)
            assertFocusVisible()
        }
        for _ in 0..<10 {
            XCUIRemote.shared.press(.up)
            assertFocusVisible()
        }
        capture("Remote-scrolled channel list")
    }
    #endif

    func testGuideAndGroupNavigation() {
        activate(app.buttons["TV Guide"])
        let channel = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Programme guide for '")).firstMatch
        XCTAssertTrue(channel.waitForExistence(timeout: 10))
        activate(channel)
        XCTAssertTrue(app.buttons["Watch live"].waitForExistence(timeout: 15))
        capture("Programme guide")
        #if os(tvOS)
        activate(app.buttons["Watch"])
        #else
        if app.buttons["Done"].exists { app.buttons["Done"].tap() }
        app.buttons["Watch"].tap()
        #endif
        let groups = app.buttons["Channel group: All groups"]
        activate(groups)
        XCTAssertTrue(app.navigationBars["Channel groups"].waitForExistence(timeout: 10))
        capture("Channel groups")
    }

    private func activate(_ element: XCUIElement) {
        #if os(tvOS)
        focus(element)
        XCUIRemote.shared.press(.select)
        #else
        if !element.isHittable { app.swipeUp() }
        element.tap()
        #endif
    }

    #if os(tvOS)
    private func focus(_ target: XCUIElement) {
        var previous = ""
        var stalled = 0
        for _ in 0..<40 {
            if target.hasFocus { return }
            let focused = app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == YES")).firstMatch
            let source = focused.frame
            let destination = target.frame
            let position = "\(focused.label) \(source)"
            print("Focus: \(position) -> \(target.label) \(destination)")
            stalled = position == previous ? stalled + 1 : 0
            let horizontalFirst = abs(destination.midX - source.midX) > max(200, source.width / 2)
            if (horizontalFirst && stalled % 2 == 0) || (!horizontalFirst && stalled % 2 == 1) {
                XCUIRemote.shared.press(destination.midX > source.midX ? .right : .left)
            } else if abs(destination.midY - source.midY) > max(25, source.height / 2) {
                XCUIRemote.shared.press(destination.midY > source.midY ? .down : .up)
            } else {
                XCUIRemote.shared.press(destination.midX > source.midX ? .right : .left)
            }
            previous = position
        }
        XCTFail("Could not focus \(target.label)")
    }

    private func assertFocusVisible() {
        let focused = app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == YES")).firstMatch
        XCTAssertTrue(focused.exists)
        XCTAssertTrue(app.frame.contains(focused.frame), "Focused control must remain inside the screen")
    }
    #endif

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
