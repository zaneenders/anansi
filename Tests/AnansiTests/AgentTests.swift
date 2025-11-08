import AsyncHTTPClient
import Configuration
import Foundation
import NIOCore
import NIOFileSystem
import Testing

@Suite
struct AgentTests {
  @Test func geminiHello() async {
    let config = try! await ConfigReader(
      provider: EnvironmentVariablesProvider(environmentFilePath: ".env"))
    guard let geminiKey = config.string(forKey: "GEMINI_API_KEY") else {
      print("GEMINI_API_KEY not found")
      return
    }
    print(geminiKey)
    await gemini(geminiKey)
  }

  @Test func ollamaTool() async {
    let config = try! await ConfigReader(
      provider: EnvironmentVariablesProvider(environmentFilePath: ".env"))
    guard let ollamaEndpoint = config.string(forKey: "OLLAMA_ENDPOINT") else {
      print("OLLAMA_ENDPOINT not found")
      return
    }
    print(ollamaEndpoint)
    await ollama(ollamaEndpoint)
  }
}
