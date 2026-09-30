import SwiftUI

struct ScheduleView: View {
    let channel: Channel
    let library: LibraryStore
    let playback: PlaybackStore
    @Environment(\.dismiss) private var dismiss
    @State private var programmes: [Programme] = []
    @State private var loading = true
    @State private var message: String?
    var body: some View {
        List {
            Section {
                HStack { ChannelLogo(channel: channel); Text(channel.name).font(.title2.weight(.bold)) }
                Button { dismiss(); Task { await playback.play(channel, library: library) } } label: { Label("Watch live", systemImage: "play.fill") }
            }
            if loading { ProgressView("Loading schedule…") }
            if let message { Text(message).foregroundStyle(.orange) }
            if !loading && programmes.isEmpty {
                Text("No programme information is available for this channel.").foregroundStyle(.secondary)
            }
            ForEach(programmes) { programme in
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(programme.startsAt.formatted(date: .abbreviated, time: .shortened)) – \(programme.endsAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption).foregroundStyle(Theme.accent)
                    Text(programme.title).font(.headline)
                    if !programme.description.isEmpty { Text(programme.description).font(.subheadline).foregroundStyle(.secondary) }
                }.padding(.vertical, 6)
            }
        }
        .navigationTitle("Programme guide")
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        .task {
            do {
                programmes = try await library.call(CoreRequest(command: "schedule", id: channel.id))
                if programmes.isEmpty {
                    let _: Int = try await library.call(CoreRequest(command: "shortGuide", id: channel.id))
                    programmes = try await library.call(CoreRequest(command: "schedule", id: channel.id))
                }
            } catch { message = error.localizedDescription }
            loading = false
        }
    }
}
