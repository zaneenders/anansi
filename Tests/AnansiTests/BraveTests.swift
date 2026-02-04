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

    do {
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
    } catch TestError.httpError(let message) where message.contains("429") {
      // Skip test gracefully if hitting rate limits
      print("Skipping BraveTests.search - API rate limit: \(message)")
    } catch TestError.decodingError {
      Issue.record("Failed to decode search response")
    } catch {
      Issue.record("Brave Search API request failed")
    }
    
    // Add 1-second delay to avoid rate limits
    try await Task.sleep(for: .seconds(1))
  }
}
