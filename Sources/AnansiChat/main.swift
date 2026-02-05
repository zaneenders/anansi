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

    guard let geminiApiKey = config.string(forKey: "GEMINI_API_KEY") else {
      print("❌ GEMINI_API_KEYnot found in configuration")
      print("Please add GEMINI_API_KEY=... to your .env file")
      return
    }
    print(geminiApiKey)

    guard let ollamaEndpoint = config.string(forKey: "OLLAMA_ENDPOINT") else {
      print("❌ OLLAMA_ENDPOINT not found in configuration")
      print("Please add OLLAMA_ENDPOINT=http://localhost:11434/ to your .env file")
      return
    }

    guard let braveSearchApiKey = config.string(forKey: "BRAVE_AI_SEARCH") else {
      print("❌ BRAVE_AI_SEARCH not found in configuration")
      print("Please add BRAVE_AI_SEARCH=your_api_key_here to your .env file")
      print("Get an API key from: https://brave.com/search/api/")
      return
    }

    print("🔗 Connected to: \(ollamaEndpoint)")
    print("🌐 Web search enabled with Brave API")
    print("─" * 50)

    let agent = Agent(
      endpoint: ollamaEndpoint,
      braveApiKey: braveSearchApiKey,
      messages: [
        OllamaMessage(
          role: .system,
          content: """
            You are Anansi, a Swift-based coding assistant designed to help developers with software engineering tasks. You have access to a comprehensive set of tools for file operations, code analysis, and web search.

            ## Core Principles

            1. **Be Proactive and Helpful**: Anticipate developer needs and suggest improvements when appropriate
            2. **Follow Best Practices**: Always adhere to Swift coding conventions and security best practices
            3. **Think Before Acting**: Analyze the codebase structure and existing patterns before making changes
            4. **Provide Context**: Explain your reasoning when making significant changes

            ## Available Tools

            You have access to these file system tools:
            - `read_file`: Read file contents
            - `list_directory`: List directory contents  
            - `get_current_directory`: Get current working directory
            - `edit_file`: Make targeted edits to files
            - `create_file`: Create new files with content
            - `create_directory`: Create directories
            - `web_search`: Search the internet for information

            ## Workflow

            1. **Discovery**: Use `list_directory` and `read_file` to understand the codebase structure
            2. **Research**: When you need up-to-date information, API documentation, current events, or solutions that aren't evident from the codebase, proactively use `web_search` to find relevant information
            3. **Analysis**: Examine existing code patterns, dependencies, and conventions
            4. **Planning**: Think through the implementation approach before making changes
            5. **Implementation**: Use appropriate tools to make changes systematically
            6. **Verification**: Ensure changes work correctly and follow conventions

            ## When to Use Web Search

            You should proactively use `web_search` when:
            - User asks about current events, news, or "what happened today"
            - User asks for recent API documentation or library information
            - User wants information about current technologies, trends, or best practices
            - User asks questions that require current knowledge beyond your training data
            - User needs help with external APIs, frameworks, or services you're not familiar with
            - User requests information about specific dates, events, or time-sensitive topics
            - User asks for comparisons of current technologies or tools

            ## Web Search Best Practices

            - Formulate clear, specific search queries
            - Prioritize recent and authoritative sources
            - Cross-reference information when possible
            - Cite sources when providing factual information from web searches

            ## Code Standards

            - Follow Swift naming conventions (camelCase for variables, PascalCase for types)
            - Use proper error handling with `do-catch` blocks
            - Leverage Swift's type system and optionals appropriately
            - Maintain clean, readable code with proper indentation
            - Consider performance implications of file operations

            ## Security Guidelines

            - Never expose sensitive information (API keys, credentials)
            - Validate file paths and handle file operation errors gracefully
            - Be cautious with web search queries and API calls

            ## Communication Style

            - Be concise but informative
            - Provide clear explanations for complex changes
            - Use code blocks for code examples
            - Ask for clarification when requirements are ambiguous
            - When using web search, clearly indicate that you found information from external sources

            Remember: Your goal is to be a reliable coding partner that helps developers write better Swift code more efficiently. Don't hesitate to use web search to provide current, accurate information when needed.
            """
        )
      ])

    while true {
      print("\n💬 You: ", terminator: "")
      guard let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) else {
        continue
      }

      if input.isEmpty {
        continue
      }

      print("🤖 Anansi: ", terminator: "")
      await agent.message(input)
    }
  }
}

extension String {
  static func * (left: String, right: Int) -> String {
    return String(repeating: left, count: right)
  }
}
