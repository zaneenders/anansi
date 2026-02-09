/// Request structure for Gemini API
struct GeminiRequest: Codable {
  let contents: [Content]
  struct Content: Codable {
    let parts: [Part]
  }
  struct Part: Codable {
    let text: String
  }
}

/// Response from Gemini API
struct GeminiResponse: Codable {
  let candidates: [Candidate]
  struct Candidate: Codable {
    let content: Content
  }
  struct Content: Codable {
    let parts: [Part]
  }
  struct Part: Codable {
    let text: String?
  }
}
