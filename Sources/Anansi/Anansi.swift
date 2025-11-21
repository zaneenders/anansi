import AsyncHTTPClient
import Foundation
import NIOCore
import NIOFileSystem
import Subprocess

public protocol MessageHandler {
  func response(_ message: String)
}

public actor Agent {
  let model: String
  let endpoint: String
  let encoder = JSONEncoder()
  let decoder = JSONDecoder()
  var messages: [OllamaMessage] = []
  let handler: MessageHandler

  public init(
    model: String,
    endpoint: String,
    messages: [OllamaMessage] = [],
    handler: MessageHandler
  ) {
    self.handler = handler
    self.model = model
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

      handler.response("Pulling model \(model)... This may take a while.")
      let response = try await HTTPClient.shared.execute(request, timeout: .seconds(600))

      guard response.status == .ok else {
        handler.response("Failed to pull model: \(response.status)")
        return
      }

      let body = try await response.body.collect(upTo: .max)
      let responseString = String(buffer: body)

      if responseString.contains("\"status\":\"success\"")
        || responseString.contains("\"status\":\"pulling\"")
      {
        handler.response("Model \(model) pulled successfully!")
      } else {
        handler.response("Unexpected response when pulling model: \(responseString)")
      }
    } catch {
      handler.response("Error pulling model: \(error)")
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
          handler.response("Model not found. Attempting to pull model...")
          // await pullModel()
          //print("Retrying request...")
          await sendMessages()
          return
        }
        handler.response("HTTP Error: \(response.status)")
        handler.response("Response body: \(jsonNDString)")
        return
      }

      let lines = jsonNDString.split(separator: "\n", omittingEmptySubsequences: true)
      var currentContent = ""
      var allToolCalls: [OllamaToolCall] = []

      for line in lines {
        do {
          let chatResponse = try decoder.decode(OllamaChatResponse.self, from: Data(line.utf8))

          if !chatResponse.message.content.isEmpty {
            handler.response(chatResponse.message.content)
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
              handler.response("\n\n🔧 Using tools...")
              for toolCall in allToolCalls {
                handler.response("  📞 \(toolCall.function.name)")
                let result = await executeTool(toolCall)
                messages.append(
                  OllamaMessage(
                    role: .tool,
                    content: result
                  ))
              }
              handler.response("\n🤖 Anansi:")
              await sendMessages()
            }
          }
        } catch {
          continue
        }
      }
    } catch {
      handler.response("Error: \(error)")
    }
  }
}
