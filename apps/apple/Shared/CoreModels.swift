import Foundation

struct ProviderConnection: Codable, Equatable, Sendable {
    var kind = "xtream"
    var baseUrl = "http://ourxtream.com"
    var username = ""
    var password = ""
    var playlistUrl = ""
    var epgUrl = ""
}

struct Programme: Decodable, Identifiable, Equatable, Sendable {
    let channelId: String
    let title: String
    let description: String
    let start: Int64
    let end: Int64
    let category: String
    var id: String { "\(channelId)|\(start)|\(end)|\(title)" }
    var startsAt: Date { Date(timeIntervalSince1970: Double(start)) }
    var endsAt: Date { Date(timeIntervalSince1970: Double(end)) }
}

struct Channel: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let group: String
    let logo: String?
    let epgId: String
    let streamId: Int64?
    var favorite: Bool
    let lastWatched: Int64?
    let now: Programme?
    let next: Programme?
}

struct ChannelPage: Decodable, Sendable {
    let channels: [Channel]
    let total: Int
    let offset: Int
}
struct ChannelGroup: Decodable, Identifiable, Equatable, Sendable {
    let name: String
    let count: Int
    var id: String { name }
}
struct Country: Decodable, Identifiable, Equatable, Sendable {
    let code: String
    let name: String
    let count: Int
    let groups: [ChannelGroup]
    let favorite: Bool
    var id: String { code }
}
struct LibraryStatus: Decodable, Sendable {
    let channels: Int
    let updated: String?
    let guideUpdated: String?
    let guideNeedsRefresh: Bool
}
struct ChannelQuery: Encodable, Sendable {
    var search = ""
    var group: String?
    var country: String?
    var alphabetical = false
    var favoritesOnly = false
    var historyOnly = false
    var offset = 0
    var limit = 80
}
struct CoreRequest: Encodable, Sendable {
    let command: String
    var connection: ProviderConnection?
    var query: ChannelQuery?
    var programmeQuery: ProgrammeQuery?
    var id: String?
    var favorite: Bool?
}
struct AppFailure: LocalizedError, Sendable {
    let message: String
    var errorDescription: String? { message }
}

enum LibrarySection: String, CaseIterable, Identifiable {
    case live = "Live TV", favorites = "Favorites", history = "Recently watched"
    var id: String { rawValue }
    var symbol: String {
        switch self { case .live: "tv"; case .favorites: "star"; case .history: "clock" }
    }
}

extension Programme {
    func contains(_ date: Date) -> Bool { startsAt <= date && endsAt > date }
    func progress(at date: Date) -> Double {
        min(1, max(0, (date.timeIntervalSince1970 - Double(start)) / Double(max(1, end - start))))
    }
    func remainingMinutes(at date: Date) -> Int {
        max(0, Int(ceil(endsAt.timeIntervalSince(date) / 60)))
    }
}

struct ProgrammeQuery: Encodable, Sendable {
    var search = ""
    var country: String?
    var group: String?
    var favoritesOnly = false
    var from: Int64?
    var until: Int64?
    var offset = 0
    var limit = 100
}
struct ProgrammeMatch: Decodable, Identifiable, Sendable {
    let channel: Channel
    let programme: Programme
    var id: String { "\(channel.id)|\(programme.id)" }
}
struct ProgrammePage: Decodable, Sendable {
    let results: [ProgrammeMatch]
    let total: Int
    let offset: Int
}
