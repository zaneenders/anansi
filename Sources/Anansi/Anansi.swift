import AsyncHTTPClient
import Foundation
import NIOCore
import NIOFileSystem
import Subprocess

public actor Agent {
  let model = "llama3-groq-tool-use"
  let endpoint: String
  let encoder = JSONEncoder()
  let decoder = JSONDecoder()
  var messages: [OllamaMessage] = []

  public init(
    endpoint: String,
    messages: [OllamaMessage] = []
  ) {
    self.endpoint = endpoint
    self.messages = messages
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
        model: model, messages: messages, tools: ollamaTools)
      let data = try encoder.encode(message)
      let bytes = ByteBuffer(bytes: data)

      var request = HTTPClientRequest(url: "\(endpoint)/api/chat")
      request.method = .POST
      request.headers.add(name: "Content-Type", value: "application/json")
      request.body = .bytes(bytes)

      let response = try await HTTPClient.shared.execute(request, timeout: .seconds(30))
      let body = try await response.body.collect(upTo: .max)
      let jsonNDString = String(buffer: body)

      guard response.status == .ok else {
        if response.status == .notFound && jsonNDString.contains("not found") {
          print("Model not found. Attempting to pull model...")
          await pullModel()
          print("Retrying request...")
          await sendMessages()
          return
        }
        print("HTTP Error: \(response.status)")
        print("Response body: \(jsonNDString)")
        return
      }

      let lines = jsonNDString.split(separator: "\n", omittingEmptySubsequences: true)
      var currentContent = ""
      var allToolCalls: [OllamaToolCall] = []

      for line in lines {
        do {
          let chatResponse = try decoder.decode(OllamaChatResponse.self, from: Data(line.utf8))

          if !chatResponse.message.content.isEmpty {
            print(chatResponse.message.content, terminator: "")
            currentContent += chatResponse.message.content
          }

          if let calls = chatResponse.message.toolCalls {
            allToolCalls.append(contentsOf: calls)
          }

          if chatResponse.done {
            let finalMessage = OllamaMessage(
              role: chatResponse.message.role,
              content: currentContent,
              toolCalls: allToolCalls.isEmpty ? nil : allToolCalls
            )

            messages.append(finalMessage)

            if !allToolCalls.isEmpty {
              print("\n\n🔧 Using tools...")
              for toolCall in allToolCalls {
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
        } catch {
          continue
        }
      }
    } catch {
      print("Error: \(error)")
    }
  }
}
