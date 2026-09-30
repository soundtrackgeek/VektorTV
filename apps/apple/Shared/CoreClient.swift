import Foundation

/// Rust serializes SQLite access internally. Each asynchronous request retains
/// this owner until completion; closing cannot race an outstanding C call.
final class CoreClient: @unchecked Sendable {
    private let handle: OpaquePointer
    init() throws {
        #if os(tvOS)
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("VektorTV")
        #else
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("VektorTV")
        #endif
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var resourceDirectory = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try resourceDirectory.setResourceValues(values)
        guard let opened = directory.appendingPathComponent("library.sqlite3").path.withCString({ vektortv_core_open($0) }) else {
            throw AppFailure(message: "The local library could not be opened. Restart VektorTV.")
        }
        handle = opened
    }
    deinit { vektortv_core_close(handle) }

    func call<T: Decodable & Sendable>(_ request: CoreRequest, as type: T.Type = T.self) async throws -> T {
        let data = try JSONEncoder().encode(request)
        let input = String(decoding: data, as: UTF8.self)
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                do {
                    guard let output = input.withCString({ vektortv_core_request(handle, $0) }) else {
                        throw AppFailure(message: "The library did not respond. Restart VektorTV.")
                    }
                    defer { vektortv_string_free(output) }
                    let bytes = Data(String(cString: output).utf8)
                    let response = try JSONDecoder().decode(CoreResponse<T>.self, from: bytes)
                    if let error = response.error { throw AppFailure(message: error) }
                    guard let value = response.value else { throw AppFailure(message: "The library returned an incomplete response.") }
                    continuation.resume(returning: value)
                } catch {
                    // Decode errors can contain provider data; expose only our controlled errors.
                    continuation.resume(throwing: error as? AppFailure ?? AppFailure(message: "The library response could not be read."))
                }
            }
        }
    }
}
private struct CoreResponse<T: Decodable>: Decodable {
    let value: T?
    let error: String?
}
