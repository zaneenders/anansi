import AsyncHTTPClient
import Configuration
import Foundation
import HTTPTypes
import NIOCore
import Testing

@testable import Anansi

@Test func geminiSetup() async throws {
  let config = try await ConfigReader(
    provider: EnvironmentVariablesProvider(environmentFilePath: ".env"))
  guard let geminiApiKey = config.string(forKey: "GEMINI_API_KEY") else {
    Issue.record(
      "GEMINI_API_KEY not found in configuration. Please add GEMINI_API_KEY=... to your .env file")
    return
  }

  let model = "gemini-3-flash-preview"
  let url =
    "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(geminiApiKey)"

  let prompt = GeminiRequest(contents: [
    .init(parts: [.init(text: "Say 'Hello from Gemini!' and nothing else.")])
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
