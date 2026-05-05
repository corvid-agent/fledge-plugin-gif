import Foundation

public struct GifResult: Codable, Equatable {
    public let id: String
    public let title: String
    public let url: String
    public let previewUrl: String
    public let width: Int
    public let height: Int

    public init(id: String, title: String, url: String, previewUrl: String, width: Int, height: Int) {
        self.id = id
        self.title = title
        self.url = url
        self.previewUrl = previewUrl
        self.width = width
        self.height = height
    }
}

public struct SavedGif: Codable {
    public let name: String
    public let url: String
    public let savedAt: String

    public init(name: String, url: String, savedAt: String) {
        self.name = name
        self.url = url
        self.savedAt = savedAt
    }
}

public enum GifError: Error, CustomStringConvertible {
    case networkError(String)
    case parseError(String)
    case saveError(String)
    case notFound(String)

    public var description: String {
        switch self {
        case .networkError(let msg): return "Network error: \(msg)"
        case .parseError(let msg): return "Parse error: \(msg)"
        case .saveError(let msg): return "Save error: \(msg)"
        case .notFound(let msg): return "Not found: \(msg)"
        }
    }
}

public func savedGifsPath() -> URL {
    let home = FileManager.default.homeDirectoryForCurrentUser
    let dir = home.appendingPathComponent(".config/fledge/gif")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.appendingPathComponent("saved.json")
}

public func loadSavedGifs() -> [SavedGif] {
    let path = savedGifsPath()
    guard let data = try? Data(contentsOf: path),
          let gifs = try? JSONDecoder().decode([SavedGif].self, from: data) else {
        return []
    }
    return gifs
}

public func writeSavedGifs(_ gifs: [SavedGif]) throws {
    let path = savedGifsPath()
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    let data = try encoder.encode(gifs)
    try data.write(to: path)
}

public func saveGif(name: String, url: String) throws {
    var gifs = loadSavedGifs()
    gifs.removeAll { $0.name == name }
    let formatter = ISO8601DateFormatter()
    let gif = SavedGif(name: name, url: url, savedAt: formatter.string(from: Date()))
    gifs.append(gif)
    try writeSavedGifs(gifs)
}

public func removeSavedGif(name: String) throws -> Bool {
    var gifs = loadSavedGifs()
    let before = gifs.count
    gifs.removeAll { $0.name == name }
    if gifs.count == before { return false }
    try writeSavedGifs(gifs)
    return true
}

public func searchTenor(query: String, limit: Int = 8, apiKey: String = "AIzaSyAyimkuYQYF_FXVALexPuGQctUWRURdCYQ") throws -> [GifResult] {
    let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
    let urlString = "https://tenor.googleapis.com/v2/search?q=\(encoded)&key=\(apiKey)&limit=\(limit)&media_filter=gif,tinygif"

    guard let url = URL(string: urlString) else {
        throw GifError.networkError("Invalid URL")
    }

    let sem = DispatchSemaphore(value: 0)
    var result: Result<[GifResult], GifError> = .failure(.networkError("Timeout"))

    let task = URLSession.shared.dataTask(with: url) { data, response, error in
        defer { sem.signal() }

        if let error = error {
            result = .failure(.networkError(error.localizedDescription))
            return
        }

        guard let data = data else {
            result = .failure(.networkError("No data received"))
            return
        }

        result = parseTenorResponse(data)
    }
    task.resume()
    sem.wait()

    switch result {
    case .success(let gifs): return gifs
    case .failure(let error): throw error
    }
}

public func trendingTenor(limit: Int = 8, apiKey: String = "AIzaSyAyimkuYQYF_FXVALexPuGQctUWRURdCYQ") throws -> [GifResult] {
    let urlString = "https://tenor.googleapis.com/v2/featured?key=\(apiKey)&limit=\(limit)&media_filter=gif,tinygif"

    guard let url = URL(string: urlString) else {
        throw GifError.networkError("Invalid URL")
    }

    let sem = DispatchSemaphore(value: 0)
    var result: Result<[GifResult], GifError> = .failure(.networkError("Timeout"))

    let task = URLSession.shared.dataTask(with: url) { data, response, error in
        defer { sem.signal() }

        if let error = error {
            result = .failure(.networkError(error.localizedDescription))
            return
        }

        guard let data = data else {
            result = .failure(.networkError("No data received"))
            return
        }

        result = parseTenorResponse(data)
    }
    task.resume()
    sem.wait()

    switch result {
    case .success(let gifs): return gifs
    case .failure(let error): throw error
    }
}

public func parseTenorResponse(_ data: Data) -> Result<[GifResult], GifError> {
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let results = json["results"] as? [[String: Any]] else {
        return .failure(.parseError("Could not parse Tenor response"))
    }

    var gifs: [GifResult] = []
    for item in results {
        let id = item["id"] as? String ?? ""
        let title = (item["content_description"] as? String ?? item["title"] as? String) ?? "Untitled"
        let mediaFormats = item["media_formats"] as? [String: Any] ?? [:]

        let gifMedia = mediaFormats["gif"] as? [String: Any] ?? [:]
        let tinyMedia = mediaFormats["tinygif"] as? [String: Any] ?? [:]

        let gifUrl = gifMedia["url"] as? String ?? ""
        let previewUrl = tinyMedia["url"] as? String ?? gifUrl

        let dims = gifMedia["dims"] as? [Int] ?? [0, 0]
        let width = dims.count > 0 ? dims[0] : 0
        let height = dims.count > 1 ? dims[1] : 0

        if !gifUrl.isEmpty {
            gifs.append(GifResult(
                id: id, title: title, url: gifUrl,
                previewUrl: previewUrl, width: width, height: height
            ))
        }
    }

    return .success(gifs)
}

public func downloadGif(url: String, to path: URL) throws {
    guard let gifUrl = URL(string: url) else {
        throw GifError.networkError("Invalid URL: \(url)")
    }

    let sem = DispatchSemaphore(value: 0)
    var downloadError: GifError?

    let task = URLSession.shared.dataTask(with: gifUrl) { data, response, error in
        defer { sem.signal() }

        if let error = error {
            downloadError = .networkError(error.localizedDescription)
            return
        }

        guard let data = data else {
            downloadError = .networkError("No data received")
            return
        }

        do {
            try data.write(to: path)
        } catch {
            downloadError = .saveError("Failed to write file: \(error.localizedDescription)")
        }
    }
    task.resume()
    sem.wait()

    if let error = downloadError { throw error }
}

public func formatResults(_ gifs: [GifResult], numbered: Bool = true) -> String {
    if gifs.isEmpty { return "  No GIFs found." }

    var output = ""
    for (i, gif) in gifs.enumerated() {
        let prefix = numbered ? "  \(i + 1). " : "  "
        let title = gif.title.isEmpty ? "Untitled" : gif.title
        let dims = gif.width > 0 ? " (\(gif.width)x\(gif.height))" : ""
        output += "\(prefix)\(title)\(dims)\n"
        output += "     \(gif.url)\n"
        if i < gifs.count - 1 { output += "\n" }
    }
    return output
}

public func formatSavedGifs(_ gifs: [SavedGif]) -> String {
    if gifs.isEmpty { return "  No saved GIFs. Use 'gif save <name> <url>' to save one." }

    var output = ""
    for (i, gif) in gifs.enumerated() {
        output += "  \(i + 1). \(gif.name)\n"
        output += "     \(gif.url)\n"
        output += "     saved: \(gif.savedAt)\n"
        if i < gifs.count - 1 { output += "\n" }
    }
    return output
}

public func formatJSON(_ gifs: [GifResult]) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    guard let data = try? encoder.encode(gifs),
          let str = String(data: data, encoding: .utf8) else {
        return "[]"
    }
    return str
}
