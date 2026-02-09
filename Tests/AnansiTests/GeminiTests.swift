import AsyncHTTPClient
import Configuration
import Foundation
import HTTPTypes
import NIOCore
import Testing

@testable import Anansi

@Suite struct GeminiTests {

  @Test func geminiWhatHappenedToday() async throws {
    let config = try await TestHelpers.loadConfig()
    let geminiApiKey = try TestHelpers.requireAPIKey("GEMINI_API_KEY", from: config)

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

    let request = TestHelpers.makePOSTRequest(url: url, body: requestBody)

    let result = try await TestHelpers.executeRequest(
      request,
      responseType: GeminiResponse.self
    )

    if let answer = result.candidates.first?.content.parts.first?.text {
      #expect(!answer.isEmpty)
    } else {
      Issue.record("No response text from Gemini")
    }
  }

}
