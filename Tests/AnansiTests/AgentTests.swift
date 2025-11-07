import AsyncHTTPClient
import Configuration
import Foundation
import NIOCore
import NIOFileSystem
import Testing

@Suite
struct AgentTests {
  @Test func hello() async {
    await gemini()
  }
}

func gemini() async {
  let config = try! await ConfigReader(
    provider: EnvironmentVariablesProvider(environmentFilePath: ".env"))
  guard let geminiKey = config.string(forKey: "GEMINI_API_KEY") else {
    print("GEMINI_API_KEY not found")
    return
  }
  print(geminiKey)
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

struct OllamaChatResponse: Codable {
  let model: String
  let createdAt: String
  let message: OllamaMessage
  let done: Bool
  let doneReason: String?
  let totalDuration: Int?
  let loadDuration: Int?
  let promptEvalCount: Int?
  let promptEvalDuration: Int?
  let evalCount: Int?
  let evalDuration: Int?

  enum CodingKeys: String, CodingKey {
    case model
    case createdAt = "created_at"
    case message
    case done
    case doneReason = "done_reason"
    case totalDuration = "total_duration"
    case loadDuration = "load_duration"
    case promptEvalCount = "prompt_eval_count"
    case promptEvalDuration = "prompt_eval_duration"
    case evalCount = "eval_count"
    case evalDuration = "eval_duration"
  }

  var doneMessage: String {
    """
    done_reason:\(self.doneReason!)
    total_duration:\(self.totalDuration!)
    load_duration:\(self.loadDuration!)
    prompt_eval_count:\(self.promptEvalCount!)
    prompt_eval_duration:\(self.promptEvalDuration!)
    eval_count:\(self.evalCount!)
    eval_duration:\(self.evalDuration!)
    """
  }
}

struct OllamaOptions: Codable {
  let seed: Int
  init(_ seed: Int = 42069) {
    self.seed = seed
  }
}

struct OllamaChatRequest: Codable {
  let model: String
  let options: OllamaOptions
  let messages: [OllamaMessage]
  let tools: [OllamaTool]?

  init(
    model: String, messages: [OllamaMessage], options: OllamaOptions = OllamaOptions(),
    tools: [OllamaTool]? = nil
  ) {
    self.model = model
    self.messages = messages
    self.options = options
    self.tools = tools
  }
}

struct OllamaTool: Codable {
  let type: String
  let function: OllamaFunction
}

struct OllamaFunction: Codable {
  let name: String
  let description: String
  let parameters: OllamaParameters
}

struct OllamaParameters: Codable {
  let type: String
  let properties: [String: OllamaProperty]
  let required: [String]?
}

struct OllamaProperty: Codable {
  let type: String
  let description: String
}

struct OllamaToolCall: Codable {
  let id: String?
  let function: OllamaToolCallFunction
}

struct OllamaToolCallFunction: Codable {
  let index: Int?
  let name: String
  let arguments: [String: String]
}

struct OllamaMessage: Codable {
  enum Role: Codable {
    case system
    case user
    case assistant
    case tool
  }
  let role: String
  var content: String
  var toolCalls: [OllamaToolCall]?
  let toolCallId: String?

  enum CodingKeys: String, CodingKey {
    case role
    case content
    case toolCalls = "tool_calls"
    case toolCallId = "tool_call_id"
  }

  init(role: String, content: String, toolCalls: [OllamaToolCall]? = nil, toolCallId: String? = nil)
  {
    self.role = role
    self.content = content
    self.toolCalls = toolCalls
    self.toolCallId = toolCallId
  }
}
