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
  OllamaTool(
    type: "function",
    function: OllamaFunction(
      name: "edit_file",
      description: """
        Make edits to a text file. Replaces 'old_str' with 'new_str' in the given file. 
        'old_str' and 'new_str' MUST be different from each other. If the file specified 
        with path doesn't exist, it will be created.
        """,
      parameters: OllamaParameters(
        type: "object",
        properties: [
          "path": OllamaProperty(
            type: "string",
            description: "The path to the file"
          ),
          "old_str": OllamaProperty(
            type: "string",
            description:
              "Text to search for - must match exactly and must only have one match exactly"
          ),
          "new_str": OllamaProperty(
            type: "string",
            description: "Text to replace old_str with"
          ),
        ],
        required: ["path", "old_str", "new_str"]
      )
    )
  ),
  OllamaTool(
    type: "function",
    function: OllamaFunction(
      name: "create_file",
      description:
        "Create a new file with the specified content. If the file already exists, it will be overwritten.",
      parameters: OllamaParameters(
        type: "object",
        properties: [
          "path": OllamaProperty(
            type: "string",
            description: "The path where the file should be created"
          ),
          "content": OllamaProperty(
            type: "string",
            description: "The content to write to the new file"
          ),
        ],
        required: ["path", "content"]
      )
    )
  ),
  OllamaTool(
    type: "function",
    function: OllamaFunction(
      name: "create_directory",
      description:
        "Create a new directory at the specified path. Creates parent directories if needed.",
      parameters: OllamaParameters(
        type: "object",
        properties: [
          "path": OllamaProperty(
            type: "string",
            description: "The path where the directory should be created"
          )
        ],
        required: ["path"]
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

func executeTool(_ toolCall: OllamaToolCall) async -> String {
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
  case "edit_file":
    guard let path = toolCall.function.arguments["path"],
      let oldStr = toolCall.function.arguments["old_str"],
      let newStr = toolCall.function.arguments["new_str"]
    else {
      return "Missing required arguments: path, old_str, new_str"
    }

    if oldStr == newStr {
      return "Error: old_str and new_str must be different"
    }

    do {
      let result = try await editFile(path: path, oldStr: oldStr, newStr: newStr)
      return result
    } catch {
      return "Error editing file: \(error.localizedDescription)"
    }
  case "create_file":
    guard let path = toolCall.function.arguments["path"],
      let content = toolCall.function.arguments["content"]
    else {
      return "Missing required arguments: path, content"
    }

    do {
      try await createNewFile(path: path, content: content)
      return "Successfully created file \(path)"
    } catch {
      return "Error creating file: \(error.localizedDescription)"
    }
  case "create_directory":
    guard let path = toolCall.function.arguments["path"] else {
      return "Missing required argument: path"
    }

    do {
      try await createDirectory(path: path)
      return "Successfully created directory \(path)"
    } catch {
      return "Error creating directory: \(error.localizedDescription)"
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

func editFile(path: String, oldStr: String, newStr: String) async throws -> String {
  let fileSystem = FileSystem.shared
  let filePath = FilePath(path)

  let fileExists = try await fileSystem.info(forFileAt: filePath) != nil

  if !fileExists {
    if oldStr.isEmpty {
      try await createNewFile(path: path, content: newStr)
      return "Successfully created file \(path)"
    } else {
      throw AnansiError.fileDoesNotExist(path: path)
    }
  }

  let content = try await fileSystem.withFileHandle(forReadingAt: filePath) { handle in
    try await handle.readToEnd(maximumSizeAllowed: .bytes(1024 * 1024 * 10))  // 10MB limit
  }

  let contentString = String(buffer: content)

  let newContent = contentString.replacing(oldStr, with: newStr, maxReplacements: 1)

  if newContent == contentString && !oldStr.isEmpty {
    throw AnansiError.oldStringNotFound(oldString: oldStr)
  }

  let buffer = ByteBuffer(string: newContent)
  _ = try await fileSystem.withFileHandle(
    forWritingAt: filePath, options: .modifyFile(createIfNecessary: false)
  ) { handle in
    try await handle.write(contentsOf: buffer, toAbsoluteOffset: 0)
  }

  return "OK"
}

func createNewFile(path: String, content: String) async throws {
  let fileSystem = FileSystem.shared
  let filePath = FilePath(path)

  let directoryPath = filePath.removingLastComponent()
  if !directoryPath.isEmpty {
    try await fileSystem.createDirectory(at: directoryPath, withIntermediateDirectories: true)
  }

  let buffer = ByteBuffer(string: content)
  _ = try await fileSystem.withFileHandle(
    forWritingAt: filePath, options: .newFile(replaceExisting: true)
  ) { handle in
    try await handle.write(contentsOf: buffer, toAbsoluteOffset: 0)
  }
}

func createDirectory(path: String) async throws {
  let fileSystem = FileSystem.shared
  let directoryPath = FilePath(path)
  try await fileSystem.createDirectory(at: directoryPath, withIntermediateDirectories: true)
}

func webSearch(query: String, apiKey: String? = nil) async throws -> String {
  let apiKey = apiKey ?? ProcessInfo.processInfo.environment["BRAVE_AI_SEARCH"]
  guard let apiKey = apiKey else {
    return
      "Brave Search API key not configured. Please set BRAVE_AI_SEARCH in your environment or .env file."
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
    let data = Data(buffer: body)

    guard (200...299).contains(response.status.code) else {
      return "Search failed with HTTP status: \(response.status)"
    }

    let decoder = JSONDecoder()
    let searchResponse = try decoder.decode(BraveSearchResponse.self, from: data)

    var formattedResults = "Search results for '\(query)':\n\n"
    var resultCount = 0

    if let webResults = searchResponse.web {
      for (index, result) in webResults.results.prefix(5).enumerated() {
        formattedResults += "\(index + 1). \(result.title)\n"
        formattedResults += "   URL: \(result.url)\n"

        if let language = result.language {
          formattedResults += "   Language: \(language)\n"
        }

        if let age = result.age {
          formattedResults += "   Age: \(age)\n"
        }

        if let familyFriendly = result.familyFriendly {
          formattedResults += "   Family Friendly: \(familyFriendly)\n"
        }

        formattedResults += "   \(result.description)\n\n"
        resultCount += 1
      }
    }

    else if let videoResults = searchResponse.videos {
      for (index, result) in videoResults.results.prefix(5).enumerated() {
        formattedResults += "\(index + 1). \(result.title)\n"
        formattedResults += "   URL: \(result.url)\n"
        formattedResults += "   Type: Video\n"

        if let duration = result.video.duration {
          formattedResults += "   Duration: \(duration)\n"
        }

        if let views = result.video.views {
          formattedResults += "   Views: \(views)\n"
        }

        if let creator = result.video.creator {
          formattedResults += "   Creator: \(creator)\n"
        }

        if let age = result.age {
          formattedResults += "   Age: \(age)\n"
        }

        formattedResults += "   \(result.description ?? "No description")\n\n"
        resultCount += 1
      }
    }

    if let queryInfo = searchResponse.query {
      if queryInfo.moreResultsAvailable == true {
        formattedResults += "\nNote: More results are available."
      }
    }

    return resultCount == 0 ? "No results found for '\(query)'" : formattedResults

  } catch let decodingError as DecodingError {
    return "Failed to decode search response: \(decodingError.localizedDescription)"
  } catch {
    return "Error performing web search: \(error.localizedDescription)"
  }
}
