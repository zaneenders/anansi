import AsyncHTTPClient
import Configuration
import Foundation
import HTTPTypes
import NIOCore
import Testing

@testable import Anansi

@Suite(.serialized) struct BraveTests {
  @Test func search() async throws {
    let config = try await TestHelpers.loadConfig()
    let apiKey = try TestHelpers.requireAPIKey("BRAVE_AI_SEARCH", from: config)

    let testQuery = "Swift programming language"
    let encodedQuery =
      testQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? testQuery
    let searchURL = "https://api.search.brave.com/res/v1/web/search?q=\(encodedQuery)"

    let request = TestHelpers.makeGETRequest(
      url: searchURL,
      headers: ["X-Subscription-Token": apiKey]
    )

    let searchResponse = try await TestHelpers.executeRequest(
      request,
      responseType: BraveSearchResponse.self
    )

    #expect(searchResponse.type == "search")

    if let webResults = searchResponse.web {
      #expect(!webResults.results.isEmpty)

      let firstResult = webResults.results.first!
      #expect(!firstResult.title.isEmpty)
      #expect(!firstResult.url.isEmpty)

    } else if let videosResults = searchResponse.videos {
      #expect(!videosResults.results.isEmpty)

      let firstResult = videosResults.results.first!
      #expect(!firstResult.title.isEmpty)
      #expect(!firstResult.url.isEmpty)
    }

    try await Task.sleep(for: .seconds(1))
  }

  @Test func webSearchToolTest() async throws {
    let config = try await TestHelpers.loadConfig()
    let apiKey = try TestHelpers.requireAPIKey("BRAVE_AI_SEARCH", from: config)

    let result = try await webSearch(query: "Swift programming", apiKey: apiKey)

    if result.contains("HTTP status") || result.contains("Error") {
      print("Skipping webSearchToolTest - API rate limit or error: \(result)")
      return
    }

    #expect(!result.isEmpty)
    #expect(result.contains("Search results for 'Swift programming'"))
    #expect(result.contains("URL:"))

    let lines = result.components(separatedBy: .newlines)
    let resultLines = lines.filter { $0.contains(".") && $0.contains("URL:") }
    #expect(resultLines.count > 0)

    try await Task.sleep(for: .seconds(1))
  }
}
