import AsyncHTTPClient
import Foundation
import NIOCore
import _NIOFileSystemFoundationCompat

func gemini(_ geminiKey: String) async {
  var req = HTTPClientRequest(
    url:
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=\(geminiKey)"
  )
  req.method = .POST
  req.headers.add(name: "Content-Type", value: "application/json")
  req.body = .bytes(
    ByteBuffer(
      string: """
        {
        "contents": [{
          "parts":[{"text": "Explain how AI works"}]
          }]
        }
        """))
  do {
    print("Sending: \(req)")
    let start = ContinuousClock.now
    let rsp = try await HTTPClient.shared.execute(req, timeout: .seconds(30))
    if rsp.status == .ok {
      let decoder = JSONDecoder()
      let buffer = try await rsp.body.collect(upTo: .max)
      let root = try decoder.decode(Root.self, from: buffer)
      for can in root.candidates {
        if let parts = can.content.parts {
          for part in parts {
            if let text = part.text {
              print(text)
            }
          }
        }
        if let metadata = can.citationMetadata?.citationSources {
          for cite in metadata {
            if let uri = cite.uri {
              print(uri)
            }
          }
        }
      }
      let end = ContinuousClock.now
      print(start.duration(to: end))
    } else {
      print(rsp)
    }
  } catch {
    print(error)
  }
}

private struct Root: Codable {
  let candidates: [Candidate]
  let usageMetadata: UsageMetadata
  let modelVersion: String
}

private struct Candidate: Codable {
  let content: Content
  let finishReason: String?
  let citationMetadata: CitationMetadata?
  let avgLogprobs: Double?
}

private struct CitationMetadata: Codable {
  let citationSources: [CitationSource]?
}

private struct CitationSource: Codable {
  let startIndex: Int?
  let endIndex: Int?
  let uri: String?
}

private struct Content: Codable {
  let parts: [Part]?
  let role: String?
}

private struct Part: Codable {
  let text: String?
}

private struct UsageMetadata: Codable {
  let promptTokenCount: Int?
  let candidatesTokenCount: Int?
  let totalTokenCount: Int?
  let promptTokensDetails: [TokensDetail]?
  let candidatesTokensDetails: [TokensDetail]?
}

struct TokensDetail: Codable {
  let modality: String?
  let tokenCount: Int?
}
