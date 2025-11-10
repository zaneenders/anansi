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

  public func message(_ message: String) async {
    messages.append(
      OllamaMessage(
        role: "user",
        content: message
      ))
    await sendMessages()
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
      var currentContent = ""
      var toolCalls: [OllamaToolCall]?

      for line in lines {
        do {
          let chatResponse = try decoder.decode(OllamaChatResponse.self, from: Data(line.utf8))

          if !chatResponse.message.content.isEmpty {
            print(chatResponse.message.content, terminator: "")
            currentContent += chatResponse.message.content
          }

          if let calls = chatResponse.message.toolCalls {
            toolCalls = calls
          }

          if chatResponse.done {
            let finalMessage = OllamaMessage(
              role: chatResponse.message.role,
              content: currentContent,
              toolCalls: toolCalls
            )

            messages.append(finalMessage)

            if let toolCalls = toolCalls {
              print("\n\n🔧 Using tools...")
              for toolCall in toolCalls {
                print("  📞 \(toolCall.function.name)")
                let result = await executeTool(toolCall)
                messages.append(
                  OllamaMessage(
                    role: "tool",
                    content: result
                  ))
              }
              print("\n🤖 Anansi:")
              await sendMessages()
            }
          }
        } catch {
          continue
        }
      }
    } catch {
      print("Error: \(error)")
    }
  }
}
