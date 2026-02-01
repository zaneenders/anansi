import AsyncHTTPClient
import Foundation
import NIOCore
import NIOFileSystem
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

    Task.immediate {
      // IDK if this is needed but it loads the model
      await sendMessages()
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

  func handleCompleteResponse(finalMessage: OllamaMessage, toolCalls: [OllamaToolCall]) async {
    messages.append(finalMessage)

    if !toolCalls.isEmpty {
      print("\n🔧 Using tools...")
      for toolCall in toolCalls {
        print("  📞 \(toolCall.function.name)")
        let result = await executeTool(toolCall)
        messages.append(
          OllamaMessage(
            role: .tool,
            content: result
          ))
      }
      print("\n🤖 Anansi:")
      await sendMessages()
    }
  }

  func pullModel() async {
    do {
      var request = HTTPClientRequest(url: "\(endpoint)/api/pull")
      request.method = .POST
      request.headers.add(name: "Content-Type", value: "application/json")

      let pullData = try JSONEncoder().encode(["name": model])
      request.body = .bytes(ByteBuffer(bytes: pullData))

      print("Pulling model \(model)... This may take a while.")
      let response = try await HTTPClient.shared.execute(request, timeout: .seconds(600))

      guard response.status == .ok else {
        print("Failed to pull model: \(response.status)")
        return
      }

      let body = try await response.body.collect(upTo: .max)
      let responseString = String(buffer: body)

      if responseString.contains("\"status\":\"success\"")
        || responseString.contains("\"status\":\"pulling\"")
      {
        print("Model \(model) pulled successfully!")
      } else {
        print("Unexpected response when pulling model: \(responseString)")
      }
    } catch {
      print("Error pulling model: \(error)")
    }
  }

  func sendMessages() async {
    do {
      let message = OllamaChatRequest(
        model: model, messages: messages, tools: ollamaTools, stream: true)
      let data = try encoder.encode(message)
      let bytes = ByteBuffer(bytes: data)

      var request = HTTPClientRequest(url: "\(endpoint)/api/chat")
      request.method = .POST
      request.headers.add(name: "Content-Type", value: "application/json")
      request.body = .bytes(bytes)

      let response = try await HTTPClient.shared.execute(request, timeout: .seconds(3))

      if response.status == .ok {
        var bodyReader = response.body.makeAsyncIterator()
        var chunk = try await bodyReader.next()
        while let line = chunk {
          let jsonNDString = String(buffer: line)
          let chatResponse = try decoder.decode(
            OllamaChatResponse.self, from: Data(jsonNDString.utf8))
          print(chatResponse.message.content, terminator: "")
          chunk = try await bodyReader.next()
        }
      } else {
        print(response.status)
      }
    } catch {
      print("Error: \(error)")
    }
  }
}
