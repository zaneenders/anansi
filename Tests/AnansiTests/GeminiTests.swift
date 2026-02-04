import AsyncHTTPClient
import Configuration
import Foundation
import HTTPTypes
import NIOCore
import Testing

@testable import Anansi

@Suite struct GeminiTests {

  @Test func geminiWhatHappenedToday() async throws {
    let config = try await ConfigReader(
      provider: EnvironmentVariablesProvider(environmentFilePath: ".env"))
    guard let geminiApiKey = config.string(forKey: "GEMINI_API_KEY") else {
      Issue.record(
        "GEMINI_API_KEY not found in configuration"
      )
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
      #expect(!answer.isEmpty)
    } else {
      Issue.record("No response text from Gemini")
    }
  }

}
