import SwiftUI

@main
struct VektorTVApp: App {
    @State private var library = LibraryStore()
    @State private var playback = PlaybackStore()
    var body: some Scene {
        WindowGroup {
            RootView(library: library, playback: playback)
                .tint(Theme.accent)
                .preferredColorScheme(.dark)
                .task { await library.start() }
        }
    }
}

enum Theme {
    static let background = Color(red: 0.025, green: 0.045, blue: 0.065)
    static let surface = Color(red: 0.055, green: 0.085, blue: 0.105)
    static let accent = Color(red: 0.28, green: 0.86, blue: 0.76)
}
