import SwiftUI

struct ScheduleView: View {
    let channel: Channel
    let library: LibraryStore
    let playback: PlaybackStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ScheduleContent(channel: channel, library: library, playback: playback, onWatch: { dismiss() })
            .navigationTitle("Programme guide")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
    }
}

struct ScheduleContent: View {
    let channel: Channel
    let library: LibraryStore
    let playback: PlaybackStore
    var onWatch: () -> Void = {}
    @State private var programmes: [Programme] = []
    @State private var loading = true
    @State private var message: String?
    @State private var attempt = 0
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 16) {
                    ChannelLogo(channel: channel)
                    Text(channel.name).font(Theme.sectionFont)
                }
                Button {
                    onWatch()
                    Task {
                        await playback.play(channel, library: library)
                        // The guide can remain behind the full-screen player.
                        if playback.channel?.id == channel.id { playback.isPresented = true }
                    }
                } label: { Label("Watch live", systemImage: "play.fill") }
                    .buttonStyle(CinemaButtonStyle(prominent: true))
                if loading { ProgressView("Loading schedule…") }
                if let message {
                    Text(message).foregroundStyle(.orange).font(Theme.detailFont)
                    Button("Retry programme guide") { attempt += 1 }.buttonStyle(CinemaButtonStyle())
                }
                if !loading && programmes.isEmpty && message == nil {
                    Text("No programme information is available for this channel.")
                        .font(Theme.bodyFont).foregroundStyle(Theme.muted)
                }
                ForEach(programmes) { programme in
                    VStack(alignment: .leading, spacing: 10) {
                        Text("\(programme.startsAt.formatted(date: .abbreviated, time: .shortened)) – \(programme.endsAt.formatted(date: .omitted, time: .shortened))")
                            .font(Theme.detailFont).foregroundStyle(Theme.accent)
                        Text(programme.title).font(Theme.channelFont)
                        if !programme.description.isEmpty {
                            Text(programme.description).font(Theme.detailFont).foregroundStyle(Theme.muted)
                        }
                        Rectangle().fill(Theme.line).frame(height: 1).padding(.top, 10)
                    }
                    #if os(tvOS)
                    .focusable()
                    #endif
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(Theme.pageInset)
        }
        .background(Theme.background)
        .task(id: "\(channel.id)|\(attempt)") {
            loading = true
            message = nil
            do {
                var values: [Programme] = try await library.call(CoreRequest(command: "schedule", id: channel.id))
                if values.isEmpty {
                    let _: Int = try await library.call(CoreRequest(command: "shortGuide", id: channel.id))
                    values = try await library.call(CoreRequest(command: "schedule", id: channel.id))
                }
                guard !Task.isCancelled else { return }
                programmes = values.filter { $0.endsAt > .now }
            } catch { if !Task.isCancelled { message = error.localizedDescription } }
            if !Task.isCancelled { loading = false }
        }
    }
}
