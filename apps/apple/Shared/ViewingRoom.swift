import SwiftUI

struct ViewingRoom: View {
    let library: LibraryStore
    @Bindable var playback: PlaybackStore
    let compact: Bool
    let availableHeight: CGFloat?
    let schedule: (Channel) -> Void
    @State private var programmes: [Programme] = []
    @State private var favoriteBusy = false

    private var channel: Channel? {
        guard let playing = playback.channel else { return nil }
        return library.channels.first { $0.id == playing.id } ?? playing
    }
    private var programmeQuery: String { "\(channel?.id ?? "")|\(library.isLoadingGuide)" }
    private var contentWidth: CGFloat {
        #if os(tvOS)
        return max(500, ((availableHeight ?? 900) - 350) * 16 / 9)
        #else
        return .infinity
        #endif
    }

    var body: some View {
        Group {
            if compact { contents }
            else { ScrollView { contents } }
        }
        .task(id: programmeQuery) {
            programmes = []
            guard let channel else { return }
            do {
                var values: [Programme] = try await library.call(CoreRequest(command: "schedule", id: channel.id))
                if values.isEmpty {
                    let _: Int = try await library.call(CoreRequest(command: "shortGuide", id: channel.id))
                    values = try await library.call(CoreRequest(command: "schedule", id: channel.id))
                }
                guard !Task.isCancelled else { return }
                programmes = values
            } catch {
                // Guide failure must not interrupt playback. The full schedule exposes retry/error detail.
            }
        }
    }

    private var contents: some View {
        VStack(alignment: .leading, spacing: compact ? 14 : 20) {
            if compact && channel == nil {
                HStack(spacing: 12) {
                    Image(systemName: "play.tv").foregroundStyle(Theme.accent)
                    Text("Choose a channel and settle in.").foregroundStyle(Theme.muted)
                }.font(.subheadline).padding(.vertical, 12)
            } else {
                videoSurface
                if let channel {
                    TimelineView(.periodic(from: .now, by: 30)) { context in
                        programmeDetails(channel, at: context.date)
                    }
                } else {
                    Text("Your viewing room").font(Theme.programmeFont)
                    Text("Choose a channel to watch live. Your programme and what's on next will appear here.")
                        .font(Theme.bodyFont).foregroundStyle(Theme.muted)
                }
            }
        }
        .frame(maxWidth: contentWidth, alignment: .leading)
        .padding(compact ? 0 : Theme.contentInset)
        .padding(.bottom, compact ? 24 : 0)
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var videoSurface: some View {
        Rectangle().fill(.black)
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .overlay {
                if channel != nil && !playback.isPresented && playback.error == nil {
                    InlinePlayer(player: playback.player).allowsHitTesting(false).accessibilityHidden(true)
                }
                if playback.isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Connecting to live stream…").font(Theme.detailFont)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity).background(.black.opacity(0.65))
                } else if playback.error != nil {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.tv").font(.largeTitle)
                        Text("Playback unavailable").font(Theme.sectionFont)
                    }.foregroundStyle(Theme.muted)
                } else if channel == nil {
                    VStack(spacing: 20) {
                        Image(systemName: "play.tv").font(.system(size: compact ? 38 : 64, weight: .ultraLight))
                        Text("LIVE TELEVISION, YOUR WAY").font(Theme.detailFont).tracking(3)
                    }.foregroundStyle(Theme.muted)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func programmeDetails(_ channel: Channel, at date: Date) -> some View {
        let now = programmes.first { $0.contains(date) } ?? channel.now.flatMap { $0.contains(date) ? $0 : nil }
        let next = programmes.first { $0.startsAt > date } ?? channel.next.flatMap { $0.startsAt > date ? $0 : nil }
        return VStack(alignment: .leading, spacing: compact ? 10 : 14) {
            HStack(spacing: 10) {
                Text(channel.name).lineLimit(2)
                if playback.error == nil {
                    Text(playback.isLoading ? "CONNECTING" : "LIVE").foregroundStyle(Theme.accent)
                }
            }.font(Theme.detailFont.weight(.medium)).foregroundStyle(Theme.muted)
            Text(now?.title ?? (playback.error == nil ? "Live television" : "Let's try that again"))
                .font(Theme.programmeFont).foregroundStyle(Theme.text).lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            if let now {
                Text("\(now.startsAt.formatted(date: .omitted, time: .shortened))–\(now.endsAt.formatted(date: .omitted, time: .shortened)) · \(now.remainingMinutes(at: date)) min left")
                    .font(Theme.detailFont).foregroundStyle(Theme.muted)
                ProgressView(value: now.progress(at: date)).tint(Theme.accent)
                    .accessibilityLabel("Programme elapsed")
                #if os(iOS)
                if !compact && !now.description.isEmpty {
                    Text(now.description).font(Theme.detailFont).foregroundStyle(Theme.muted).lineLimit(2)
                }
                #endif
            } else if playback.error == nil {
                Text("Programme information unavailable").font(Theme.detailFont).foregroundStyle(Theme.muted)
            }
            if let error = playback.error {
                Text(error).font(Theme.detailFont).foregroundStyle(Theme.muted)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { actions(channel) }
                VStack(alignment: .leading, spacing: 12) { actions(channel) }
            }.padding(.vertical, 4)
            if let next {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("UP NEXT").font(Theme.detailFont.weight(.medium)).foregroundStyle(Theme.muted)
                    Text(next.startsAt, style: .time).foregroundStyle(Theme.muted)
                    Text(next.title).foregroundStyle(Theme.text).lineLimit(2)
                }.font(Theme.detailFont)
            }
        }
    }

    @ViewBuilder private func actions(_ channel: Channel) -> some View {
        if playback.error != nil {
            Button { Task { await playback.play(channel, library: library) } } label: {
                Label("Retry channel", systemImage: "arrow.clockwise")
            }.buttonStyle(CinemaButtonStyle(prominent: true))
        } else {
            Button { playback.isPresented = true } label: {
                Label("Full screen", systemImage: "arrow.up.left.and.arrow.down.right")
            }.buttonStyle(CinemaButtonStyle(prominent: true)).accessibilityLabel("Full screen")
        }
        Button {
            favoriteBusy = true
            Task {
                if await library.toggleFavorite(channel), playback.channel?.id == channel.id {
                    playback.channel?.favorite = !channel.favorite
                }
                favoriteBusy = false
            }
        } label: {
            Image(systemName: channel.favorite ? "star.fill" : "star")
                .foregroundStyle(channel.favorite ? Theme.accent : Theme.text)
        }
        .buttonStyle(CinemaButtonStyle()).disabled(favoriteBusy)
        .accessibilityLabel(channel.favorite ? "Remove from favorites" : "Add to favorites")
        Button { schedule(channel) } label: { Image(systemName: "calendar") }
            .buttonStyle(CinemaButtonStyle()).accessibilityLabel("Programme guide")
        Button { playback.stop() } label: { Image(systemName: "stop.fill") }
            .buttonStyle(CinemaButtonStyle()).accessibilityLabel("Stop playback")
    }
}
