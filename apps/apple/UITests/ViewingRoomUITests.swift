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

    #if os(tvOS)
    func testMenuReturnsThroughWorkspaceHistoryWithoutExiting() {
        activate(app.buttons["TV Guide"])
        activate(app.buttons["Countries"])
        activate(app.buttons["Favorites"])
        XCUIRemote.shared.press(.menu)
        XCTAssertTrue(app.textFields["Find a country"].waitForExistence(timeout: 10))
        XCUIRemote.shared.press(.menu)
        XCTAssertTrue(app.buttons["Search programmes"].waitForExistence(timeout: 10))
        XCUIRemote.shared.press(.menu)
        XCTAssertTrue(app.buttons["Watch"].isSelected)
        XCUIRemote.shared.press(.menu)
        XCTAssertEqual(app.state, .runningForeground, "Menu at the root must keep VektorTV open")
        XCTAssertTrue(app.buttons["Watch"].isSelected)
        capture("Menu returned through workspace history")
    }

    func testMenuReturnsFromCountryChannelsAndDetails() {
        openNorway()
        activate(app.buttons["Explore Norway"])
        activate(app.buttons["Open group NORWAY HD & HEVC"])
        XCTAssertTrue(app.buttons["Channel group: NORWAY HD & HEVC"].waitForExistence(timeout: 10))
        XCUIRemote.shared.press(.menu)
        XCTAssertTrue(app.buttons["Open group NORWAY HD & HEVC"].waitForExistence(timeout: 10),
                      "Back from country channels must restore the country's groups")
        focus(app.buttons["Countries"])
        XCUIRemote.shared.press(.menu)
        XCTAssertTrue(app.textFields["Find a country"].waitForExistence(timeout: 10))
        XCUIRemote.shared.press(.menu)
        XCTAssertTrue(app.buttons["Watch"].isSelected)
        XCTAssertFalse(app.buttons["Back to countries"].exists, "Back must restore the original channel filters")
        XCTAssertEqual(app.state, .runningForeground)
        capture("Menu returned from country channels")
    }

    func testMenuDismissesSheetsBeforeWorkspaceHistory() {
        activate(app.buttons["TV Guide"])
        activate(app.buttons["Settings"])
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 10))
        focus(app.buttons["Done"])
        XCUIRemote.shared.press(.menu)
        XCTAssertTrue(app.buttons["Done"].waitForNonExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Search programmes"].waitForExistence(timeout: 10))
        activate(app.buttons["Search programmes"])
        XCTAssertTrue(app.buttons["Filters"].waitForExistence(timeout: 10))
        activate(app.buttons["Filters"])
        XCTAssertTrue(app.buttons["Reset filters"].waitForExistence(timeout: 10))
        XCUIRemote.shared.press(.menu)
        XCTAssertTrue(app.buttons["Reset filters"].waitForNonExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Filters"].waitForExistence(timeout: 10))
        XCUIRemote.shared.press(.menu)
        XCTAssertTrue(app.buttons["Filters"].waitForNonExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Search programmes"].waitForExistence(timeout: 10))
        XCUIRemote.shared.press(.menu)
        XCTAssertTrue(app.buttons["Watch"].isSelected)
        XCTAssertEqual(app.state, .runningForeground)
    }

    func testMenuCancelsFavoriteArrangementBeforeGoingBack() throws {
        activate(app.buttons["Favorites"])
        let first = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Watch '")).firstMatch
        try XCTSkipUnless(first.waitForExistence(timeout: 10), "Save a Favorite before this integration check.")
        let original = first.label
        focus(first)
        XCUIRemote.shared.press(.select, forDuration: 0.7)
        let status = app.staticTexts["favorite-arrangement-status"]
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        XCUIRemote.shared.press(.menu)
        XCTAssertTrue(status.waitForNonExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Favorites"].isSelected)
        XCTAssertEqual(first.label, original)
        XCUIRemote.shared.press(.menu)
        XCTAssertTrue(app.buttons["Watch"].isSelected)
        XCTAssertEqual(app.state, .runningForeground)
    }
    #endif

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
        #if os(tvOS)
        activate(app.buttons["Programme guide"])
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 10))
        XCUIRemote.shared.press(.menu)
        XCTAssertTrue(app.buttons["Done"].waitForNonExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Stop playback"].exists, "Dismissing the schedule must retain playback")
        #endif
        activate(app.buttons["Stop playback"])
        XCTAssertFalse(app.buttons["Stop playback"].exists)
        capture("Returned to channels after stop")
    }

    func testFavoritesShortcutArrangementAndRestart() throws {
        activate(app.buttons["Favorites"])
        let rows = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Watch '"))
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 15))
        try XCTSkipUnless(rows.count >= 2, "Save at least two Favorites in the simulator before this integration check.")
        let original = rows.allElementsBoundByIndex.map(\.label)
        let firstName = String(original[0].dropFirst("Watch ".count))
        let first = app.buttons[original[0]]
        #if os(tvOS)
        focus(first)
        XCUIRemote.shared.press(.select, forDuration: 0.7)
        #else
        first.press(forDuration: 0.7)
        #endif
        let status = app.staticTexts["favorite-arrangement-status"]
        XCTAssertTrue(status.waitForExistence(timeout: 10), "Hold and release must pick up the Favorite")
        #if os(tvOS)
        XCUIRemote.shared.press(.down)
        XCUIRemote.shared.press(.select)
        #else
        activate(app.buttons["Move favorite down"])
        activate(app.buttons["Drop"])
        #endif
        XCTAssertTrue(status.waitForNonExistence(timeout: 10))
        var expected = original
        expected.swapAt(0, 1)
        XCTAssertEqual(rows.allElementsBoundByIndex.map(\.label), expected)
        XCTAssertFalse(app.buttons["Stop playback"].exists, "Arranging must not start playback")
        capture("Favorites arranged")
        app.terminate()
        app.launch()
        activate(app.buttons["Favorites"])
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 15))
        XCTAssertEqual(rows.allElementsBoundByIndex.map(\.label), expected, "Favorite order must survive restart")
        // Restore the prior order and prove Cancel discards a preview.
        activate(app.buttons["Arrange \(firstName)"])
        #if os(tvOS)
        XCUIRemote.shared.press(.up)
        XCUIRemote.shared.press(.menu)
        #else
        activate(app.buttons["Move favorite up"])
        activate(app.buttons["Cancel"])
        #endif
        XCTAssertEqual(rows.allElementsBoundByIndex.map(\.label), expected)
        activate(app.buttons["Arrange \(firstName)"])
        #if os(tvOS)
        XCUIRemote.shared.press(.up)
        XCUIRemote.shared.press(.select)
        #else
        activate(app.buttons["Move favorite up"])
        activate(app.buttons["Drop"])
        #endif
        XCTAssertTrue(status.waitForNonExistence(timeout: 10))
        XCTAssertEqual(rows.allElementsBoundByIndex.map(\.label), original)
    }

    func testChannelZappingRetainsCategoryAndSearch() throws {
        openNorway()
        activate(app.buttons["Explore Norway"])
        activate(app.buttons["Open group NORWAY HD & HEVC"])
        let search = app.textFields["Find a channel"]
        #if os(tvOS)
        focus(search)
        XCUIRemote.shared.press(.select)
        app.typeText("NRK1 H")
        XCUIRemote.shared.press(.menu)
        #else
        search.tap()
        search.typeText("NRK1 H\n")
        #endif
        let rows = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Watch ' AND label CONTAINS[c] 'NRK1 H'"))
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 15))
        let names = rows.allElementsBoundByIndex.map { String($0.label.dropFirst(6)) }
        try XCTSkipUnless(names.count > 1, "The provider must have multiple NRK1 variants in this category.")
        activate(rows.firstMatch)
        XCTAssertTrue(app.staticTexts["LIVE"].waitForExistence(timeout: 35))
        activate(app.buttons["Next channel"])
        assertPlaying(names[1])
        activate(app.buttons["Previous channel"])
        assertPlaying(names[0])
        activate(app.buttons["Previous channel"])
        assertPlaying(names.last!)
        XCTAssertTrue(app.buttons["Channel group: NORWAY HD & HEVC"].exists)
        XCTAssertEqual(search.value as? String, "NRK1 H")
        capture("Zapping within category and search")
        activate(app.buttons["Next channel"])
        assertPlaying(names[0])
        activate(app.buttons["Stop playback"])
    }

    func testFavoritesZappingWrapsAndRetainsScope() throws {
        activate(app.buttons["Favorites"])
        let rows = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Watch '"))
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 15))
        let names = rows.allElementsBoundByIndex.map { String($0.label.dropFirst(6)) }
        try XCTSkipUnless(names.count > 1, "Save at least two Favorites before this integration check.")
        activate(rows.firstMatch)
        activate(app.buttons["Next channel"])
        assertPlaying(names[1])
        activate(app.buttons["Previous channel"])
        assertPlaying(names[0])
        activate(app.buttons["Previous channel"])
        assertPlaying(names.last!)
        capture("Zapping in saved Favorites order")
        // Browsing another folder must not replace the playback scope.
        openNorway()
        activate(app.buttons["Explore Norway"])
        activate(app.buttons["All channels A–Z"])
        activate(app.buttons["Next channel"])
        assertPlaying(names[0])
        activate(app.buttons["Stop playback"])
    }

    #if os(tvOS)
    func testFallbackRemoteZappingInFullScreen() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["VEKTORTV_ZAP_FALLBACK_CHECK"] == "1")
        activate(app.buttons["Favorites"])
        let rows = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Watch '"))
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 15))
        let names = rows.allElementsBoundByIndex.map { String($0.label.dropFirst(6)) }
        XCTAssertEqual(names.count, 2, "Configure the two live VLC fallback Favorites for this opt-in check.")
        activate(rows.firstMatch)
        XCTAssertTrue(app.staticTexts["LIVE"].waitForExistence(timeout: 65))
        activate(app.buttons["Full screen"])
        XCTAssertTrue(app.buttons["Pause playback"].waitForExistence(timeout: 10), "The test stream must use VLC fallback")
        XCUIRemote.shared.press(.right)
        assertPlaying(names[1], fullScreen: true)
        XCUIRemote.shared.press(.left)
        assertPlaying(names[0], fullScreen: true)
        capture("Fallback remote channel zap")
        XCUIRemote.shared.press(.menu)
        XCTAssertTrue(app.staticTexts["Your channels"].waitForExistence(timeout: 10))
        assertPlaying(names[0])
        activate(app.buttons["Stop playback"])
    }
    #endif

    private func assertPlaying(_ name: String, fullScreen: Bool = false) {
        let identifier = fullScreen ? "playing-channel-name" : "inline-playing-channel-name"
        let label = app.staticTexts.matching(NSPredicate(format: "identifier == %@ AND label == %@", identifier, name)).firstMatch
        XCTAssertTrue(label.waitForExistence(timeout: 15), "Expected scoped channel: \(name)")
    }

    /// Opt-in provider regression checks: availability is intentionally a live
    /// service observation, not a permanent assertion about these channel names.
    func testReportedPlaybackChannels() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["VEKTORTV_PLAYBACK_CHECK"] == "1")
        for name in ["UK| MTV XMAS", "UK| MTV 90S", "NOR| TVNORGE HD", "UK| NOW 70S", "UK| NOW 80S"] {
            let clearSearch = app.buttons["Clear channel search"]
            if clearSearch.exists { activate(clearSearch) }
            let search = app.textFields["Find a channel"]
            #if os(tvOS)
            focus(search)
            XCUIRemote.shared.press(.select)
            #else
            search.tap()
            #endif
            app.typeText(name)
            #if os(tvOS)
            XCUIRemote.shared.press(.menu)
            #else
            app.typeText("\n")
            #endif
            let channel = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Watch " + name)).firstMatch
            XCTAssertTrue(channel.waitForExistence(timeout: 15))
            activate(channel)
            if name.contains("NOW ") {
                XCTAssertTrue(app.staticTexts["LIVE"].waitForExistence(timeout: 65), "The fallback must decode output for \(name)")
                capture("Fallback " + name)
                activate(app.buttons["Full screen"])
                XCTAssertTrue(app.descendants(matching: .any)["full-screen-player"].waitForExistence(timeout: 10))
                // Capture after the presentation animation and video-surface layout.
                Thread.sleep(forTimeInterval: 2)
                capture("Fallback fullscreen " + name)
                #if os(tvOS)
                XCUIRemote.shared.press(.menu)
                #else
                app.buttons["Close full screen"].tap()
                #endif
                XCTAssertTrue(app.buttons["Stop playback"].waitForExistence(timeout: 10))
                XCTAssertTrue(app.staticTexts["LIVE"].exists)
                Thread.sleep(forTimeInterval: 2)
                capture("Fallback returned " + name)
            } else {
                XCTAssertTrue(app.staticTexts["Playback unavailable"].waitForExistence(timeout: 20))
                XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'provider returned an ended stream'")).firstMatch.exists)
                XCTAssertFalse(app.staticTexts["LIVE"].exists)
                capture("Offline " + name)
            }
            activate(app.buttons["Stop playback"])
        }
    }

    func testDiscoverySwitchWhilePlaying() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["VEKTORTV_DISCOVERY_CHECK"] == "1")
        func select(_ name: String) {
            let clear = app.buttons["Clear channel search"]
            if clear.exists { activate(clear) }
            let search = app.textFields["Find a channel"]
            #if os(tvOS)
            focus(search)
            XCUIRemote.shared.press(.select)
            app.typeText(name)
            XCUIRemote.shared.press(.menu)
            #else
            search.tap()
            search.typeText(name + "\n")
            #endif
            let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Watch " + name)).firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 15))
            activate(row)
            assertPlaying(name)
        }
        for name in ["D+| DISCOVERY HISTORY", "D+| DMAX"] {
            select(name)
            XCTAssertTrue(app.staticTexts["LIVE"].waitForExistence(timeout: 65))
            capture("Discovery before active switch " + name)
            // Select directly while the decoder runs, without Stop or waiting for failure.
            select("NOR| NRK1 HD")
            XCTAssertTrue(app.staticTexts["LIVE"].waitForExistence(timeout: 65))
            XCTAssertTrue(app.staticTexts["Your channels"].exists)
            capture("Recovered after active switch " + name)
            activate(app.buttons["Stop playback"])
        }
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
