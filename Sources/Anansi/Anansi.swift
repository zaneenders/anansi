import AsyncHTTPClient
import Foundation
import NIOCore
import NIOFileSystem
import NIOFoundationCompat
import NIOHTTP1
import Subprocess

public actor Agent {
  let model = "glm-4.7-flash"
  let endpoint: String
  let encoder = JSONEncoder()
  let decoder = JSONDecoder()
  var messages: [OllamaMessage] = []

  public init(
    endpoint: String,
    systemPrompt: String? = nil,
    messages: [OllamaMessage] = []
  ) {
    self.endpoint = endpoint
    self.messages = messages

    if let systemPrompt = systemPrompt {
      self.messages.append(OllamaMessage(role: .system, content: systemPrompt))
    }
  }

  public func message(_ message: String) async {
    messages.append(
      OllamaMessage(
        role: .user,
        content: message
      ))
    await sendMessages()
  }

  func sendMessages() async {
    do {
      var madeToolCalls = false
      var isThiniking = false
      let request = try makeChatRequest()
      let response = try await HTTPClient.shared.execute(request, timeout: .hours(24))
      for try await buffer in response.body {
        if let rsp = try? decoder.decode(OllamaChatResponse.self, from: buffer) {
          if let toolCalls = rsp.message.toolCalls, !toolCalls.isEmpty {
            for toolCall in toolCalls {
              print()
              if toolCall.function.arguments.isEmpty {
                print("🛠️\(toolCall.function.name)()")
              } else {
                print("🛠️\(toolCall.function.name)(", terminator: "")
              }
              for (i, (arg, value)) in toolCall.function.arguments.enumerated() {
                if i == toolCall.function.arguments.count - 1 {
                  print("\(arg):\(value))")
                } else {
                  print("\(arg):\(value),", terminator: " ")
                }
              }
              madeToolCalls = true
              let result = await executeTool(toolCall)
              messages.append(
                OllamaMessage(
                  role: .tool, content: result, toolCalls: nil, toolCallId: toolCall.id))
            }
          } else {
            if let thinking = rsp.message.thinking {
              if isThiniking {
                print(thinking, terminator: "")
              } else {
                print()
                print("🧠" + thinking, terminator: "")
              }
              isThiniking = true
            } else {
              isThiniking = false
              print(rsp.message.content, terminator: "")
            }
          }
        }
      }
      if madeToolCalls {
        await sendMessages()
      }
    } catch {
      print("Error: \(error)")
    }
  }

  private func makeChatRequest() throws -> HTTPClientRequest {
    let message = OllamaChatRequest(
      model: model, messages: messages, tools: ollamaTools, stream: true, think: true)
    let data = try encoder.encode(message)
    var request = HTTPClientRequest(url: endpoint + "/api/chat")
    request.method = .POST
    request.headers.add(name: "Content-Type", value: "application/json")
    request.headers.add(name: "Accept", value: "text/event-stream")
    request.body = .bytes(ByteBuffer(bytes: data))
    return request
  }
}
