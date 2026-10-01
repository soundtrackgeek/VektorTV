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
struct LibraryStatus: Decodable, Sendable {
    let channels: Int
    let updated: String?
    let guideUpdated: String?
}
struct ChannelQuery: Encodable, Sendable {
    var search = ""
    var group: String?
    var favoritesOnly = false
    var historyOnly = false
    var offset = 0
    var limit = 80
}
struct CoreRequest: Encodable, Sendable {
    let command: String
    var connection: ProviderConnection?
    var query: ChannelQuery?
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
