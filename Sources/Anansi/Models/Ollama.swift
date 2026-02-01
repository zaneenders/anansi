public struct OllamaChatResponse: Codable, Sendable {
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

public struct OllamaOptions: Codable, Sendable {
  let seed: Int
  init(_ seed: Int = 42069) {
    self.seed = seed
  }
}

public struct OllamaChatRequest: Codable, Sendable {
  let model: String
  let options: OllamaOptions
  let messages: [OllamaMessage]
  let tools: [OllamaTool]?
  let stream: Bool
  let think: Bool

  init(
    model: String, messages: [OllamaMessage], options: OllamaOptions = OllamaOptions(),
    tools: [OllamaTool]? = nil, stream: Bool = true, think: Bool = false
  ) {
    self.model = model
    self.messages = messages
    self.options = options
    self.tools = tools
    self.stream = stream
    self.think = think
  }
}

public struct OllamaTool: Codable, Sendable {
  let type: String
  let function: OllamaFunction
}

public struct OllamaFunction: Codable, Sendable {
  let name: String
  let description: String
  let parameters: OllamaParameters
}

public struct OllamaParameters: Codable, Sendable {
  let type: String
  let properties: [String: OllamaProperty]
  let required: [String]?
}

public struct OllamaProperty: Codable, Sendable {
  let type: String
  let description: String
}

public struct OllamaToolCall: Codable, Sendable {
  let id: String?
  let function: OllamaToolCallFunction
}

public struct OllamaToolCallFunction: Codable, Sendable {
  let index: Int?
  let name: String
  let arguments: [String: String]
}

public enum Role: Codable, Sendable {
  case system
  case user
  case assistant
  case tool

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .system:
      try container.encode("system")
    case .user:
      try container.encode("user")
    case .assistant:
      try container.encode("assistant")
    case .tool:
      try container.encode("tool")
    }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let rawValue = try container.decode(String.self)
    switch rawValue {
    case "system":
      self = .system
    case "user":
      self = .user
    case "assistant":
      self = .assistant
    case "tool":
      self = .tool
    default:
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: decoder.codingPath, debugDescription: "Invalid role value: \(rawValue)")
      )
    }
  }
}

public struct OllamaMessage: Codable, Sendable {
  let role: Role
  var content: String
  var toolCalls: [OllamaToolCall]?
  let toolCallId: String?
  var thinking: String?

  enum CodingKeys: String, CodingKey {
    case role
    case content
    case toolCalls = "tool_calls"
    case toolCallId = "tool_call_id"
    case thinking
  }

  public init(
    role: Role, content: String, toolCalls: [OllamaToolCall]? = nil, toolCallId: String? = nil,
    thinking: String? = nil
  ) {
    self.role = role
    self.content = content
    self.toolCalls = toolCalls
    self.toolCallId = toolCallId
    self.thinking = thinking
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
