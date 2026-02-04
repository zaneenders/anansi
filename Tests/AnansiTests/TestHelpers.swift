import AsyncHTTPClient
import Configuration
import Foundation
import HTTPTypes
import NIOCore
import Testing

@testable import Anansi

struct TestHelpers {
  static func loadConfig() async throws -> ConfigReader {
    return try await ConfigReader(
      provider: EnvironmentVariablesProvider(environmentFilePath: ".env")
    )
  }

  static func requireAPIKey(_ key: String, from config: ConfigReader) throws -> String {
    guard let apiKey = config.string(forKey: key) else {
      Issue.record("\(key) API key missing from configuration")
      throw TestError.missingAPIKey(key)
    }
    return apiKey
  }

  static func makeGETRequest(
    url: String,
    headers: [String: String] = [:]
  ) -> HTTPClientRequest {
    var request = HTTPClientRequest(url: url)
    request.method = .GET
    request.headers.add(name: "User-Agent", value: "Anansi")
    request.headers.add(name: "Accept", value: "application/json")

    for (name, value) in headers {
      request.headers.add(name: name, value: value)
    }

    return request
  }

  static func makePOSTRequest(
    url: String,
    headers: [String: String] = [:],
    body: Data
  ) -> HTTPClientRequest {
    var request = HTTPClientRequest(url: url)
    request.method = .POST
    request.headers.add(name: "User-Agent", value: "Anansi")
    request.headers.add(name: "Content-Type", value: "application/json")

    for (name, value) in headers {
      request.headers.add(name: name, value: value)
    }

    request.body = .bytes(ByteBuffer(data: body))
    return request
  }

  static func executeRequest<T: Codable>(
    _ request: HTTPClientRequest,
    responseType: T.Type,
    timeout: TimeAmount = .seconds(30)
  ) async throws -> T {
    let response = try await HTTPClient.shared.execute(request, timeout: timeout)

    guard response.status == .ok else {
      throw TestError.httpError("HTTP Error: \(response.status)")
    }

    let body = try await response.body.collect(upTo: .max)
    let data = Data(buffer: body)

    do {
      return try JSONDecoder().decode(responseType, from: data)
    } catch let decodingError as DecodingError {
      Issue.record("Failed to decode response: \(decodingError.localizedDescription)")
      throw TestError.decodingError(decodingError)
    }
  }
}

// MARK: - Test Error Types

enum TestError: Error {
  case missingAPIKey(String)
  case httpError(String)
  case decodingError(DecodingError)
}

