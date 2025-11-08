import AsyncHTTPClient
import Foundation
import NIOCore
import NIOFileSystem
import Subprocess

public func listDirectory() async throws -> String {
  do {
    let result = try await run(.name("ls"), output: .string(limit: 4096))
    return result.standardOutput ?? ""
  } catch {
    throw error
  }
}

func ollama(_ ollamaEndpoint: String, userMessage: String = "What is 420 + 69?") async {
  let chatURL = "\(ollamaEndpoint)/api/chat"
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
      ),
      OllamaTool(
        type: "function",
        function: OllamaFunction(
          name: "read_file",
          description: "Read the contents of a file",
          parameters: OllamaParameters(
            type: "object",
            properties: [
              "file_path": OllamaProperty(
                type: "string",
                description: "The absolue or relative path to the file"
              )
            ],
            required: ["file_path"]
          )
        )
      ),
      OllamaTool(
        type: "function",
        function: OllamaFunction(
          name: "list_directory",
          description: "List the contents of the current directory",
          parameters: OllamaParameters(
            type: "object",
            properties: [:],
            required: []
          )
        )
      ),
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
          "When asked to list files in the directory, use the list_directory tool."
      ))
    chat.append(
      OllamaMessage(
        role: "system",
        content:
          "When asked to perform calculations, use the calculate tool."
      ))
    chat.append(
      OllamaMessage(
        role: "system",
        content:
          "When asked to read files, use the read_file tool."
      ))
    chat.append(OllamaMessage(role: "user", content: userMessage))
    let message = OllamaChatRequest(model: "\(model)", messages: chat, tools: tools)
    let data = try encoder.encode(message)
    let bytes = ByteBuffer(bytes: data)
    print("Messages: \(chat.count), bytes:\(bytes.readableBytes)")
    var request = HTTPClientRequest(url: chatURL)
    request.method = .POST
    request.headers.add(name: "Content-Type", value: "application/json")
    request.body = .bytes(bytes)
    let response = try await HTTPClient.shared.execute(request, timeout: .seconds(30))
    let body = try await response.body.collect(upTo: .max)
    let jsonString = String(buffer: body)
    guard response.status == .ok else {
      print("HTTP Error: \(response.status)")
      print("Response body: \(jsonString)")
      return
    }

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
      var followUpRequest = HTTPClientRequest(url: chatURL)
      followUpRequest.method = .POST
      followUpRequest.headers.add(name: "Content-Type", value: "application/json")
      followUpRequest.body = .bytes(followUpBytes)
      let followUpResponse = try await HTTPClient.shared.execute(
        followUpRequest, timeout: .seconds(30))
      let followUpBody = try await followUpResponse.body.collect(upTo: .max)
      let followUpJson = String(buffer: followUpBody)
      guard followUpResponse.status == .ok else {
        print("HTTP Error in follow-up: \(followUpResponse.status)")
        print("Response body: \(followUpJson)")
        return
      }

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
  case "read_file":
    guard let filePath = toolCall.function.arguments["file_path"] else {
      return "Missing file_path in arguments"
    }
    do {
      print(FileManager.default.currentDirectoryPath)
      let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
      let content = String(data: data, encoding: .utf8) ?? "Failed to decode as UTF-8"
      return content
    } catch {
      return "Error reading file: \(error.localizedDescription)"
    }
  case "list_directory":
    do {
      let result = try await listDirectory()
      return result
    } catch {
      return "Error listing directory: \(error.localizedDescription)"
    }
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
