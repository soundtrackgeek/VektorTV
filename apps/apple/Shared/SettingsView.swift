import SwiftUI

struct SettingsView: View {
    let library: LibraryStore
    let playback: PlaybackStore
    // A one-time draft isolates editing from the currently connected account.
    @State private var draft: ProviderConnection
    @State private var confirmingForget = false
    init(library: LibraryStore, playback: PlaybackStore) {
        self.library = library
        self.playback = playback
        self.draft = library.connection
    }
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: "play.tv.fill").font(.largeTitle).foregroundStyle(Theme.accent)
                    Text("Your television.\nYour viewing room.").font(.largeTitle.weight(.bold)).fixedSize(horizontal: false, vertical: true)
                    Text("Connect your IPTV subscription to watch live channels and browse the programme guide.").foregroundStyle(.secondary)
                }.padding(.vertical)
            }
            Section("Connection") {
                Picker("Provider type", selection: $draft.kind) {
                    Text("Xtream account").tag("xtream")
                    Text("M3U playlist").tag("m3u")
                }
                if draft.kind == "xtream" {
                    TextField("Server address", text: $draft.baseUrl).autocorrectionDisabled()
                    TextField("Username", text: $draft.username).autocorrectionDisabled()
                    SecureField("Password", text: $draft.password)
                } else {
                    TextField("Playlist URL", text: $draft.playlistUrl).autocorrectionDisabled()
                }
                TextField("XMLTV URL (optional)", text: $draft.epgUrl).autocorrectionDisabled()
                #if os(iOS)
                Text("Use the server address, such as http://ourxtream.com. Xtream guide addresses are inferred automatically.").font(.caption).foregroundStyle(.secondary)
                #endif
                Button {
                    playback.stop()
                    Task { await library.connect(draft) }
                } label: {
                    HStack {
                        Text(library.isRefreshing ? "Loading your channels…" : "Connect & load channels")
                        if library.isRefreshing { Spacer(); ProgressView() }
                    }
                }.disabled(library.isRefreshing)
            }
            if let message = library.message { Section { Text(message).foregroundStyle(.orange) } }
            if library.hasAccount {
                Section("Library") {
                    LabeledContent("Cached channels", value: library.catalogCount.formatted())
                    Button(library.isLoadingGuide ? "Guide updating…" : "Refresh programme guide") { Task { await library.refreshGuide() } }
                        .disabled(library.isLoadingGuide)
                    if let guideMessage = library.guideMessage { Text(guideMessage).foregroundStyle(.orange) }
                    Button("Forget saved account", role: .destructive) { confirmingForget = true }.disabled(library.isRefreshing)
                }
            }
            Section("About VektorTV") {
                Text("VektorTV 0.2.1 · Native Apple beta")
                Text("VektorTV supplies no channels. Use your own authorized IPTV subscription. Live playback uses HLS; availability and codecs depend on your provider.").font(.footnote).foregroundStyle(.secondary)
            }
        }
        #if os(iOS)
        .textInputAutocapitalization(.never)
        #endif
        .navigationTitle(library.hasAccount ? "Settings" : "Welcome to VektorTV")
        .confirmationDialog("Forget the account on this device?", isPresented: $confirmingForget, titleVisibility: .visible) {
            Button("Forget account", role: .destructive) {
                playback.stop()
                Task {
                    do { try await library.forget(); draft = ProviderConnection() }
                    catch { library.message = error.localizedDescription }
                }
            }
        } message: { Text("Your saved credentials will be removed. Cached favorites and viewing history are kept for reconnecting to this account.") }
    }
}
