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

    func testGlobalProgrammeSearchAndEmptyState() {
        activate(app.buttons["TV Guide"])
        activate(app.buttons["Search programmes"])
        let search = app.textFields["Search all programmes"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        let result = app.buttons.matching(identifier: "programme-search-result").firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 30), "Imported guides should be searchable across the whole catalog")
        capture("Global programme search")
        #if os(tvOS)
        focus(search)
        XCUIRemote.shared.press(.select)
        app.typeText("zznonexistentprogramme123")
        XCUIRemote.shared.press(.menu)
        #else
        search.tap()
        search.typeText("zznonexistentprogramme123\n")
        #endif
        capture("Programme query entered")
        XCTAssertTrue(app.staticTexts["0 programmes found"].waitForExistence(timeout: 30))
        XCTAssertFalse(result.exists, "Old results must disappear when the search changes")
        activate(app.buttons["Filters"])
        XCTAssertTrue(app.navigationBars["Programme filters"].waitForExistence(timeout: 10))
        capture("Programme filters")
    }

    func testCountriesFavoritesGroupsAndAlphabeticalChannels() {
        openNorway()
        let wasFavorite = app.buttons["Unfavorite country Norway"].exists
        activate(app.buttons[wasFavorite ? "Unfavorite country Norway" : "Favorite country Norway"])
        XCTAssertTrue(app.buttons[wasFavorite ? "Favorite country Norway" : "Unfavorite country Norway"].waitForExistence(timeout: 10))
        capture("Country flag and favorite")
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["Your channels"].waitForExistence(timeout: 15))
        openNorway()
        XCTAssertTrue(app.buttons[wasFavorite ? "Favorite country Norway" : "Unfavorite country Norway"].exists, "Country favorite must survive restart")
        activate(app.buttons["Explore Norway"])
        XCTAssertTrue(app.buttons["All channels A–Z"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Open group NORWAY HD & HEVC"].exists)
        capture("Norway groups")
        activate(app.buttons["All channels A–Z"])
        XCTAssertTrue(app.buttons["Back to countries"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["All channels A–Z"].exists)
        let channels = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Watch '"))
        XCTAssertTrue(channels.firstMatch.waitForExistence(timeout: 10))
        capture("Country channels A to Z")
        activate(app.buttons["Countries"])
        findNorway()
        activate(app.buttons[wasFavorite ? "Favorite country Norway" : "Unfavorite country Norway"])
        XCTAssertTrue(app.buttons[wasFavorite ? "Unfavorite country Norway" : "Favorite country Norway"].waitForExistence(timeout: 10))
        activate(app.buttons["Explore Norway"])
        activate(app.buttons["Open group NORWAY HD & HEVC"])
        XCTAssertTrue(app.buttons["Channel group: NORWAY HD & HEVC"].waitForExistence(timeout: 10))
        XCTAssertTrue(channels.firstMatch.waitForExistence(timeout: 10))
        activate(app.buttons["Clear country filter"])
    }

    private func openNorway() {
        activate(app.buttons["Countries"])
        findNorway()
    }
    private func findNorway() {
        let search = app.textFields["Find a country"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        #if os(tvOS)
        focus(search)
        XCUIRemote.shared.press(.select)
        app.typeText("Norway")
        XCUIRemote.shared.press(.menu)
        #else
        search.tap()
        search.typeText("Norway\n")
        #endif
        XCTAssertTrue(app.buttons["Explore Norway"].waitForExistence(timeout: 10))
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
