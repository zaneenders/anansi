import AsyncHTTPClient
import Foundation
import NIOCore
import Subprocess

public let ollamaTools = [
  OllamaTool(
    type: "function",
    function: OllamaFunction(
      name: "read_file",
      description: "Read the contents of a file",
      parameters: OllamaParameters(
        type: "object",
        properties: [
          "file_path": OllamaProperty(
            type: "string",
            description: "The absolute or relative path to the file to read the contents of"
          )
        ],
        required: ["file_path"]
      )
    )
  ),
  OllamaTool(
    type: "function",
    function: OllamaFunction(
      name: "list_directory",
      description: "List the contents of the current directory",
      parameters: OllamaParameters(
        type: "object",
        properties: [:],
        required: []
      )
    )
  ),
  OllamaTool(
    type: "function",
    function: OllamaFunction(
      name: "web_search",
      description: "Search the internet for information",
      parameters: OllamaParameters(
        type: "object",
        properties: [
          "query": OllamaProperty(
            type: "string",
            description: "The search query to look up on the internet"
          )
        ],
        required: ["query"]
      )
    )
  ),
]

internal func executeTool(_ toolCall: OllamaToolCall) async -> String {
  switch toolCall.function.name {
  case "read_file":
    guard let filePath = toolCall.function.arguments["file_path"] else {
      return "Missing file_path in arguments"
    }
    do {
      let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
      let content = String(data: data, encoding: .utf8) ?? "Failed to decode as UTF-8"
      return content
    } catch {
      return "Error reading file: \(error.localizedDescription)"
    }
  case "list_directory":
    do {
      let result = try await listDirectory()
      return result
    } catch {
      return "Error listing directory: \(error.localizedDescription)"
    }
  case "web_search":
    guard let query = toolCall.function.arguments["query"] else {
      return "Missing query in arguments"
    }
    do {
      let result = try await webSearch(query: query)
      return result
    } catch {
      return "Error performing web search: \(error.localizedDescription)"
    }
  default:
    return "Unknown tool: \(toolCall.function.name)"
  }
}

func listDirectory() async throws -> String {
  do {
    let result = try await run(.name("ls"), output: .string(limit: 4096))
    return result.standardOutput ?? ""
  } catch {
    throw error
  }
}

func webSearch(query: String) async throws -> String {
  guard let apiKey = ProcessInfo.processInfo.environment["BRAVE_API_KEY"]
  else {
    return
      "Brave Search API key not configured. Please set BRAVE_API_KEY in your environment or .env file."
  }

  let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
  let searchURL = "https://api.search.brave.com/res/v1/web/search?q=\(encodedQuery)"

  var request = HTTPClientRequest(url: searchURL)
  request.method = .GET
  request.headers.add(name: "User-Agent", value: "Anansi")
  request.headers.add(name: "Accept", value: "application/json")
  request.headers.add(name: "X-Subscription-Token", value: apiKey)

  do {
    let response = try await HTTPClient.shared.execute(request, timeout: .seconds(30))
    let body = try await response.body.collect(upTo: .max)
    let jsonString = String(buffer: body)

    guard (200...299).contains(response.status.code) else {
      return "Search failed with HTTP status: \(response.status)"
    }

    guard let data = jsonString.data(using: .utf8) else {
      return "Failed to encode response as UTF-8"
    }

    guard let searchResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let web = searchResponse["web"] as? [String: Any],
      let results = web["results"] as? [[String: Any]]
    else {
      return "Failed to parse search response"
    }

    var formattedResults = "Search results for '\(query)':\n\n"

    for (index, result) in results.prefix(5).enumerated() {
      let title = result["title"] as? String ?? "No title"
      let url = result["url"] as? String ?? "No URL"
      let description = result["description"] as? String ?? "No description"

      formattedResults += "\(index + 1). \(title)\n"
      formattedResults += "   URL: \(url)\n"
      formattedResults += "   \(description)\n\n"
    }

    return formattedResults.isEmpty ? "No results found for '\(query)'" : formattedResults

  } catch {
    return "Error performing web search: \(error.localizedDescription)"
  }
}
