import SwiftUI

struct ChannelBrowser: View {
    @Bindable var library: LibraryStore
    let playback: PlaybackStore
    let guide: Bool
    let wide: Bool
    let queryKey: String
    let showCountries: () -> Void
    let selectedGuideID: String?
    let schedule: (Channel) -> Void
    @FocusState private var searchFocused: Bool
    @FocusState private var channelFocus: String?
    @State private var movingID: String?
    @State private var draftOrder: [String] = []
    @State private var savingOrder = false

    private var visibleChannels: [Channel] {
        guard movingID != nil else { return library.channels }
        let byID = Dictionary(uniqueKeysWithValues: library.channels.map { ($0.id, $0) })
        let ordered = Set(draftOrder)
        return draftOrder.compactMap { byID[$0] } + library.channels.filter { !ordered.contains($0.id) }
    }
    private func pickUp(_ channel: Channel) {
        guard !library.isLoading, !savingOrder else { return }
        searchFocused = false
        draftOrder = library.channels.map(\.id)
        movingID = channel.id
        channelFocus = channel.id
    }
    private func move(to targetID: String) {
        guard let movingID, !savingOrder else { return }
        var ids = visibleChannels.map(\.id)
        guard let source = ids.firstIndex(of: movingID), let target = ids.firstIndex(of: targetID) else { return }
        ids.remove(at: source)
        ids.insert(movingID, at: target)
        draftOrder = ids
    }
    private func step(_ direction: Int) {
        let ids = visibleChannels.map(\.id)
        guard let movingID, let index = ids.firstIndex(of: movingID), ids.indices.contains(index + direction) else { return }
        move(to: ids[index + direction])
    }
    private func cancelMove() { movingID = nil; draftOrder = [] }
    private func drop() {
        guard let movingID, !savingOrder else { return }
        let ids = visibleChannels.map(\.id)
        guard let index = ids.firstIndex(of: movingID), ids.count > 1 else { cancelMove(); return }
        let targetID = ids[index == 0 ? 1 : index - 1]
        savingOrder = true
        Task {
            if await library.moveFavorite(movingID, targetId: targetID, before: index == 0) { cancelMove() }
            savingOrder = false
        }
    }

    var body: some View {
        ScrollViewReader { scroll in
            VStack(alignment: .leading, spacing: 0) {
                if wide { browserControls }
                if wide && library.isLoading && library.channels.isEmpty {
                    ProgressView("Loading channels…").frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            if !wide && !guide && playback.channel != nil {
                                ViewingRoom(library: library, playback: playback, compact: true,
                                    availableHeight: nil, schedule: schedule)
                                    .id("player")
                            }
                            if !wide { browserControls.id("browser-controls") }
                            Color.clear.frame(height: 1).id("channels-start")
                            if library.isLoading && library.channels.isEmpty {
                                ProgressView("Loading channels…").padding()
                            } else if library.channels.isEmpty {
                                ContentUnavailableView("No channels here", systemImage: library.section.symbol,
                                    description: Text(library.section == .favorites ? "Save a channel with its star or channel menu." : "Try another search or channel group."))
                            }
                            ForEach(visibleChannels) { channel in
                                ChannelRow(channel: channel,
                                    selected: guide ? selectedGuideID == channel.id : playback.channel?.id == channel.id,
                                    guide: guide,
                                    moving: movingID == channel.id,
                                    arranging: movingID != nil,
                                    select: {
                                        if movingID != nil {
                                            #if os(iOS)
                                            move(to: channel.id)
                                            #endif
                                            drop()
                                        }
                                        else if guide { schedule(channel) }
                                        else {
                                            searchFocused = false
                                            Task { await playback.play(channel, library: library) }
                                        }
                                    },
                                    favorite: {
                                        Task {
                                            if await library.toggleFavorite(channel), playback.channel?.id == channel.id {
                                                playback.channel?.favorite = !channel.favorite
                                            }
                                        }
                                    },
                                    schedule: { schedule(channel) },
                                    arrange: library.section == .favorites && movingID == nil ? { pickUp(channel) } : nil,
                                    focus: $channelFocus,
                                    onFocus: {
                                        #if os(tvOS)
                                        if let movingID, channel.id != movingID {
                                            move(to: channel.id)
                                            Task { @MainActor in
                                                await Task.yield()
                                                channelFocus = movingID
                                            }
                                        }
                                        #endif
                                        scroll.scrollTo(movingID ?? channel.id, anchor: .center)
                                    })
                                    .disabled(savingOrder)
                            }
                            if library.channels.count < library.total {
                                Button { Task { await library.reload(more: true) } } label: {
                                    if library.isLoading { ProgressView() }
                                    else { Text("Load more · \(library.channels.count.formatted()) of \(library.total.formatted())") }
                                }
                                .buttonStyle(CinemaButtonStyle()).font(Theme.detailFont)
                                .disabled(library.isLoading).padding(.vertical, 16)
                                .task(id: library.channels.count) {
                                    if guide && !library.isLoading { await library.reload(more: true) }
                                }
                            }
                        }
                        .padding(.horizontal, Theme.contentInset)
                        .padding(.vertical, 8)
                        #if os(tvOS)
                        .focusSection()
                        #endif
                    }
                    .onChange(of: queryKey) { _, _ in
                        cancelMove()
                        scroll.scrollTo(wide ? "channels-start" : "browser-controls", anchor: .top)
                    }
                    .onChange(of: draftOrder) { _, _ in
                        if let movingID { withAnimation { scroll.scrollTo(movingID, anchor: .center) } }
                    }
                    .onChange(of: playback.channel?.id) { _, selected in
                        guard !wide, !guide, selected != nil else { return }
                        Task { @MainActor in
                            await Task.yield()
                            withAnimation { scroll.scrollTo("player", anchor: .top) }
                        }
                    }
                }
            }
        }
        .onDisappear { if !savingOrder { cancelMove() } }
        #if os(tvOS)
        .onExitCommand(perform: movingID == nil ? nil : { if !savingOrder { cancelMove() } })
        #endif
    }

    private var browserControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let country = library.country {
                HStack {
                    Button(action: showCountries) {
                        HStack(spacing: 8) { CountryFlag(code: country.code, width: 28); Text(country.name).lineLimit(1) }
                    }.buttonStyle(CinemaButtonStyle()).font(Theme.detailFont).accessibilityLabel("Back to countries")
                    Spacer()
                    Button { library.clearCountry() } label: { Image(systemName: "xmark") }
                        .buttonStyle(CinemaButtonStyle()).accessibilityLabel("Clear country filter")
                }
                Text(library.group == nil ? "All channels A–Z" : "Country channels").font(Theme.detailFont).foregroundStyle(Theme.muted)
            }
            HStack {
                Text("Your channels").font(Theme.sectionFont)
                Spacer()
                if library.isRefreshing { ProgressView() }
                else {
                    Button { Task { await library.connect(library.connection) } } label: {
                        Image(systemName: "arrow.clockwise").font(Theme.detailFont)
                    }.buttonStyle(CinemaButtonStyle()).accessibilityLabel("Refresh channels and guide")
                }
            }
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.muted)
                TextField("Find a channel", text: $library.search)
                    .focused($searchFocused)
                    .onSubmit { searchFocused = false }
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                    #endif
                    .font(Theme.detailFont).accessibilityLabel("Find a channel")
                if !library.search.isEmpty {
                    Button { library.search = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(CinemaButtonStyle()).accessibilityLabel("Clear channel search")
                }
            }
            #if os(iOS)
            .padding(12).background(Theme.surface, in: RoundedRectangle(cornerRadius: 10))
            #endif
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { sectionPicker; groupPicker }
                VStack(alignment: .leading, spacing: 8) { sectionPicker; groupPicker }
            }
            if library.section == .favorites {
                if let movingID, let channel = visibleChannels.first(where: { $0.id == movingID }) {
                    Text("Moving \(channel.name). Move up/down, then select to drop.")
                        .font(Theme.detailFont).foregroundStyle(Theme.accent)
                        .accessibilityIdentifier("favorite-arrangement-status")
                    HStack(spacing: 10) {
                        Button { step(-1) } label: { Image(systemName: "arrow.up") }
                            .accessibilityLabel("Move favorite up").disabled(visibleChannels.first?.id == movingID)
                        Button { step(1) } label: { Image(systemName: "arrow.down") }
                            .accessibilityLabel("Move favorite down").disabled(visibleChannels.last?.id == movingID)
                        Button(savingOrder ? "Saving…" : "Drop", action: drop)
                        Button("Cancel", action: cancelMove)
                    }.buttonStyle(CinemaButtonStyle()).font(Theme.detailFont).disabled(savingOrder)
                } else {
                    Text("Hold a channel to arrange Favorites, or use its move button.")
                        .font(Theme.detailFont).foregroundStyle(Theme.muted)
                }
            }
        }
        .padding(.horizontal, wide ? Theme.contentInset : 0)
        .padding(.top, Theme.contentInset)
        .padding(.bottom, 12)
    }

    private var sectionPicker: some View {
        Menu {
            Picker("Library", selection: $library.section) {
                ForEach(LibrarySection.allCases) { section in
                    Label(section.rawValue, systemImage: section.symbol).tag(section)
                }
            }
        } label: {
            Label(library.section == .live ? "All channels" : library.section.rawValue, systemImage: library.section.symbol)
                .font(Theme.detailFont).lineLimit(1)
        }.buttonStyle(CinemaButtonStyle()).accessibilityLabel("Library: \(library.section.rawValue)")
    }

    private var groupPicker: some View {
        NavigationLink {
            GroupChooser(library: library)
        } label: {
            Label(library.group ?? "All groups", systemImage: "line.3.horizontal.decrease")
                .font(Theme.detailFont).lineLimit(1)
        }.buttonStyle(CinemaButtonStyle()).accessibilityLabel("Channel group: \(library.group ?? "All groups")")
    }
}

private struct ChannelRow: View {
    let channel: Channel
    let selected: Bool
    let guide: Bool
    let moving: Bool
    let arranging: Bool
    let select: () -> Void
    let favorite: () -> Void
    let schedule: () -> Void
    let arrange: (() -> Void)?
    let focus: FocusState<String?>.Binding
    let onFocus: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            row
            if let arrange {
                Button(action: arrange) { Image(systemName: "line.3.horizontal").padding(8) }
                    .buttonStyle(CinemaButtonStyle()).accessibilityLabel("Arrange \(channel.name)")
                    .contextMenu {
                        Button("Remove from favorites", systemImage: "star.slash", action: favorite)
                        Button("Programme guide", systemImage: "calendar", action: schedule)
                    }
            }
        }
        .background(moving ? Theme.accent.opacity(0.15) : .clear)
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(moving ? Theme.accent : .clear, lineWidth: 2) }
    }

    private var row: some View {
        Button(action: select) {
            HStack(spacing: 14) {
                ChannelLogo(channel: channel)
                VStack(alignment: .leading, spacing: 7) {
                    Text(channel.name).font(Theme.channelFont).foregroundStyle(Theme.text).lineLimit(2)
                    Text(channel.now?.title ?? channel.group).font(Theme.detailFont)
                        .foregroundStyle(Theme.muted).lineLimit(1)
                }.frame(maxWidth: .infinity, alignment: .leading)
                if selected {
                    Image(systemName: guide ? "calendar" : "speaker.wave.2.fill").foregroundStyle(Theme.accent)
                        .font(Theme.detailFont)
                } else if channel.favorite {
                    Image(systemName: "star.fill").foregroundStyle(Theme.muted).font(.caption)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, Theme.rowInset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Theme.accent.opacity(0.10) : .clear)
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2).fill(selected ? Theme.accent : .clear).frame(width: 4)
                    .padding(.vertical, 10)
            }
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
            .contentShape(Rectangle())
        }
        .buttonStyle(ChannelRowStyle())
        .focused(focus, equals: channel.id)
        .onChange(of: focus.wrappedValue) { _, focused in if focused == channel.id { onFocus() } }
        .highPriorityGesture(arrange == nil ? nil : LongPressGesture(minimumDuration: 0.45).onEnded { _ in arrange?() })
        .contextMenu {
            if arrange == nil && !arranging {
            Button(channel.favorite ? "Remove from favorites" : "Add to favorites", systemImage: channel.favorite ? "star.slash" : "star", action: favorite)
            Button("Programme guide", systemImage: "calendar", action: schedule)
            }
        }
        .accessibilityLabel("\(arranging ? "Drop at" : guide ? "Programme guide for" : "Watch") \(channel.name)")
        .accessibilityValue(channel.now?.title ?? "Programme information unavailable")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityAction(named: channel.favorite ? "Remove from favorites" : "Add to favorites", favorite)
        .accessibilityAction(named: "Programme guide", schedule)
        .accessibilityAction(named: "Arrange favorite") { arrange?() }
    }
}

private struct ChannelRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        ChannelRowFocus(configuration: configuration)
    }
}
private struct ChannelRowFocus: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.isFocused) private var focused
    var body: some View {
        configuration.label
            .background(focused ? Color.white.opacity(0.06) : .clear)
            .overlay { RoundedRectangle(cornerRadius: 8).stroke(focused ? .white : .clear, lineWidth: 3) }
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct GroupChooser: View {
    @Bindable var library: LibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    private var groups: [ChannelGroup] {
        search.isEmpty ? library.availableGroups : library.availableGroups.filter { $0.name.localizedStandardContains(search) }
    }
    var body: some View {
        List {
            #if os(tvOS)
            TextField("Find a group", text: $search).autocorrectionDisabled()
            #endif
            Button { library.group = nil; dismiss() } label: {
                Label(library.countryCode == nil ? "All groups" : "All channels A–Z", systemImage: library.group == nil ? "checkmark.circle.fill" : "circle")
            }
            ForEach(groups) { group in
                Button { library.group = group.name; dismiss() } label: {
                    HStack {
                        Text(group.name)
                        Spacer()
                        Text(group.count.formatted()).foregroundStyle(.secondary)
                        if library.group == group.name { Image(systemName: "checkmark").foregroundStyle(Theme.accent) }
                    }
                }
            }
        }
        .navigationTitle("Channel groups")
        .toolbar(.visible, for: .navigationBar)
        #if os(iOS)
        .searchable(text: $search, prompt: "Find a group")
        #endif
    }
}
