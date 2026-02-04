import AsyncHTTPClient
import Foundation
import NIOCore
import NIOFileSystem
import Testing

@testable import Anansi

@Suite
class ToolsTests {
  let tempDir: String
  let fileSystem = FileSystem.shared

  init() async throws {
    tempDir = "/tmp/anansi_tools_tests_\(UUID().uuidString)"
    try await createDirectory(path: tempDir)
  }

  deinit {
    let copy = self.tempDir
    Task.immediate {
      try? await FileSystem.shared.removeItem(at: FilePath(copy))
    }
  }

  private func fileContents(at path: String) async throws -> String {
    let filePath = FilePath(path)
    let contents = try await fileSystem.withFileHandle(forReadingAt: filePath) { handle in
      try await handle.readToEnd(maximumSizeAllowed: .bytes(1024 * 1024))
    }
    return String(buffer: contents)
  }

  private func fileExists(at path: String) async -> Bool {
    let filePath = FilePath(path)
    return (try? await fileSystem.info(forFileAt: filePath)) != nil
  }

  private func removeFileIfExists(at path: String) async throws {
    let filePath = FilePath(path)
    if (try? await fileSystem.info(forFileAt: filePath)) != nil {
      try await fileSystem.removeItem(at: filePath)
    }
  }

  @Test func testListDirectory() async throws {
    let testFile1 = "\(tempDir)/test1.txt"
    let testFile2 = "\(tempDir)/test2.txt"
    let testSubDir = "\(tempDir)/subdir"

    try await createNewFile(path: testFile1, content: "Test content 1")
    try await createNewFile(path: testFile2, content: "Test content 2")
    try await createDirectory(path: testSubDir)

    let result = try await listDirectory(path: tempDir)

    #expect(result.contains("FILE\ttest1.txt"))
    #expect(result.contains("FILE\ttest2.txt"))
    #expect(result.contains("DIR\tsubdir"))
  }

  @Test func testGetCurrentDirectory() async throws {
    let result = try await getCurrentDirectory()

    #expect(!result.isEmpty)
    #expect(result.hasPrefix("/"))
  }

  @Test func testCreateNewFile() async throws {
    let testFile = "\(tempDir)/new_file.txt"
    let content = "This is test content for the new file"

    try await createNewFile(path: testFile, content: content)
    let actualContent = try await fileContents(at: testFile)
    #expect(actualContent == content)
  }

  @Test func testCreateNewFileWithNestedPath() async throws {
    let nestedFile = "\(tempDir)/nested/deep/file.txt"
    let content = "Nested file content"

    try await createNewFile(path: nestedFile, content: content)
    let actualContent = try await fileContents(at: nestedFile)
    #expect(actualContent == content)
  }

  @Test func testCreateDirectory() async throws {
    let newDir = "\(tempDir)/new_directory"

    try await createDirectory(path: newDir)

    let dirPath = FilePath(newDir)
    let info = try await fileSystem.info(forFileAt: dirPath)
    #expect(info?.type == .directory)
  }

  @Test func testCreateDirectoryWithNestedPath() async throws {
    let nestedDir = "\(tempDir)/nested/deep/directory"

    try await createDirectory(path: nestedDir)

    let dirPath = FilePath(nestedDir)
    let info = try await fileSystem.info(forFileAt: dirPath)
    #expect(info?.type == .directory)
  }

  @Test func testEditFile() async throws {
    let testFile = "\(tempDir)/edit_test.txt"
    let originalContent = "Original content\nLine 2\nLine 3"
    let oldStr = "Line 2"
    let newStr = "Modified Line 2"

    try await removeFileIfExists(at: testFile)
    try await createNewFile(path: testFile, content: originalContent)
    _ = try await editFile(path: testFile, oldStr: oldStr, newStr: newStr)

    let actualContent = try await fileContents(at: testFile)
    #expect(actualContent.contains(newStr))
    #expect(!actualContent.contains("\n\(oldStr)\n"))
  }

  @Test func testEditFileCreateNew() async throws {
    let newFile = "\(tempDir)/new_edit_file.txt"
    let content = "Content for new file"

    _ = try await editFile(path: newFile, oldStr: "", newStr: content)
    let actualContent = try await fileContents(at: newFile)
    #expect(actualContent == content)
  }

  @Test func testEditFileNotFound() async throws {
    let nonExistentFile = "\(tempDir)/does_not_exist.txt"

    do {
      _ = try await editFile(path: nonExistentFile, oldStr: "something", newStr: "something else")
      Issue.record("Expected AnansiError.fileDoesNotExist but no error was thrown")
    } catch let error as AnansiError {
      switch error {
      case .fileDoesNotExist:
        break  // Expected error
      default:
        Issue.record("Expected fileDoesNotExist error but got: \(error)")
      }
    } catch {
      Issue.record("Expected AnansiError but got: \(error)")
    }
  }

  @Test func testEditFileOldStrNotFound() async throws {
    let testFile = "\(tempDir)/old_str_not_found.txt"
    let content = "Some content here"
    let oldStr = "nonexistent text"
    let newStr = "replacement text"

    try await createNewFile(path: testFile, content: content)

    do {
      _ = try await editFile(path: testFile, oldStr: oldStr, newStr: newStr)
      Issue.record("Expected AnansiError.oldStringNotFound but no error was thrown")
    } catch let error as AnansiError {
      switch error {
      case .oldStringNotFound:
        break  // Expected error
      default:
        Issue.record("Expected oldStringNotFound error but got: \(error)")
      }
    } catch {
      Issue.record("Expected AnansiError but got: \(error)")
    }
  }

  @Test func webSearchToolTest() async throws {
    do {
      let config = try await TestHelpers.loadConfig()
      let apiKey = try TestHelpers.requireAPIKey("BRAVE_AI_SEARCH", from: config)

      let result = try await webSearch(query: "Swift programming", apiKey: apiKey)

      if result.contains("HTTP status") || result.contains("Error") {
        print("Skipping webSearchToolTest - API rate limit or error: \(result)")
        return
      }

      #expect(!result.isEmpty)
      #expect(result.contains("Search results for 'Swift programming'"))
      #expect(result.contains("URL:"))

      let lines = result.components(separatedBy: .newlines)
      let resultLines = lines.filter { $0.contains(".") && $0.contains("URL:") }
      #expect(resultLines.count > 0)
    } catch TestError.missingAPIKey {
      print("Skipping webSearchToolTest - API key not configured")
    }

    try await Task.sleep(for: .seconds(1))
  }

  @Test func webSearchToolTestWithMissingAPIKey() async throws {
    let result = try await webSearch(query: "test query", apiKey: nil as String?)
    #expect(result.contains("API key not configured"))

    try await Task.sleep(for: .seconds(1))
  }

}
