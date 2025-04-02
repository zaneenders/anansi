import AsyncHTTPClient
import HTTPTypes
import NIOHTTP1
import RegexBuilder

public struct Anansi {
  public init() {}

  public func ping(url: String) async throws(AnansiError) -> HTTPResponse {
    do {
      let req = HTTPClientRequest(url: url)
      let rsp = try await HTTPClient.shared.execute(req, timeout: .seconds(5))
      return HTTPResponse(status: rsp.status.httpStatus)
    } catch let error as AsyncHTTPClient.HTTPClientError {
      throw .asyncHTTPClientError(error)
    } catch {
      throw .other(error)
    }
  }

  mutating func view(url: String) async throws(AnansiError) {
    let req = HTTPClientRequest(url: url)
    do {
      let rsp = try await HTTPClient.shared.execute(req, timeout: .seconds(5))
      let buffer = try await rsp.body.collect(upTo: .max)
      let doc = Document(parsing: String(buffer: buffer))
    } catch {
      throw .other(error)
    }
  }
}

extension Document {
  enum Nodes: Equatable {
    case DOCTYPE
    case head
    case html(HTML)
  }

  enum HTML: Equatable {
    case start
    case end
  }
}

struct Document {
  @available(*, deprecated, message: "BETA")
  private(set) public var elements: [Document.Nodes] = []
  init(parsing contents: String) {
    let doc_element = Regex {
      ZeroOrMore {
        .whitespace
      }
      "<!DOCTYPE html>"
      ZeroOrMore {
        .whitespace
      }
    }
    if let match = contents.prefixMatch(of: doc_element) {
      elements.append(.DOCTYPE)
      let next = String(contents[match.endIndex..<contents.endIndex])
      print("NEXT: \(next)")
      parseRestOfDoc(next)
    }
  }

  mutating func parseRestOfDoc(_ contents: String) {
    // Could use jsut firstMatch instead of the whitespace.. IDK
    print("\(#function): \(contents)")
    let html_start_tag = Regex {
      ZeroOrMore {
        .whitespace
      }
      "<html"
      Capture {
        ZeroOrMore(.any, .reluctant)
      }
      ">"
      ZeroOrMore {
        .whitespace
      }
    }
    let html_end_tag = Regex {
      ZeroOrMore {
        .whitespace
      }
      "</html>"
      ZeroOrMore {
        .whitespace
      }
    }
    do {
      guard let start = try html_start_tag.prefixMatch(in: contents) else {
        return
      }
      elements.append(.html(.start))
      guard let end = try html_end_tag.firstMatch(in: contents) else {
        return
      }
      // At this point we have a valid open and closing html tag pair
      parseHTMLBody(String(contents[start.1.endIndex..<end.startIndex]))
      elements.append(.html(.end))
    } catch {
      print("iDK: \(error)")
    }
  }

  mutating func parseHTMLBody(_ contents: String) {
    let head_element = Regex {
      "<head>"
      // TODO parse contents
      Capture {
        ZeroOrMore(.any, .reluctant)
      }
      "</head>"
    }
    do {
      if let match = try head_element.firstMatch(in: contents) {
        elements.append(.head)
        parseHeadContents(String(match.1))
      }
    } catch {
      print("iDK: \(error)")
      return
    }
  }

  mutating func parseHeadContents(_ contents: String) {
    print("HEAD: \(contents)")
  }
}

public enum AnansiError: Error {
  case asyncHTTPClientError(AsyncHTTPClient.HTTPClientError)
  case other(Error)
}

extension HTTPResponseStatus {
  var httpStatus: HTTPResponse.Status {
    return HTTPResponse.Status(integerLiteral: Int(self.code))
  }
}
