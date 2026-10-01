import SwiftUI

@main
struct VektorTVApp: App {
    @State private var library = LibraryStore()
    @State private var playback = PlaybackStore()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            RootView(library: library, playback: playback)
                .tint(Theme.accent)
                .preferredColorScheme(.dark)
                .task(id: scenePhase) {
                    guard scenePhase == .active else { return }
                    await library.start()
                    await library.refreshIfNeeded()
                    while !Task.isCancelled {
                        do { try await Task.sleep(for: .seconds(300)) } catch { return }
                        await library.refreshIfNeeded()
                    }
                }
        }
    }
}

enum Theme {
    static let background = Color(red: 0.035, green: 0.047, blue: 0.059)
    static let surface = Color(red: 0.08, green: 0.10, blue: 0.12)
    static let accent = Color(red: 0.39, green: 0.87, blue: 0.75)
    static let text = Color(red: 0.94, green: 0.96, blue: 0.97)
    static let muted = Color(red: 0.66, green: 0.71, blue: 0.76)
    static let line = Color.white.opacity(0.10)
    #if os(tvOS)
    static let brandFont = Font.system(size: 28, weight: .medium)
    static let controlFont = Font.system(size: 26, weight: .medium)
    static let sectionFont = Font.system(size: 30, weight: .semibold)
    static let channelFont = Font.system(size: 25, weight: .medium)
    static let detailFont = Font.system(size: 22)
    static let bodyFont = Font.system(size: 26)
    static let programmeFont = Font.system(size: 40, weight: .semibold)
    static let pageInset: CGFloat = 30
    static let contentInset: CGFloat = 24
    static let headerInset: CGFloat = 8
    static let rowInset: CGFloat = 20
    static let logoSize: CGFloat = 34
    #else
    static let brandFont = Font.system(.title3, design: .default, weight: .medium)
    static let controlFont = Font.headline
    static let sectionFont = Font.title2.weight(.semibold)
    static let channelFont = Font.headline
    static let detailFont = Font.subheadline
    static let bodyFont = Font.body
    static let programmeFont = Font.title2.weight(.semibold)
    static let pageInset: CGFloat = 20
    static let contentInset: CGFloat = 18
    static let headerInset: CGFloat = 8
    static let rowInset: CGFloat = 16
    static let logoSize: CGFloat = 28
    #endif
}
