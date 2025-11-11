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

    let agent = Agent(
      model: "gpt-oss:20b",
      endpoint: ollamaEndpoint,
      messages: [
        OllamaMessage(
          role: .system,
          content:
            """
            You are a helpful assistant that can read files, list directories, create files, and edit files using tools.

            Prioritize fast responses!!!

            CRITICAL RULES:
            1. NEVER make up file names, directory contents, or file contents
            2. ONLY respond with information from tool results
            3. Do not add any information that wasn't provided by tools
            4. Be proactive about using tools to understand your environment when relevant

            Available tools:
            - list_directory: Shows files and directories
            - read_file: Shows file contents
            - create_file: Creates new files with specified content
            - create_directory: Creates new directories
            - edit_file: Edits files by replacing text
            - get_current_directory: Gets current working directory path
            - web_search: Searches internet

            Process: User asks → You use tool → You get exact results → You report ONLY those results
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
