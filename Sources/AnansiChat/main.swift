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

            Tools: 
            - list_directory 
            - read_file
            - web_search

            list_directory use when asked to list files in the directory.

            read_file use When needed to read files.

            web_search use when you need to search the internet for current information, news, or topics not covered by your training data.

            Continue using tools as needed until you have completely answered the user's question. When you have provided a complete answer and no longer need to use tools, respond normally without making any tool calls.
            """
        )
      ])

    while true {
      print("\n💬 You:", terminator: " ")
      guard let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) else {
        continue
      }

      if input.isEmpty {
        continue
      }

      print("\n🤖 Anansi:", terminator: " ")
      await agent.message(input)
    }
  }
}

extension String {
  static func * (left: String, right: Int) -> String {
    return String(repeating: left, count: right)
  }
}
