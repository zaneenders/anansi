import Testing

@testable import Anansi

@Suite
struct AnansiTests {
  @Test
  func basic() async throws {
    var anansi = Anansi()
    // try await anansi.view(url: "https://zaneenders.com")
  }

  @Test
  func htmlStartTagTest() {
    let html_contents = """
      <!DOCTYPE html>
      <html lang="en">
      """
    let doc = Document(parsing: html_contents)
    let expected: [Document.Nodes] = [.DOCTYPE, .html(.start)]
    #expect(doc.elements == expected)
  }

  @Test
  func htmlEndTagTest() {
    let html_contents = """
      <!DOCTYPE html>
      <html lang="en">
      </html>
      """
    let doc = Document(parsing: html_contents)
    let expected: [Document.Nodes] = [.DOCTYPE, .html(.start), .html(.end)]
    #expect(doc.elements == expected)
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
        Zane was Here ->
      </body>
      </html>
      """
    let doc = Document(parsing: html_string)
    let expected: [Document.Nodes] = [.DOCTYPE, .html(.start), .head, .html(.end)]
    print(doc.elements)
    #expect(doc.elements == expected)
  }
}
