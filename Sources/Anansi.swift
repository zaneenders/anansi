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
  }
}

struct Document {
  var elements: [Document.Nodes] = []
  init(parsing contents: String) {
    let doc_element = Regex {
      "<!DOCTYPE html>"
    }
    if let match = contents.prefixMatch(of: doc_element) {
      elements.append(.DOCTYPE)
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
