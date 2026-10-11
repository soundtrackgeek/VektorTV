import SwiftUI

private enum WorkspaceTab: String, CaseIterable {
    case watch = "Watch"
    case guide = "TV Guide"
    case countries = "Countries"
    case favorites = "Favorites"
}

struct RootView: View {
    @Bindable var library: LibraryStore
    @Bindable var playback: PlaybackStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var tab = WorkspaceTab.watch
    @State private var settingsPresented = false
    @State private var scheduleChannel: Channel?
    @State private var guideChannel: Channel?
    @State private var programmeSearchPresented = false

    private var queryKey: String {
        "\(library.search)|\(library.group ?? "")|\(library.section.rawValue)|\(library.countryCode ?? "")|\(library.hasAccount)"
    }

    var body: some View {
        Group {
            if !library.startupComplete {
                ProgressView("Opening VektorTV…")
            } else if !library.hasAccount {
                NavigationStack { SettingsView(library: library, playback: playback) }
            } else {
                GeometryReader { geometry in
                    #if os(tvOS)
                    workspace(wide: true)
                    #else
                    workspace(wide: geometry.size.width >= 800 && !dynamicTypeSize.isAccessibilitySize)
                    #endif
                }
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .task(id: queryKey) {
            guard library.hasAccount else { return }
            do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
            await library.reload()
        }
        .sheet(isPresented: $settingsPresented) {
            NavigationStack {
                SettingsView(library: library, playback: playback)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { settingsPresented = false } } }
            }
        }
        .sheet(isPresented: $programmeSearchPresented) {
            NavigationStack {
                ProgrammeSearchView(library: library) { channel in
                    programmeSearchPresented = false
                    tab = .watch
                    Task { await playback.play(channel, library: library) }
                }
            }
        }
        .sheet(item: $scheduleChannel) { channel in
            NavigationStack { ScheduleView(channel: channel, library: library, playback: playback) }
        }
        .fullScreenCover(isPresented: $playback.isPresented) {
            FullScreenPlayer(playback: playback, library: library)
        }
        .onChange(of: library.section) { _, section in
            if tab == .favorites && section != .favorites { tab = .watch }
            else if tab == .watch && section == .favorites { tab = .favorites }
        }
        .onChange(of: library.hasAccount) { _, connected in
            if !connected { settingsPresented = false; guideChannel = nil }
        }
    }

    private func workspace(wide: Bool) -> some View {
        NavigationStack {
            VStack(spacing: 0) {
                header(wide: wide)
                Rectangle().fill(Theme.line).frame(height: 1)
                if let message = library.message {
                    StatusBanner(message: message) { library.message = nil }
                }
                if library.isLoadingGuide {
                    ProgressView("Loading the programme guide for all channels…")
                        .font(Theme.detailFont).padding(8)
                }
                if let message = library.guideMessage {
                    StatusBanner(message: "Guide: \(message)") { library.guideMessage = nil }
                }
                if tab == .guide {
                    HStack {
                        Text("Explore channel schedules or search every guide.")
                            .font(Theme.detailFont).foregroundStyle(Theme.muted)
                        Spacer()
                        Button { programmeSearchPresented = true } label: {
                            Label("Search programmes", systemImage: "magnifyingglass")
                        }.buttonStyle(CinemaButtonStyle()).font(Theme.detailFont)
                    }.padding(.horizontal, Theme.pageInset).padding(.vertical, 8)
                }
                if tab == .countries {
                    CountryBrowser(library: library) { country, group in
                        library.openCountry(country, group: group)
                        tab = .watch
                    }
                } else if wide {
                    GeometryReader { geometry in
                        HStack(spacing: 0) {
                            channelBrowser(wide: true)
                                .frame(width: min(480, max(290, geometry.size.width * 0.29)))
                            Rectangle().fill(Theme.line).frame(width: 1)
                            if tab == .guide {
                                if let channel = guideChannel {
                                    ScheduleContent(channel: channel, library: library, playback: playback, onWatch: { tab = .watch })
                                        .id(channel.id)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                } else {
                                    ContentUnavailableView("What's on next", systemImage: "calendar",
                                        description: Text("Choose a channel to explore its programme schedule."))
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                }
                            } else {
                                ViewingRoom(library: library, playback: playback, compact: false,
                                    availableHeight: geometry.size.height, schedule: { scheduleChannel = $0 })
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                                    #if os(tvOS)
                                    .focusSection()
                                    #endif
                            }
                        }
                        #if os(tvOS)
                        .focusSection()
                        .padding(.top, 18)
                        #endif
                    }
                } else {
                    channelBrowser(wide: false)
                }
                if tab != .watch && tab != .favorites, playback.channel != nil {
                    NowPlayingBar(playback: playback) { tab = .watch }
                }
            }
            .background(Theme.background)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func channelBrowser(wide: Bool) -> some View {
        ChannelBrowser(library: library, playback: playback, guide: tab == .guide,
            wide: wide, queryKey: queryKey,
            showCountries: { tab = .countries },
            selectedGuideID: guideChannel?.id,
            schedule: { channel in
                if wide && tab == .guide { guideChannel = channel }
                else { scheduleChannel = channel }
            })
    }

    private func header(wide: Bool) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 20) {
                HStack(spacing: 3) {
                    Text("VEKTOR").foregroundStyle(Theme.text)
                    Text("TV").foregroundStyle(Theme.accent)
                }
                .font(Theme.brandFont).tracking(4)
                .accessibilityElement(children: .ignore).accessibilityLabel("VektorTV")
                Spacer(minLength: 10)
                if wide { navigationTabs }
                Spacer(minLength: 10)
                Button { settingsPresented = true } label: {
                    Image(systemName: "gearshape").font(Theme.controlFont).frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(CinemaButtonStyle())
                .accessibilityLabel("Settings")
            }
            if !wide { ScrollView(.horizontal) { navigationTabs }.scrollIndicators(.hidden) }
        }
        .padding(.horizontal, Theme.pageInset)
        .padding(.vertical, Theme.headerInset)
        #if os(tvOS)
        .focusSection()
        #endif
    }

    private var navigationTabs: some View {
        HStack(spacing: 4) {
            ForEach(WorkspaceTab.allCases, id: \.self) { item in
                Button {
                    if item == .favorites { library.openFavorites() }
                    else if item == .watch && library.section == .favorites { library.section = .live }
                    tab = item
                } label: {
                    Text(item.rawValue)
                        .font(Theme.controlFont)
                        .foregroundStyle(tab == item ? Theme.text : Theme.muted)
                        .padding(.horizontal, 6).padding(.vertical, 12)
                        .overlay(alignment: .bottom) {
                            Capsule().fill(tab == item ? Theme.accent : .clear).frame(height: 3)
                                .padding(.horizontal, 16)
                        }
                }
                .buttonStyle(CinemaButtonStyle(horizontalInset: 2))
                .accessibilityAddTraits(tab == item ? .isSelected : [])
            }
        }
    }
}

struct FullScreenPlayer: View {
    @Bindable var playback: PlaybackStore
    let library: LibraryStore
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            if playback.usesFallbackSurface {
                FallbackPlayer(videoView: playback.fallbackSurface, onZap: { direction in
                    Task { await playback.zap(direction, library: library) }
                }).ignoresSafeArea().accessibilityIdentifier("full-screen-player")
            } else {
                NativePlayer(player: playback.player, onExit: { playback.isPresented = false },
                    onZap: { await playback.zap($0, library: library) }).ignoresSafeArea()
            }
            if playback.isLoading {
                ProgressView("Connecting to live stream…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if let error = playback.error {
                VStack(spacing: 24) {
                    ContentUnavailableView("Playback unavailable", systemImage: "exclamationmark.tv", description: Text(error))
                    Button("Retry channel") {
                        if let channel = playback.channel { Task { await playback.play(channel, library: library, keepingScope: true) } }
                    }.buttonStyle(CinemaButtonStyle(prominent: true))
                    HStack(spacing: 24) {
                        Button("Previous channel") { Task { await playback.zap(-1, library: library) } }
                        Button("Next channel") { Task { await playback.zap(1, library: library) } }
                    }.buttonStyle(CinemaButtonStyle())
                    Button("Back to channels") { playback.isPresented = false }
                        .buttonStyle(CinemaButtonStyle())
                }.frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.background)
            }
            #if os(iOS)
            Button { playback.isPresented = false } label: {
                Image(systemName: "xmark.circle.fill").font(.title).padding()
            }.accessibilityLabel("Close full screen")
            #endif
        }
        .overlay(alignment: .bottom) {
            if playback.usesFallbackSurface && playback.error == nil {
                HStack(spacing: 24) {
                    Button("Previous channel") { Task { await playback.zap(-1, library: library) } }
                    Button(playback.isPaused ? "Resume playback" : "Pause playback") { playback.togglePause() }
                        .disabled(playback.isLoading)
                    Button("Next channel") { Task { await playback.zap(1, library: library) } }
                    Button("Stop playback") { playback.stop() }
                }.buttonStyle(CinemaButtonStyle()).padding()
            }
        }
        .overlay(alignment: .topLeading) {
            if let channel = playback.channel {
                Text(channel.name).font(Theme.detailFont).padding().background(.black.opacity(0.65))
                    .accessibilityIdentifier("playing-channel-name").allowsHitTesting(false)
            }
        }
        #if os(tvOS)
        .onExitCommand { playback.isPresented = false }
        .onPlayPauseCommand { playback.togglePause() }
        #endif
    }
}

struct NowPlayingBar: View {
    @Bindable var playback: PlaybackStore
    let returnToWatch: () -> Void
    var body: some View {
        HStack(spacing: 16) {
            Button(action: returnToWatch) {
                Label(playback.channel?.name ?? "Live TV", systemImage: "speaker.wave.2")
                    .lineLimit(1)
            }.buttonStyle(CinemaButtonStyle())
            Spacer()
            Button { playback.isPresented = true } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                .buttonStyle(CinemaButtonStyle()).accessibilityLabel("Full screen")
            Button { playback.stop() } label: { Image(systemName: "stop.fill") }
                .buttonStyle(CinemaButtonStyle()).accessibilityLabel("Stop playback")
        }.font(Theme.detailFont).padding(Theme.contentInset).background(Theme.surface)
    }
}
