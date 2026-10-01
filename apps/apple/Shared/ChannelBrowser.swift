import SwiftUI

struct ChannelBrowser: View {
    @Bindable var library: LibraryStore
    let playback: PlaybackStore
    let guide: Bool
    let wide: Bool
    let queryKey: String
    let selectedGuideID: String?
    let schedule: (Channel) -> Void
    @FocusState private var searchFocused: Bool

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
                            ForEach(library.channels) { channel in
                                ChannelRow(channel: channel,
                                    selected: guide ? selectedGuideID == channel.id : playback.channel?.id == channel.id,
                                    guide: guide,
                                    select: {
                                        if guide { schedule(channel) }
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
                                    onFocus: { scroll.scrollTo(channel.id, anchor: .center) })
                            }
                            if library.channels.count < library.total {
                                Button { Task { await library.reload(more: true) } } label: {
                                    if library.isLoading { ProgressView() }
                                    else { Text("Load more · \(library.channels.count.formatted()) of \(library.total.formatted())") }
                                }
                                .buttonStyle(CinemaButtonStyle()).font(Theme.detailFont)
                                .disabled(library.isLoading).padding(.vertical, 16)
                            }
                        }
                        .padding(.horizontal, Theme.contentInset)
                        .padding(.vertical, 8)
                        #if os(tvOS)
                        .focusSection()
                        #endif
                    }
                    .onChange(of: queryKey) { _, _ in
                        scroll.scrollTo(wide ? "channels-start" : "browser-controls", anchor: .top)
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
    }

    private var browserControls: some View {
        VStack(alignment: .leading, spacing: 14) {
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
    let select: () -> Void
    let favorite: () -> Void
    let schedule: () -> Void
    let onFocus: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
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
        .focused($focused)
        .onChange(of: focused) { _, focused in if focused { onFocus() } }
        .contextMenu {
            Button(channel.favorite ? "Remove from favorites" : "Add to favorites", systemImage: channel.favorite ? "star.slash" : "star", action: favorite)
            Button("Programme guide", systemImage: "calendar", action: schedule)
        }
        .accessibilityLabel("\(guide ? "Programme guide for" : "Watch") \(channel.name)")
        .accessibilityValue(channel.now?.title ?? "Programme information unavailable")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityAction(named: channel.favorite ? "Remove from favorites" : "Add to favorites", favorite)
        .accessibilityAction(named: "Programme guide", schedule)
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
        search.isEmpty ? library.groups : library.groups.filter { $0.name.localizedStandardContains(search) }
    }
    var body: some View {
        List {
            #if os(tvOS)
            TextField("Find a group", text: $search).autocorrectionDisabled()
            #endif
            Button { library.group = nil; dismiss() } label: {
                Label("All groups", systemImage: library.group == nil ? "checkmark.circle.fill" : "circle")
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
