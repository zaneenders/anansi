import AsyncHTTPClient
import Configuration
import Foundation
import HTTPTypes
import NIOCore
import Testing

@testable import Anansi

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
    let jsonString = String(buffer: body)

    #expect(response.status == .ok)

    guard let data = jsonString.data(using: .utf8) else {
      Issue.record("Failed to encode response as UTF-8")
      return
    }

    guard let searchResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let web = searchResponse["web"] as? [String: Any],
      let results = web["results"] as? [[String: Any]]
    else {
      Issue.record("Failed to parse search response")
      return
    }

    #expect(!results.isEmpty, "Search should return results")

    if let firstResult = results.first {
      let title = firstResult["title"] as? String ?? ""
      let url = firstResult["url"] as? String ?? ""
      #expect(!title.isEmpty, "First result should have a title")
      #expect(!url.isEmpty, "First result should have a URL")
      print("✅ Brave Search API test passed - Found \(results.count) results")
      for result in results {
        print(result)
      }
    }

  } catch {
    Issue.record("Brave Search API request failed: \(error.localizedDescription)")
  }
}

@Test func geminiWhatHappenedToday() async throws {
  let config = try await ConfigReader(
    provider: EnvironmentVariablesProvider(environmentFilePath: ".env"))
  guard let geminiApiKey = config.string(forKey: "GEMINI_API_KEY") else {
    Issue.record(
      "GEMINI_API_KEY not found in configuration. Please add GEMINI_API_KEY=... to your .env file")
    return
  }

  // let model = "gemini-3-flash-preview"
  // let model = "gemini-2.5-flash"
  let model = "gemini-2.5-flash-lite"
  let url =
    "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(geminiApiKey)"

  let prompt = GeminiRequest(contents: [
    .init(parts: [
      .init(
        text:
          "What happened in the world today? Please site all content with multiple links and references."
      )
    ])
  ])

  let encoder = JSONEncoder()
  let requestBody = try encoder.encode(prompt)

  var request = HTTPClientRequest(url: url)
  request.method = .POST
  request.headers.add(name: "Content-Type", value: "application/json")
  request.body = .bytes(ByteBuffer(data: requestBody))

  let response = try await HTTPClient.shared.execute(request, timeout: .seconds(30))

  #expect(response.status == .ok)
  let body = try await response.body.collect(upTo: .max)
  let result = try JSONDecoder().decode(GeminiResponse.self, from: body)

  if let answer = result.candidates.first?.content.parts.first?.text {
    print("✅ Gemini response: \(answer)")
    #expect(!answer.isEmpty)
  } else {
    Issue.record("No response text from Gemini")
  }
}
