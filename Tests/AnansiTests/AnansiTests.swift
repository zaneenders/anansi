import Testing

@testable import Anansi

@Suite
struct AnansiTests {
  @Test
  func basic() async throws {
    var anansi = Anansi()
    try await anansi.view(url: "https://zaneenders.com")
  }

  @Test
  func basicHTMLDocurment() {
    let html_string = """
      <!DOCTYPE html>
      <html lang="ko">
      <head>
      	<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
      	<meta name="description" content="" />
      	<meta name="author" content="" />
      	<meta name="viewport" content="user-scalable=no, initial-scale=1.0, maximum-scale=1.0, minimum-scale=1.0, width=device-width" />
      	<title></title>
      	<link href="css/style.css" rel="stylesheet" />
      </head>
      <body>

      	<script type="text/javascript" src="//ajax.googleapis.com/ajax/libs/jquery/1.7.2/jquery.min.js"></script>
      </body>
      </html>
      """
    let doc = Document(parsing: html_string)
    let expected: [Document.Nodes] = [.DOCTYPE]
    #expect(doc.elements == expected)
  }
}
