import AsyncHTTPClient
import Foundation
import NIOCore
import NIOFileSystem
import Subprocess

public actor Agent {
  let model: OllamaModel
  let endpoint: String
  let encoder = JSONEncoder()
  let decoder = JSONDecoder()
  var messages: [OllamaMessage] = []

  public init(
    model: OllamaModel = .llama(.llama3_1_8b),
    endpoint: String,
    messages: [OllamaMessage] = []
  ) {
    self.endpoint = endpoint
    self.model = model
    self.messages = messages
  }

  public func message(_ message: String) {
    messages.append(
      OllamaMessage(
        role: "user",
        content: message
      ))
    Task {
      print("sending to model")
      await sendMessages()
    }
  }

  func sendMessages() async {
    do {
      let message = OllamaChatRequest(model: "\(model)", messages: messages, tools: ollamaTools)
      let data = try encoder.encode(message)
      let bytes = ByteBuffer(bytes: data)

      var request = HTTPClientRequest(url: endpoint)
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

      let lines = jsonString.split(separator: "\n", omittingEmptySubsequences: true)

      for line in lines {
        do {
          let chatResponse = try decoder.decode(OllamaChatResponse.self, from: Data(line.utf8))
          await processMessage(chatResponse)
        } catch {
          print("Unable to process: \(line)")
        }
      }
    } catch {
      print(error)
    }
  }

  func processMessage(_ message: OllamaChatResponse) async {
    print(message.message.content, terminator: "")
    messages.append(
      OllamaMessage(
        role: "assistant",
        content: message.message.content
      ))
    if let toolCalls = message.message.toolCalls {
      print("Need to make ToolCalls: \(toolCalls.count)")
      for toolCall in toolCalls {
        print("Calling \(toolCall.function.name)")
        let result = await executeTool(toolCall)
        print("Call completed")
        messages.append(
          OllamaMessage(
            role: "tool",
            content: result
          ))
      }
    }
  }
}
