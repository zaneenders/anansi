import AsyncHTTPClient
import Foundation
import NIOCore
import NIOFileSystem
import Subprocess

public let ollamaTools = [
  OllamaTool(
    type: "function",
    function: OllamaFunction(
      name: "read_file",
      description:
        "Read the contents of a given file path. Use this when you want to see what's inside a file. Do not use this with directory names.",
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
      description:
        "List files and directories at a given path. If no path provided, lists current directory. Use this when you need to see what files exist.",
      parameters: OllamaParameters(
        type: "object",
        properties: [
          "path": OllamaProperty(
            type: "string",
            description: "The directory path to list (optional, defaults to current directory)"
          )
        ],
        required: []
      )
    )
  ),
  OllamaTool(
    type: "function",
    function: OllamaFunction(
      name: "get_current_directory",
      description: "Get the current working directory path",
      parameters: OllamaParameters(
        type: "object",
        properties: [:],
        required: []
      )
    )
  ),
  /*
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
 */
]

internal func executeTool(_ toolCall: OllamaToolCall) async -> String {
  switch toolCall.function.name {
  case "read_file":
    guard let filePath = toolCall.function.arguments["file_path"] else {
      return "Missing file_path in arguments"
    }
    do {
      let fileSystem = FileSystem.shared
      let filePath = FilePath(filePath)
      let contents = try await fileSystem.withFileHandle(forReadingAt: filePath) { handle in
        try await handle.readToEnd(maximumSizeAllowed: .bytes(1024 * 1024 * 10))  // 10MB limit
      }
      return String(buffer: contents)
    } catch {
      return "Error reading file: \(error.localizedDescription)"
    }
  case "list_directory":
    let path = toolCall.function.arguments["path"] ?? "."
    do {
      let result = try await listDirectory(path: path.isEmpty ? "." : path)
      print(
        "DEBUG: list_directory('\(path)') -> using '\(path.isEmpty ? "." : path)' returned: '\(result)'"
      )
      return result
    } catch {
      return "Error listing directory '\(path)': \(error.localizedDescription)"
    }
  case "get_current_directory":
    do {
      let result = try await getCurrentDirectory()
      return result
    } catch {
      return "Error getting current directory: \(error.localizedDescription)"
    }
  /*
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
  */
  default:
    return "Unknown tool: \(toolCall.function.name)"
  }
}

func listDirectory(path: String = ".") async throws -> String {
  let fileSystem = FileSystem.shared
  let directoryPath = FilePath(path)

  var result = ""
  try await fileSystem.withDirectoryHandle(atPath: directoryPath) { handle in
    for try await entry in handle.listContents() {
      let entryPath = directoryPath.appending(entry.name)
      let info = try await fileSystem.info(forFileAt: entryPath)

      let type = info?.type == .directory ? "DIR" : "FILE"
      result += "\(type)\t\(entry.name)\n"
    }
  }

  return result
}

func getCurrentDirectory() async throws -> String {
  let fileSystem = FileSystem.shared
  return try await fileSystem.currentWorkingDirectory.string
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
