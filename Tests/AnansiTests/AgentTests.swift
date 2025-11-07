import AsyncHTTPClient
import Configuration
import Foundation
import NIOCore
import NIOFileSystem
import Testing

@Suite
struct AgentTests {
  @Test func geminiHello() async {
    await gemini()
  }

  @Test func ollamaTool() async {
    await ollama()
  }
}

func ollama() async {
  let encoder = JSONEncoder()
  let decoder = JSONDecoder()
  do {
    var chat: [OllamaMessage] = []
    let model: OllamaModel = .llama(.llama3_1_8b)
    print(" \(model), inputs: \(model.inputs)")

    // Define available tools
    let tools = [
      OllamaTool(
        type: "function",
        function: OllamaFunction(
          name: "calculate",
          description: "Perform basic arithmetic calculations",
          parameters: OllamaParameters(
            type: "object",
            properties: [
              "expression": OllamaProperty(
                type: "string",
                description: "The mathematical expression to evaluate (e.g., '2 + 3 * 4')"
              )
            ],
            required: ["expression"]
          )
        )
      )
    ]

    chat.append(
      OllamaMessage(
        role: "system",
        content:
          "You are a helpful assistant with access to tools."
      ))
    chat.append(
      OllamaMessage(
        role: "system",
        content:
          "When asked to perform calculations, use the calculate tool."
      ))
    chat.append(OllamaMessage(role: "user", content: "What is 420 + 69?"))
    let message = OllamaChatRequest(model: "\(model)", messages: chat, tools: tools)
    let data = try encoder.encode(message)
    let bytes = ByteBuffer(bytes: data)
    print("Messages: \(chat.count), bytes:\(bytes.readableBytes)")
    var request = HTTPClientRequest(url: "http://192.168.1.177:11434/api/chat")
    request.method = .POST
    request.body = .bytes(bytes)
    let response = try await HTTPClient.shared.execute(request, timeout: .seconds(30))
    let body = try await response.body.collect(upTo: .max)
    let jsonString = String(buffer: body)

    // Parse the NDJSON response
    let lines = jsonString.split(separator: "\n", omittingEmptySubsequences: true)
    var accumulatedMessage: OllamaMessage?
    var executedTools: Set<String> = []
    for line in lines {
      let lineData = Data(line.utf8)
      let chatResponse = try decoder.decode(OllamaChatResponse.self, from: lineData)
      let content = chatResponse.message.content
      if accumulatedMessage == nil {
        accumulatedMessage = chatResponse.message
      } else {
        accumulatedMessage!.content += content
      }
      if let toolCalls = chatResponse.message.toolCalls {
        if accumulatedMessage?.toolCalls == nil {
          accumulatedMessage?.toolCalls = toolCalls
        } else {
          accumulatedMessage?.toolCalls?.append(contentsOf: toolCalls)
        }
      }
      if chatResponse.done {
        break
      }
    }

    guard let finalMessage = accumulatedMessage else {
      print("No message received")
      return
    }

    if let toolCalls = finalMessage.toolCalls {
      print("Toolcall: \(toolCalls)")
      for toolCall in toolCalls {
        let key = "\(toolCall.function.name):\(toolCall.function.arguments)"
        if !executedTools.contains(key) {
          executedTools.insert(key)
          print("🔧 Using tool: \(toolCall.function.name) with \(toolCall.function.arguments)")
          let result = await executeTool(toolCall)
          print("✅ Tool result: \(result)")
          // Add tool response to chat
          chat.append(OllamaMessage(role: "tool", content: result, toolCallId: toolCall.id))
        }
      }

      let followUpMessage = OllamaChatRequest(model: "\(model)", messages: chat, tools: tools)
      let followUpData = try encoder.encode(followUpMessage)
      let followUpBytes = ByteBuffer(bytes: followUpData)
      var followUpRequest = HTTPClientRequest(url: "http://localhost:11434/api/chat")
      followUpRequest.method = .POST
      followUpRequest.body = .bytes(followUpBytes)
      let followUpResponse = try await HTTPClient.shared.execute(
        followUpRequest, timeout: .seconds(30))
      let followUpBody = try await followUpResponse.body.collect(upTo: .max)
      let followUpJson = String(buffer: followUpBody)

      let followUpLines = followUpJson.split(separator: "\n", omittingEmptySubsequences: true)
      var finalAnswer = ""
      for line in followUpLines {
        let lineData = Data(line.utf8)
        let chatResponse = try decoder.decode(OllamaChatResponse.self, from: lineData)
        let content = chatResponse.message.content
        if !content.isEmpty {
          finalAnswer += content
        }
        if chatResponse.done {
          break
        }
      }
      print(finalAnswer)
    } else {
      print("No tool calls in response")
    }
  } catch {
    print("Erorr: \(error.localizedDescription)")
  }
}

private func executeTool(_ toolCall: OllamaToolCall) async -> String {
  switch toolCall.function.name {
  case "calculate":
    guard let expression = toolCall.function.arguments["expression"] else {
      return "Missing expression in arguments"
    }
    let result = calculate(expression: expression)
    return "Result: \(result)"
  default:
    return "Unknown tool: \(toolCall.function.name)"
  }
}

private func calculate(expression: String) -> String {
  let expr = expression.replacing(" ", with: "")
  if let result = evaluateSimpleExpression(expr) {
    return "\(result)"
  } else {
    return "Could not evaluate expression: \(expression)"
  }
}

private func evaluateSimpleExpression(_ expr: String) -> Double? {
  let expression = NSExpression(format: expr)
  return expression.expressionValue(with: nil, context: nil) as? Double
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

public enum OllamaModel: Codable, CustomStringConvertible, Sendable {
  case llama(Llama)
  case gemma3(Gemma3)
  case gemma3n(Gemma3n)
  public var inputs: [Input] {
    switch self {
    case .llama(let model):
      model.inputs
    case .gemma3(let model):
      model.inputs
    case .gemma3n(let model):
      model.inputs
    }
  }
  public var description: String {
    switch self {
    case .llama(let model):
      model.description
    case .gemma3(let model):
      model.description
    case .gemma3n(let model):
      model.description
    }
  }
}

public enum Input: Codable, CustomStringConvertible, Sendable {
  case text
  case image

  public var description: String {
    switch self {
    case .text:
      return "text"
    case .image:
      return "image"
    }
  }
}

public enum Gemma3n: Codable, CustomStringConvertible, Sendable {
  case e2b
  public var description: String {
    var out = "gemma3n:"
    switch self {
    case .e2b:
      out += "e2b"
    }
    return out
  }
  var inputs: [Input] {
    switch self {
    case .e2b:
      return [.text, .image]
    }
  }
}

public enum Llama: Codable, Sendable, CustomStringConvertible {
  case llama3_1_8b
  public var description: String {
    switch self {
    case .llama3_1_8b:
      return "llama3.1:8b"
    }
  }

  var inputs: [Input] {
    switch self {
    case .llama3_1_8b:
      return [.text, .image]
    }
  }
}

public enum Gemma3: Codable, CustomStringConvertible, Sendable {

  case b1
  case b4
  case latest
  case b12
  case b27

  public var description: String {
    var out = "gemma3:"
    switch self {
    case .b1:
      out += "1b"
    case .b4:
      out += "4b"
    case .latest:
      out += "latest"
    case .b12:
      out += "12b"
    case .b27:
      out += "27b"
    }
    return out
  }

  var inputs: [Input] {
    switch self {
    case .b1:
      return [.text]
    case .b4, .latest, .b12, .b27:
      return [.text, .image]
    }
  }
}
