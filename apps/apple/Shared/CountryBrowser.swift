import SwiftUI

struct CountryFlag: View {
    let code: String
    var width: CGFloat = 64
    var body: some View {
        Group {
            if code == "zz" {
                Image(systemName: "globe.europe.africa").resizable().scaledToFit()
                    .padding(7).foregroundStyle(Theme.muted)
            } else {
                Image("flag-\(code)").resizable().scaledToFit()
            }
        }
        .frame(width: width, height: width * 0.75)
        .clipShape(.rect(cornerRadius: 4))
        .accessibilityHidden(true)
    }
}

struct CountryBrowser: View {
    @Bindable var library: LibraryStore
    let open: (Country, String?) -> Void
    @State private var selectedCode: String?
    @State private var search = ""
    @State private var saving = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var selected: Country? { library.countries.first { $0.code == selectedCode } }
    private var filtered: [Country] {
        library.countries.filter { search.isEmpty || $0.name.localizedStandardContains(search) || $0.code.localizedStandardContains(search) }
    }
    private var columns: [GridItem] {
        #if os(tvOS)
        [GridItem(.adaptive(minimum: 300), spacing: 24)]
        #else
        [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 280 : 155), spacing: 16)]
        #endif
    }
    var body: some View {
        ScrollViewReader { scroll in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let country = selected {
                        countryDetail(country)
                    } else {
                        heading
                        if library.countries.isEmpty {
                            ContentUnavailableView("No countries yet", systemImage: "globe",
                                description: Text("Refresh your channel library to discover its countries."))
                        } else if filtered.isEmpty {
                            ContentUnavailableView.search(text: search)
                        } else {
                            countrySection("Favorite countries", countries: filtered.filter(\.favorite))
                            countrySection("All countries", countries: filtered.filter { !$0.favorite })
                            Text("Star countries to keep them at the top. Regional and unrecognized groups are under International & unassigned.")
                                .font(Theme.detailFont).foregroundStyle(Theme.muted)
                        }
                    }
                }
                .id("country-top")
                .padding(Theme.pageInset)
            }
            .onChange(of: selectedCode) { _, _ in scroll.scrollTo("country-top", anchor: .top) }
        }
        #if os(tvOS)
        .onExitCommand { if selectedCode != nil { selectedCode = nil } }
        #endif
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("YOUR WORLD OF TELEVISION").font(Theme.detailFont).foregroundStyle(Theme.muted)
            Text("Countries").font(.largeTitle.bold())
            Text("Choose a country. Find your channels.").font(Theme.detailFont).foregroundStyle(Theme.muted)
            TextField("Find a country", text: $search)
                .font(Theme.controlFont).autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .padding(14).background(Theme.surface, in: RoundedRectangle(cornerRadius: 10))
                #endif
                .accessibilityLabel("Find a country")
        }
    }
    @ViewBuilder private func countrySection(_ title: String, countries: [Country]) -> some View {
        if !countries.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                Text(title).font(Theme.sectionFont)
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(countries) { country in
                        VStack(alignment: .leading, spacing: 0) {
                            Button { selectedCode = country.code; search = "" } label: {
                                VStack(alignment: .leading, spacing: 12) {
                                    CountryFlag(code: country.code)
                                    Text(country.name).font(Theme.channelFont).foregroundStyle(Theme.text)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text("\(country.groups.count) groups · \(country.count.formatted()) channels")
                                        .font(Theme.detailFont).foregroundStyle(Theme.muted)
                                }.frame(maxWidth: .infinity, alignment: .leading).padding(18)
                            }
                            .buttonStyle(CinemaButtonStyle())
                            .accessibilityLabel("Explore \(country.name)")
                            HStack {
                                Spacer()
                                favoriteButton(country)
                            }.padding(.horizontal, 12).padding(.bottom, 8)
                        }
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
                        .overlay { RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1).allowsHitTesting(false) }
                    }
                }
            }
        }
    }
    private func favoriteButton(_ country: Country) -> some View {
        Button {
            saving = true
            Task { await library.toggleCountryFavorite(country); saving = false }
        } label: {
            Image(systemName: country.favorite ? "star.fill" : "star")
                .font(Theme.controlFont).foregroundStyle(country.favorite ? Theme.accent : Theme.muted)
                .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(CinemaButtonStyle()).disabled(saving)
        .accessibilityLabel("\(country.favorite ? "Unfavorite" : "Favorite") country \(country.name)")
        .accessibilityValue(country.favorite ? "Favorite" : "Not favorite")
    }
    private func countryDetail(_ country: Country) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            Button { selectedCode = nil } label: { Label("All countries", systemImage: "arrow.left") }
                .buttonStyle(CinemaButtonStyle()).font(Theme.controlFont)
            HStack(spacing: 20) {
                CountryFlag(code: country.code, width: 80)
                VStack(alignment: .leading, spacing: 8) {
                    Text(country.name).font(Theme.sectionFont)
                    Text("\(country.groups.count) groups · \(country.count.formatted()) channels")
                        .font(Theme.detailFont).foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 0)
                favoriteButton(country)
            }
            Button { open(country, nil) } label: {
                HStack(spacing: 16) {
                    Image(systemName: "textformat.abc")
                    Text("All channels A–Z").font(Theme.controlFont)
                    Spacer()
                    Image(systemName: "chevron.right")
                }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            }.buttonStyle(CinemaButtonStyle(prominent: true))
            Text("Channel groups").font(Theme.sectionFont)
            LazyVStack(spacing: 12) {
                ForEach(country.groups) { group in
                    Button { open(country, group.name) } label: {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(group.name).font(Theme.channelFont).foregroundStyle(Theme.text)
                                Text("\(group.count.formatted()) channels").font(Theme.detailFont).foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                        }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10))
                    }.buttonStyle(CinemaButtonStyle()).accessibilityLabel("Open group \(group.name)")
                }
            }
        }
    }
}
