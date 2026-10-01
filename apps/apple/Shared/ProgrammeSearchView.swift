import SwiftUI

struct ProgrammeSearchView: View {
    let library: LibraryStore
    let onWatch: (Channel) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var country = ""
    @State private var group = ""
    @State private var when = "all"
    @State private var favoritesOnly = false
    @State private var filtersPresented = false
    @State private var offset = 0
    @State private var page: ProgrammePage?
    @State private var loading = true
    @State private var message: String?
    @State private var attempt = 0
    @FocusState private var searchFocused: Bool
    private var filterKey: String { "\(search)|\(country)|\(group)|\(when)|\(favoritesOnly)|\(library.isLoadingGuide)" }
    private var availableGroups: [ChannelGroup] { country.isEmpty ? library.groups : library.countries.first { $0.code == country }?.groups ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                TextField("Search all programmes", text: $search)
                    .focused($searchFocused).onSubmit { searchFocused = false }
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never).submitLabel(.search)
                    .textFieldStyle(.roundedBorder)
                    #endif
                Button { filtersPresented = true } label: { Label("Filters", systemImage: "line.3.horizontal.decrease") }
                    .buttonStyle(CinemaButtonStyle())
            }.font(Theme.detailFont)
            Text("All imported guides · \(whenLabel)\(country.isEmpty ? "" : " · " + (library.countries.first { $0.code == country }?.name ?? country))\(group.isEmpty ? "" : " · " + group)\(favoritesOnly ? " · Favorite channels" : "")")
                .font(Theme.detailFont).foregroundStyle(Theme.muted)
            if library.isLoadingGuide {
                ProgressView("Loading the guide… Search results will update automatically.")
            }
            if let guideMessage = library.guideMessage {
                Text("Guide: \(guideMessage)").font(Theme.detailFont).foregroundStyle(.orange)
            }
            if loading { ProgressView("Searching programmes…") }
            if let message {
                Text(message).foregroundStyle(.orange)
                Button("Retry search") { attempt += 1 }.buttonStyle(CinemaButtonStyle())
            }
            if let page, !loading {
                Text("\(page.total.formatted()) programmes found").font(Theme.detailFont).foregroundStyle(Theme.accent)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        if page.results.isEmpty {
                            Text("Try a different search or filter, or refresh the guide in Settings.").font(Theme.bodyFont)
                        }
                        ForEach(page.results) { result in
                            Button { onWatch(result.channel) } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("\(result.channel.name) · \(result.programme.startsAt.formatted(date: .abbreviated, time: .shortened)) – \(result.programme.endsAt.formatted(date: .omitted, time: .shortened))")
                                        .font(Theme.detailFont).foregroundStyle(Theme.accent)
                                    Text(result.programme.title).font(Theme.channelFont)
                                    if !result.programme.category.isEmpty { Text(result.programme.category).font(Theme.detailFont) }
                                    if !result.programme.description.isEmpty { Text(result.programme.description).font(Theme.detailFont).foregroundStyle(Theme.muted).lineLimit(2) }
                                    Label("Watch channel live", systemImage: "play.fill").font(Theme.detailFont)
                                }.frame(maxWidth: .infinity, alignment: .leading).padding(12)
                            }.buttonStyle(CinemaButtonStyle())
                            .accessibilityIdentifier("programme-search-result")
                        }
                        if page.total > 100 {
                            HStack {
                                Button("Previous results") { offset = max(0, offset - 100) }.disabled(offset == 0)
                                Spacer()
                                Button("More results") { offset += 100 }.disabled(offset + page.results.count >= page.total)
                            }.buttonStyle(CinemaButtonStyle())
                        }
                    }.padding(8)
                }.id(offset)
            }
            if page == nil { Spacer() }
        }
        .padding(Theme.pageInset).background(Theme.background)
        .navigationTitle("Search programmes")
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        .onChange(of: filterKey) { _, _ in offset = 0 }
        .task(id: "\(filterKey)|\(offset)|\(attempt)") {
            loading = true; message = nil; page = nil
            do {
                try await Task.sleep(for: .milliseconds(300))
                let now = Int64(Date.now.timeIntervalSince1970)
                let query = ProgrammeQuery(search: search, country: country.isEmpty ? nil : country,
                    group: group.isEmpty ? nil : group, favoritesOnly: favoritesOnly,
                    from: when == "all" ? nil : now,
                    until: when == "live" ? now + 1 : when == "day" ? now + 86400 : nil, offset: offset)
                let result: ProgrammePage = try await library.call(CoreRequest(command: "searchProgrammes", programmeQuery: query))
                guard !Task.isCancelled else { return }
                page = result
            } catch { if !Task.isCancelled { message = error.localizedDescription } }
            if !Task.isCancelled { loading = false }
        }
        .sheet(isPresented: $filtersPresented) {
            NavigationStack {
                Form {
                    Picker("When", selection: $when) {
                        Text("All guide times").tag("all")
                        Text("On now").tag("live")
                        Text("Next 24 hours").tag("day")
                        Text("Now & upcoming").tag("upcoming")
                    }
                    Picker("Country", selection: $country) {
                        Text("All countries").tag("")
                        ForEach(library.countries) { country in Text(country.name).tag(country.code) }
                    }.onChange(of: country) { _, _ in group = "" }
                    Picker("Group", selection: $group) {
                        Text("All groups").tag("")
                        ForEach(availableGroups) { group in Text(group.name).tag(group.name) }
                    }
                    Toggle("Favorite channels", isOn: $favoritesOnly)
                    Button("Reset filters") { country = ""; group = ""; when = "all"; favoritesOnly = false }
                }.navigationTitle("Programme filters")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { filtersPresented = false } } }
            }
        }
    }
    private var whenLabel: String {
        switch when { case "live": "On now"; case "day": "Next 24 hours"; case "upcoming": "Now & upcoming"; default: "All guide times" }
    }
}
