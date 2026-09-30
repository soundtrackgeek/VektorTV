import Foundation
import Observation

@MainActor @Observable
final class LibraryStore {
    var connection = ProviderConnection()
    var hasAccount = false
    var channels: [Channel] = []
    var groups: [ChannelGroup] = []
    var total = 0
    var catalogCount = 0
    var search = ""
    var group: String?
    var section = LibrarySection.live
    var isLoading = false
    var isRefreshing = false
    var isLoadingGuide = false
    var message: String?
    var guideMessage: String?
    var startupComplete = false
    @ObservationIgnored private var core: CoreClient?
    @ObservationIgnored private var queryGeneration = 0
    @ObservationIgnored private var accountGeneration = 0

    func start() async {
        guard !startupComplete else { return }
        startupComplete = true
        do {
            core = try CoreClient()
            if let saved = try CredentialStore.load() {
                connection = saved
                let _: Bool = try await call(CoreRequest(command: "restore", connection: saved))
                hasAccount = true
                await reload()
                await updateStatus()
                if catalogCount == 0 { await connect(saved) }
            }
            #if DEBUG
            if !hasAccount && ProcessInfo.processInfo.arguments.contains("--use-development-account") {
                let env = ProcessInfo.processInfo.environment
                if let user = env["IPTV_USERNAME"], let password = env["IPTV_PASSWORD"] {
                    var development = ProviderConnection()
                    development.baseUrl = env["IPTV_URL"] ?? "http://ourxtream.com"
                    development.username = user
                    development.password = password
                    await connect(development)
                }
            }
            #endif
        } catch { message = error.localizedDescription }
    }

    func call<T: Decodable & Sendable>(_ request: CoreRequest, as type: T.Type = T.self) async throws -> T {
        guard let core else { throw AppFailure(message: "The local library is unavailable. Restart VektorTV.") }
        return try await core.call(request, as: type)
    }
    func connect(_ candidate: ProviderConnection) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        message = nil
        defer { isRefreshing = false }
        do {
            let count: Int = try await call(CoreRequest(command: "refresh", connection: candidate))
            // Playback stops in Settings before replacing an account.
            connection = candidate
            hasAccount = true
            accountGeneration += 1
            catalogCount = count
            group = nil
            try CredentialStore.save(candidate)
            await reload()
            Task { await self.refreshGuide() }
        } catch {
            message = error.localizedDescription
            // A successful import remains usable even if saving Keychain failed.
            await reload()
        }
    }
    func refreshGuide() async {
        guard hasAccount, !isLoadingGuide else { return }
        isLoadingGuide = true
        let account = accountGeneration
        guideMessage = nil
        defer { isLoadingGuide = false }
        do {
            let _: Int = try await call(CoreRequest(command: "guide"))
            if account == accountGeneration && hasAccount { await reload() }
        } catch { if account == accountGeneration && hasAccount { guideMessage = error.localizedDescription } }
    }
    func reload(more: Bool = false) async {
        queryGeneration += 1
        let generation = queryGeneration
        let account = accountGeneration
        isLoading = true
        defer { if generation == queryGeneration { isLoading = false } }
        do {
            let query = ChannelQuery(search: search, group: group, favoritesOnly: section == .favorites, historyOnly: section == .history, offset: more ? channels.count : 0)
            let page: ChannelPage = try await call(CoreRequest(command: "list", query: query))
            let fetchedGroups: [ChannelGroup] = try await call(CoreRequest(command: "groups"))
            guard generation == queryGeneration, account == accountGeneration, !Task.isCancelled else { return }
            if more {
                let loaded = Set(channels.map(\.id))
                channels += page.channels.filter { !loaded.contains($0.id) }
            } else { channels = page.channels }
            total = page.total
            groups = fetchedGroups
        } catch { if generation == queryGeneration { message = error.localizedDescription } }
    }
    func updateStatus() async {
        do { let status: LibraryStatus = try await call(CoreRequest(command: "status")); catalogCount = status.channels }
        catch { message = error.localizedDescription }
    }
    func toggleFavorite(_ channel: Channel) async {
        do {
            let _: Bool = try await call(CoreRequest(command: "favorite", id: channel.id, favorite: !channel.favorite))
            await reload()
        } catch { message = error.localizedDescription }
    }
    func forget() async throws {
        try CredentialStore.delete()
        let _: Bool = try await call(CoreRequest(command: "disconnect"))
        accountGeneration += 1
        queryGeneration += 1
        isLoading = false
        hasAccount = false
        connection = ProviderConnection()
        channels = []
        groups = []
        catalogCount = 0
        total = 0
        message = nil
        guideMessage = nil
    }
}
