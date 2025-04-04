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
    case script
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
      "<!DOCTYPE html>"
    }
    if let match = contents.firstMatch(of: doc_element) {
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
      "<html"
      Capture {
        ZeroOrMore(.any, .reluctant)
      }
      ">"
    }
    let html_end_tag = Regex {
      "</html>"
    }
    do {
      guard let start = try html_start_tag.firstMatch(in: contents) else {
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
    parseStrictTag(contents)
  }

  mutating func parseHeadContents(_ contents: String) {
    print("HEAD: \(contents)")
  }

  mutating func parseStrictTag(_ contents: String) {
    let head_element = Regex {
      "<script"
      Capture {
        ZeroOrMore(.any, .reluctant)
      }
      ">"
      Capture {
        ZeroOrMore(.any, .reluctant)
      }
      "</script>"
    }
    do {
      if let match = try head_element.firstMatch(in: contents) {
        elements.append(.script)
        parserAttributes(String(match.1))
        print(String(match.2))
      }
    } catch {
      print("iDK: \(error)")
      return
    }
  }

  mutating func parserAttributes(_ contents: String) {

    let head_element = Regex {
      """
      src="
      """
      Capture {
        ZeroOrMore(.any, .reluctant)
      }
      """
      "
      """
    }
    do {
      if let match = try head_element.firstMatch(in: contents) {
        print(String(match.1))
      }
    } catch {
      print(error.localizedDescription)
    }
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
