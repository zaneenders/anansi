import AsyncHTTPClient
import Configuration
import Foundation
import HTTPTypes
import NIOCore
import Testing

@testable import Anansi

@Suite(.serialized) struct BraveTests {

  @Test func search() async throws {
    let config = try await ConfigReader(
      provider: EnvironmentVariablesProvider(environmentFilePath: ".env"))

    guard let apiKey = config.string(forKey: "BRAVE_AI_SEARCH") else {
      Issue.record(
        "BRAVE_AI_SEARCH api key missing"
      )
      return
    }

    let testQuery = "Swift programming language"
    let encodedQuery =
      testQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? testQuery
    let searchURL = "https://api.search.brave.com/res/v1/web/search?q=\(encodedQuery)"

    var request = HTTPClientRequest(url: searchURL)
    request.method = .GET
    request.headers.add(name: "User-Agent", value: "Anansi")
    request.headers.add(name: "Accept", value: "application/json")
    request.headers.add(name: "X-Subscription-Token", value: apiKey)

    do {
      let response = try await HTTPClient.shared.execute(request, timeout: .seconds(30))
      let body = try await response.body.collect(upTo: .max)
      let data = Data(buffer: body)

      #expect(response.status == .ok)

      do {
        let decoder = JSONDecoder()
        let searchResponse = try decoder.decode(BraveSearchResponse.self, from: data)

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
      } catch let decodingError as DecodingError {
        Issue.record("Failed to decode search response: \(decodingError.localizedDescription)")
      } catch {
        Issue.record("Brave Search API request failed: \(error.localizedDescription)")
      }
    }
  }
}
