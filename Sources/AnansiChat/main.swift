import Anansi
import Configuration
import Foundation

@main
struct AnansiChat {
  static func main() async {
    print("🕷️  Welcome to Anansi Chat!")
    print("Type 'quit' or 'exit' to end the conversation\n")

    let config: ConfigReader
    do {
      config = try await ConfigReader(
        provider: EnvironmentVariablesProvider(environmentFilePath: ".env"))
    } catch {
      print("❌ Error loading configuration: \(error)")
      print("Make sure you have a .env file with OLLAMA_ENDPOINT configured")
      return
    }

    guard let ollamaEndpoint = config.string(forKey: "OLLAMA_ENDPOINT") else {
      print("❌ OLLAMA_ENDPOINT not found in configuration")
      print("Please add OLLAMA_ENDPOINT=http://localhost:11434/ to your .env file")
      return
    }

    print("🔗 Connected to: \(ollamaEndpoint)")
    print("─" * 50)
    let chatURL = "\(ollamaEndpoint)/api/chat"

    let agent = Agent(
      endpoint: chatURL,
      messages: [
        OllamaMessage(
          role: "system",
          content:
            """
            You are a helpful assistant with access to tools.

            Available tools:
            - list_directory: List files in the current directory
            - read_file: Read contents of a file (requires file_path parameter)
            - web_search: Search the internet (requires query parameter)

            When you need to use a tool, respond with a function call in JSON format. After tool execution results are provided, continue the conversation normally to answer the user's question based on the tool results.

            Only use tools when necessary to answer the user's question.
            """
        )
      ])

    while true {
      print("\n💬 You:")
      guard let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) else {
        continue
      }

      if input.isEmpty {
        continue
      }

      print("\n🤖 Anansi:")
      await agent.message(input)
      print()
    }
  }
}

extension String {
  static func * (left: String, right: Int) -> String {
    return String(repeating: left, count: right)
  }
}
