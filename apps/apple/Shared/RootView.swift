import SwiftUI

struct RootView: View {
    @Bindable var library: LibraryStore
    @Bindable var playback: PlaybackStore
    @State private var tab = "watch"
    @State private var settingsPresented = false

    var body: some View {
        Group {
            if !library.startupComplete {
                ProgressView("Opening VektorTV…")
            } else if !library.hasAccount {
                NavigationStack { SettingsView(library: library, playback: playback) }
            } else {
                TabView(selection: $tab) {
                    Tab("Watch", systemImage: "tv", value: "watch") {
                        NavigationStack { ChannelBrowser(library: library, playback: playback, guide: false) }
                    }
                    Tab("TV Guide", systemImage: "calendar", value: "guide") {
                        NavigationStack { ChannelBrowser(library: library, playback: playback, guide: true) }
                    }
                    Tab("Settings", systemImage: "gearshape", value: "settings") {
                        NavigationStack { SettingsView(library: library, playback: playback) }
                    }
                }
                #if os(iOS)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if playback.channel != nil { MiniPlayer(playback: playback, library: library) }
                }
                #endif
            }
        }
        .background(Theme.background)
        .fullScreenCover(isPresented: $playback.isPresented, onDismiss: {
            #if os(tvOS)
            playback.stop()
            #endif
        }) {
            ZStack(alignment: .topTrailing) {
                NativePlayer(player: playback.player).ignoresSafeArea()
                if playback.isLoading { ProgressView("Connecting to live stream…").padding(30).frame(maxWidth: .infinity, maxHeight: .infinity) }
                if let error = playback.error {
                    VStack(spacing: 20) {
                        ContentUnavailableView("Playback unavailable", systemImage: "exclamationmark.tv", description: Text(error))
                        Button("Retry") { if let channel = playback.channel { Task { await playback.play(channel, library: library) } } }
                        Button("Back to channels") { playback.stop() }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.background)
                }
                #if os(iOS)
                Button { playback.isPresented = false } label: { Image(systemName: "xmark.circle.fill").font(.title).padding() }
                    .accessibilityLabel("Close full screen")
                #endif
            }
            #if os(tvOS)
            .onExitCommand { playback.stop() }
            #endif
        }
    }
}

struct ChannelBrowser: View {
    @Bindable var library: LibraryStore
    let playback: PlaybackStore
    let guide: Bool
    @State private var scheduleChannel: Channel?
    private var queryKey: String { "\(library.search)|\(library.group ?? "")|\(library.section.rawValue)|\(library.hasAccount)" }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("VEKTOR TV").font(.caption.weight(.bold)).tracking(3).foregroundStyle(Theme.accent)
                    Text(guide ? "What's on tonight" : "Your viewing room").font(.title2.weight(.semibold))
                    Text("\(library.catalogCount.formatted()) channels · \(library.isLoadingGuide ? "Guide updating" : "Live television")")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                #if os(tvOS)
                TextField("Find a channel", text: $library.search)
                    .autocorrectionDisabled()
                    .frame(width: 460)
                    .accessibilityLabel("Find a channel")
                if !library.search.isEmpty {
                    Button { library.search = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.borderless).accessibilityLabel("Clear channel search")
                }
                #endif
                if library.isRefreshing { ProgressView() }
                else { Button { Task { await library.connect(library.connection) } } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.borderless).accessibilityLabel("Refresh channels and guide") }
            }.padding()
            HStack {
                Picker("Library", selection: $library.section) {
                    ForEach(LibrarySection.allCases) { section in
                        Label(section.rawValue, systemImage: section.symbol).tag(section)
                    }
                }
                #if os(iOS)
                .pickerStyle(.menu)
                #endif
                Spacer()
                NavigationLink {
                    GroupChooser(library: library)
                } label: {
                    Label(library.group ?? "All groups", systemImage: "line.3.horizontal.decrease")
                        .lineLimit(1)
                }
                .buttonStyle(.borderless)
            }.padding(.horizontal).padding(.bottom, 10)
            if let message = library.message { StatusBanner(message: message, dismiss: { library.message = nil }) }
            if let message = library.guideMessage { StatusBanner(message: "Guide: \(message)", dismiss: { library.guideMessage = nil }) }
            if library.isLoading && library.channels.isEmpty {
                ProgressView("Loading channels…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if library.channels.isEmpty {
                ContentUnavailableView("No channels here", systemImage: library.section.symbol,
                    description: Text(library.section == .favorites ? "Save channels with the star button to find them here." : "Try another group or search, or refresh your account."))
            } else {
                ScrollViewReader { scroll in
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(library.channels) { channel in
                                ChannelRow(channel: channel, selected: playback.channel?.id == channel.id,
                                    guide: guide,
                                    play: { Task { await playback.play(channel, library: library) } },
                                    favorite: { Task { await library.toggleFavorite(channel) } },
                                    schedule: { scheduleChannel = channel },
                                    onFocus: { scroll.scrollTo(channel.id, anchor: .center) })
                                    .id(channel.id)
                            }
                            if library.channels.count < library.total {
                                Button { Task { await library.reload(more: true) } } label: {
                                    if library.isLoading { ProgressView() }
                                    else { Text("Load more · \(library.channels.count.formatted()) of \(library.total.formatted())") }
                                }.disabled(library.isLoading).padding()
                            }
                        }
                        .padding()
                        #if os(tvOS)
                        .focusSection()
                        #endif
                    }
                    // A new query starts at the top, including after an empty result.
                    .id(queryKey)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.background)
        #if os(iOS)
        .navigationTitle(guide ? "TV Guide" : "Watch")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $library.search, prompt: "Find a channel")
        #else
        // The native tvOS searchable container reserves space for an inline keyboard
        // above the results even while browsing. TextField opens the system editor on demand.
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .task(id: queryKey) {
            do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
            await library.reload()
        }
        .sheet(item: $scheduleChannel) { channel in
            NavigationStack { ScheduleView(channel: channel, library: library, playback: playback) }
        }
    }
}

struct ChannelRow: View {
    let channel: Channel
    let selected: Bool
    let guide: Bool
    let play: () -> Void
    let favorite: () -> Void
    let schedule: () -> Void
    var onFocus: () -> Void = {}
    #if os(tvOS)
    @FocusState private var isFocused: Bool
    #endif
    private var backgroundColor: Color {
        #if os(tvOS)
        if isFocused { return Theme.accent.opacity(0.18) }
        #endif
        return selected ? Theme.accent.opacity(0.1) : Theme.surface
    }
    var body: some View {
        HStack(spacing: 6) {
            Button(action: guide ? schedule : play) {
                HStack(spacing: 10) {
                    ChannelLogo(channel: channel)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(channel.name).font(.headline).foregroundStyle(.white).lineLimit(2)
                        Text(channel.now?.title ?? channel.group).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                        if guide, let next = channel.next {
                            Text("Next \(next.startsAt.formatted(date: .omitted, time: .shortened)) · \(next.title)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        if let now = channel.now {
                            ProgressView(value: min(1, max(0, (Date().timeIntervalSince1970 - Double(now.start)) / Double(max(1, now.end - now.start)))))
                                .tint(Theme.accent).frame(maxWidth: 260)
                        }
                    }
                    Spacer(minLength: 8)
                    Image(systemName: guide ? "calendar" : selected ? "speaker.wave.2.fill" : "play.fill").foregroundStyle(Theme.accent)
                }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
            }
            #if os(tvOS)
            .buttonStyle(ChannelRowButtonStyle())
            #else
            .buttonStyle(.borderless)
            #endif
            .layoutPriority(1)
            .accessibilityLabel("\(guide ? "Programme guide for" : "Watch") \(channel.name)")
            Button(action: favorite) { Image(systemName: channel.favorite ? "star.fill" : "star").foregroundStyle(channel.favorite ? Theme.accent : .secondary).padding(8) }
                .buttonStyle(.borderless).accessibilityLabel("\(channel.favorite ? "Remove" : "Add") \(channel.name) \(channel.favorite ? "from" : "to") favorites")
            if !guide {
                Button(action: schedule) { Image(systemName: "info.circle").padding(8) }
                    .buttonStyle(.borderless).accessibilityLabel("Programme guide for \(channel.name)")
            }
        }
        .padding(.trailing, 6)
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).stroke(selected ? Theme.accent.opacity(0.6) : Color.white.opacity(0.05), lineWidth: 1) }
        #if os(tvOS)
        .overlay {
            if isFocused {
                RoundedRectangle(cornerRadius: 14).stroke(Theme.accent, lineWidth: 2)
                    .allowsHitTesting(false)
            }
        }
        // Track the whole row so play, favorite and guide focus all stay visible.
        .focused($isFocused)
        .onChange(of: isFocused) { _, focused in
            if focused { onFocus() }
        }
        #endif
    }
}

#if os(tvOS)
private struct ChannelRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        // The row supplies its own focus highlight without scaling into adjacent actions.
        configuration.label.opacity(configuration.isPressed ? 0.8 : 1)
    }
}
#endif

struct ChannelLogo: View {
    let channel: Channel
    var body: some View {
        AsyncImage(url: channel.logo.flatMap(URL.init(string:))) { image in
            image.resizable().scaledToFit()
        } placeholder: {
            Image(systemName: "tv").resizable().scaledToFit().foregroundStyle(Theme.accent.opacity(0.8))
        }.frame(width: 36, height: 36).padding(6).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
            .accessibilityHidden(true)
    }
}

struct GroupChooser: View {
    @Bindable var library: LibraryStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        List {
            Button { library.group = nil; dismiss() } label: { Label("All groups", systemImage: library.group == nil ? "checkmark.circle.fill" : "circle") }
            ForEach(library.groups) { group in
                Button { library.group = group.name; dismiss() } label: {
                    HStack {
                        Text(group.name)
                        Spacer()
                        Text(group.count.formatted()).foregroundStyle(.secondary)
                        if library.group == group.name { Image(systemName: "checkmark").foregroundStyle(Theme.accent) }
                    }
                }
            }
        }.navigationTitle("Channel groups")
    }
}

struct StatusBanner: View {
    let message: String
    let dismiss: () -> Void
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.circle").foregroundStyle(.orange)
            Text(message).font(.callout)
            Spacer()
            Button(action: dismiss) { Image(systemName: "xmark") }.accessibilityLabel("Dismiss message")
        }.padding().background(Color.orange.opacity(0.1))
    }
}

#if os(iOS)
struct MiniPlayer: View {
    @Bindable var playback: PlaybackStore
    let library: LibraryStore
    var body: some View {
        VStack(spacing: 0) {
            NativePlayer(player: playback.player).frame(height: 205)
                .overlay { if playback.isLoading { ProgressView("Connecting…") } }
            if let error = playback.error {
                Text(error).font(.caption).foregroundStyle(.orange).padding(8)
                Button("Retry channel") { if let channel = playback.channel { Task { await playback.play(channel, library: library) } } }
            }
            HStack {
                Text(playback.channel?.name ?? "Live TV").font(.subheadline.weight(.semibold)).lineLimit(1)
                Spacer()
                Button { playback.isPresented = true } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }.accessibilityLabel("Full screen")
                Button { playback.stop() } label: { Image(systemName: "stop.fill") }.accessibilityLabel("Stop playback")
            }.padding(12)
        }.background(Theme.surface)
    }
}
#endif
