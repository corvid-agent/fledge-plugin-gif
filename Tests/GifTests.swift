import XCTest
import Foundation
@testable import GifLib

final class ParseTenorTests: XCTestCase {
    func testParsesValidResponse() {
        let json = """
        {
            "results": [
                {
                    "id": "123",
                    "content_description": "thumbs up",
                    "media_formats": {
                        "gif": {"url": "https://example.com/test.gif", "dims": [480, 360]},
                        "tinygif": {"url": "https://example.com/tiny.gif", "dims": [220, 165]}
                    }
                }
            ]
        }
        """.data(using: .utf8)!

        let result = parseTenorResponse(json)
        switch result {
        case .success(let gifs):
            XCTAssertEqual(gifs.count, 1)
            XCTAssertEqual(gifs[0].id, "123")
            XCTAssertEqual(gifs[0].title, "thumbs up")
            XCTAssertEqual(gifs[0].url, "https://example.com/test.gif")
            XCTAssertEqual(gifs[0].previewUrl, "https://example.com/tiny.gif")
            XCTAssertEqual(gifs[0].width, 480)
            XCTAssertEqual(gifs[0].height, 360)
        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testParsesEmptyResults() {
        let json = """
        {"results": []}
        """.data(using: .utf8)!

        let result = parseTenorResponse(json)
        switch result {
        case .success(let gifs):
            XCTAssertEqual(gifs.count, 0)
        case .failure:
            XCTFail("Should succeed with empty results")
        }
    }

    func testFailsOnInvalidJSON() {
        let json = "not json".data(using: .utf8)!
        let result = parseTenorResponse(json)
        switch result {
        case .success:
            XCTFail("Should fail on invalid JSON")
        case .failure(let error):
            XCTAssertTrue(error.description.contains("parse"))
        }
    }

    func testSkipsEntriesWithNoURL() {
        let json = """
        {
            "results": [
                {
                    "id": "1",
                    "content_description": "has url",
                    "media_formats": {
                        "gif": {"url": "https://example.com/1.gif", "dims": [100, 100]},
                        "tinygif": {"url": "https://example.com/1t.gif"}
                    }
                },
                {
                    "id": "2",
                    "content_description": "no url",
                    "media_formats": {}
                }
            ]
        }
        """.data(using: .utf8)!

        let result = parseTenorResponse(json)
        switch result {
        case .success(let gifs):
            XCTAssertEqual(gifs.count, 1)
            XCTAssertEqual(gifs[0].id, "1")
        case .failure:
            XCTFail("Should succeed")
        }
    }
}

final class FormatTests: XCTestCase {
    func testFormatResultsEmpty() {
        XCTAssertEqual(formatResults([]), "  No GIFs found.")
    }

    func testFormatResultsNumbered() {
        let gifs = [
            GifResult(id: "1", title: "test gif", url: "https://example.com/1.gif",
                      previewUrl: "https://example.com/1t.gif", width: 480, height: 360)
        ]
        let output = formatResults(gifs)
        XCTAssertTrue(output.contains("1."))
        XCTAssertTrue(output.contains("test gif"))
        XCTAssertTrue(output.contains("480x360"))
        XCTAssertTrue(output.contains("https://example.com/1.gif"))
    }

    func testFormatSavedGifsEmpty() {
        let output = formatSavedGifs([])
        XCTAssertTrue(output.contains("No saved GIFs"))
    }

    func testGifResultCodable() {
        let gif = GifResult(id: "1", title: "test", url: "https://x.com/1.gif",
                            previewUrl: "https://x.com/1t.gif", width: 100, height: 80)
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try! encoder.encode(gif)
        let decoded = try! decoder.decode(GifResult.self, from: data)
        XCTAssertEqual(gif, decoded)
    }
}
