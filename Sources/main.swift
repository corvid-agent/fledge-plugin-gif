import Foundation
import GifLib

let args = Array(CommandLine.arguments.dropFirst())

func printUsage() {
    print("""
    fledge gif — search, explore, and save GIFs

    Usage:
      gif search <query>        Search for GIFs
      gif trending              Show trending GIFs
      gif save <name> <url>     Save a GIF to your collection
      gif list                  List saved GIFs
      gif get <name>            Get a saved GIF by name
      gif remove <name>         Remove a saved GIF
      gif download <url> [path] Download a GIF to disk
      gif random <query>        Get a random GIF for a query

    Options:
      --limit <n>               Number of results (default: 8)
      --json                    Output as JSON

    Examples:
      gif search "nice work"
      gif trending --limit 5
      gif save celebration https://media.tenor.com/...
      gif get celebration
      gif random "thumbs up"
    """)
}

if args.isEmpty {
    printUsage()
    exit(0)
}

let jsonMode = args.contains("--json")
var limit = 8
if let idx = args.firstIndex(of: "--limit"), idx + 1 < args.count, let n = Int(args[idx + 1]) {
    limit = min(max(n, 1), 50)
}

var skipIndices = Set<Int>()
if let idx = args.firstIndex(of: "--json") { skipIndices.insert(idx) }
if let idx = args.firstIndex(of: "--limit") { skipIndices.insert(idx); skipIndices.insert(idx + 1) }

let filteredArgs = args.enumerated()
    .filter { !skipIndices.contains($0.offset) }
    .map { $0.element }

let command = filteredArgs.first ?? ""
let rest = Array(filteredArgs.dropFirst())

switch command {
case "search", "s", "find":
    let query = rest.joined(separator: " ")
    if query.isEmpty {
        print("Usage: gif search <query>")
        exit(1)
    }
    do {
        let results = try searchTenor(query: query, limit: limit)
        if jsonMode {
            print(formatJSON(results))
        } else {
            print("  GIFs for \"\(query)\":\n")
            print(formatResults(results))
        }
    } catch {
        fputs("Error: \(error)\n", stderr)
        exit(1)
    }

case "trending", "t", "hot":
    do {
        let results = try trendingTenor(limit: limit)
        if jsonMode {
            print(formatJSON(results))
        } else {
            print("  Trending GIFs:\n")
            print(formatResults(results))
        }
    } catch {
        fputs("Error: \(error)\n", stderr)
        exit(1)
    }

case "random", "r", "lucky":
    let query = rest.joined(separator: " ")
    if query.isEmpty {
        print("Usage: gif random <query>")
        exit(1)
    }
    do {
        let results = try searchTenor(query: query, limit: 20)
        if results.isEmpty {
            print("  No GIFs found for \"\(query)\".")
            exit(0)
        }
        let pick = results[Int.random(in: 0..<results.count)]
        if jsonMode {
            print(formatJSON([pick]))
        } else {
            print("  Random GIF for \"\(query)\":\n")
            print("  \(pick.title)")
            print("  \(pick.url)")
        }
    } catch {
        fputs("Error: \(error)\n", stderr)
        exit(1)
    }

case "save":
    guard rest.count >= 2 else {
        print("Usage: gif save <name> <url>")
        exit(1)
    }
    let name = rest[0]
    let url = rest[1]
    do {
        try saveGif(name: name, url: url)
        print("  Saved \"\(name)\" -> \(url)")
    } catch {
        fputs("Error saving GIF: \(error)\n", stderr)
        exit(1)
    }

case "list", "ls", "saved":
    let gifs = loadSavedGifs()
    if jsonMode {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(gifs), let str = String(data: data, encoding: .utf8) {
            print(str)
        }
    } else {
        print("  Saved GIFs:\n")
        print(formatSavedGifs(gifs))
    }

case "get":
    guard let name = rest.first else {
        print("Usage: gif get <name>")
        exit(1)
    }
    let gifs = loadSavedGifs()
    if let gif = gifs.first(where: { $0.name == name }) {
        if jsonMode {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            if let data = try? encoder.encode(gif), let str = String(data: data, encoding: .utf8) {
                print(str)
            }
        } else {
            print("  \(gif.name): \(gif.url)")
        }
    } else {
        print("  No saved GIF named \"\(name)\".")
        let suggestions = gifs.filter { $0.name.localizedCaseInsensitiveContains(name) }
        if !suggestions.isEmpty {
            print("  Did you mean: \(suggestions.map { $0.name }.joined(separator: ", "))?")
        }
        exit(1)
    }

case "remove", "rm", "delete":
    guard let name = rest.first else {
        print("Usage: gif remove <name>")
        exit(1)
    }
    do {
        let removed = try removeSavedGif(name: name)
        if removed {
            print("  Removed \"\(name)\" from saved GIFs.")
        } else {
            print("  No saved GIF named \"\(name)\".")
            exit(1)
        }
    } catch {
        fputs("Error: \(error)\n", stderr)
        exit(1)
    }

case "download", "dl":
    guard let url = rest.first else {
        print("Usage: gif download <url> [path]")
        exit(1)
    }
    let filename: String
    if rest.count > 1 {
        filename = rest[1]
    } else {
        let urlParts = url.split(separator: "/")
        filename = String(urlParts.last ?? "download.gif")
    }
    let path = URL(fileURLWithPath: filename)
    do {
        try downloadGif(url: url, to: path)
        print("  Downloaded to \(path.path)")
    } catch {
        fputs("Error: \(error)\n", stderr)
        exit(1)
    }

case "help", "--help", "-h":
    printUsage()

default:
    let query = ([command] + rest).joined(separator: " ")
    do {
        let results = try searchTenor(query: query, limit: limit)
        if jsonMode {
            print(formatJSON(results))
        } else {
            print("  GIFs for \"\(query)\":\n")
            print(formatResults(results))
        }
    } catch {
        fputs("Error: \(error)\n", stderr)
        exit(1)
    }
}
