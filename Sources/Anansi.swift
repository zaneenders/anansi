import AsyncHTTPClient
import HTTPTypes
import NIOHTTP1

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
