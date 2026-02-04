import AsyncHTTPClient
import Configuration
import Foundation
import HTTPTypes
import NIOCore
import Testing

@testable import Anansi

@Suite(.serialized) struct BraveTests {

  @Test func search() async throws {
    let config = try await ConfigReader(
      provider: EnvironmentVariablesProvider(environmentFilePath: ".env"))

    guard let apiKey = config.string(forKey: "BRAVE_AI_SEARCH") else {
      Issue.record(
        "BRAVE_AI_SEARCH api key missing"
      )
      return
    }

    let testQuery = "Swift programming language"
    let encodedQuery =
      testQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? testQuery
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

      #expect(response.status == .ok)

      do {
        let decoder = JSONDecoder()
        let searchResponse = try decoder.decode(BraveSearchResponse.self, from: data)

        #expect(searchResponse.type == "search", "Response should be search type")

        if let webResults = searchResponse.web {
          print("✅ Found web results: \(webResults.results.count)")
          #expect(!webResults.results.isEmpty, "Should have web results")

          let firstResult = webResults.results.first!
          #expect(!firstResult.title.isEmpty, "First result should have title")
          #expect(!firstResult.url.isEmpty, "First result should have URL")
          print("✅ First web result: \(firstResult.title)")

        } else if let videosResults = searchResponse.videos {
          print("✅ Found video results: \(videosResults.results.count)")
          #expect(!videosResults.results.isEmpty, "Should have video results")

          let firstResult = videosResults.results.first!
          #expect(!firstResult.title.isEmpty, "First result should have title")
          #expect(!firstResult.url.isEmpty, "First result should have URL")
          print("✅ First video result: \(firstResult.title)")
        }
      } catch let decodingError as DecodingError {
        Issue.record("Failed to decode search response: \(decodingError.localizedDescription)")
      } catch {
        Issue.record("Brave Search API request failed: \(error.localizedDescription)")
      }
    }
  }
  @Test func braveVideoSearchTest() async throws {
    let config = try await ConfigReader(
      provider: EnvironmentVariablesProvider(environmentFilePath: ".env"))

    guard let apiKey = config.string(forKey: "BRAVE_AI_SEARCH") else {
      Issue.record(
        "BRAVE_AI_SEARCH api key missing"
      )
      return
    }

    let testQuery = "Swift programming tutorials"
    let encodedQuery =
      testQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? testQuery
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

      #expect(response.status == .ok)

      // Check for quota information in headers
      for header in response.headers {
        if header.name.lowercased() == "x-remaining-quota" {
          print("📊 Remaining quota: \(header.value)")
        }
        if header.name.lowercased() == "x-quota-reset" {
          print("📅 Quota reset: \(header.value)")
        }
      }

      let decoder = JSONDecoder()
      let searchResponse = try decoder.decode(BraveSearchResponse.self, from: data)

      #expect(searchResponse.type == "search", "Response should be search type")

      // Test video results specifically
      if let videosResults = searchResponse.videos {
        print("✅ Found \(videosResults.results.count) video results")
        #expect(!videosResults.results.isEmpty, "Should have video results")

        for (index, result) in videosResults.results.enumerated() {
          print("📹 Video \(index + 1): \(result.title)")

          // Test video metadata structure
          #expect(!result.title.isEmpty, "Video should have title")
          #expect(!result.url.isEmpty, "Video should have URL")
          #expect(result.type == "video_result", "Should be video result type")

          // Test video info (all optional fields)
          if let duration = result.video.duration {
            print("   ⏱️ Duration: \(duration)")
            #expect(!duration.isEmpty, "Duration should not be empty when present")
          }

          if let views = result.video.views {
            print("   👁️ Views: \(views)")
            #expect(views > 0, "Views should be positive")
          }

          if let creator = result.video.creator {
            print("   👤 Creator: \(creator)")
            #expect(!creator.isEmpty, "Creator should not be empty when present")
          }

          if let publisher = result.video.publisher {
            print("   🏢 Publisher: \(publisher)")
            #expect(!publisher.isEmpty, "Publisher should not be empty when present")
          }

          if let age = result.age {
            print("   📅 Age: \(age)")
          }

          if let description = result.description {
            print("   📝 Description: \(description.prefix(100))...")
            #expect(!description.isEmpty, "Description should not be empty when present")
          }

          print("")
        }

        print("✅ Brave Video Search test passed with full structure validation")

      } else {
        Issue.record("No video results found in response")
      }

    } catch let decodingError as DecodingError {
      Issue.record("Failed to decode video search response: \(decodingError.localizedDescription)")
    } catch {
      Issue.record("Brave Video Search API request failed: \(error.localizedDescription)")
    }
  }
}
