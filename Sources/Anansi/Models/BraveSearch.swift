import Foundation

struct MetaURL: Codable {
  let scheme: String
  let netloc: String
  let hostname: String
  let favicon: String?
  let path: String?
}

struct Thumbnail: Codable {
  let src: String
  let original: String?
  let logo: Bool?
}

struct QueryInfo: Codable {
  let original: String
  let more_results_available: Bool?
  let spellcheck_off: Bool?
  let show_strict_warning: Bool?
  let is_navigational: Bool?
  let is_news_breaking: Bool?
  let country: String?
  let bad_results: Bool?
  let should_fallback: Bool?
  let postal_code: String?
  let city: String?
  let header_country: String?
  let state: String?

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    original = try container.decode(String.self, forKey: .original)
    more_results_available = try container.decodeIfPresent(
      Bool.self, forKey: .more_results_available)
    spellcheck_off = try container.decodeIfPresent(Bool.self, forKey: .spellcheck_off)
    show_strict_warning = try container.decodeIfPresent(Bool.self, forKey: .show_strict_warning)
    is_navigational = try container.decodeIfPresent(Bool.self, forKey: .is_navigational)
    is_news_breaking = try container.decodeIfPresent(Bool.self, forKey: .is_news_breaking)
    country = try container.decodeIfPresent(String.self, forKey: .country)
    bad_results = try container.decodeIfPresent(Bool.self, forKey: .bad_results)
    should_fallback = try container.decodeIfPresent(Bool.self, forKey: .should_fallback)
    postal_code = try container.decodeIfPresent(String.self, forKey: .postal_code)
    city = try container.decodeIfPresent(String.self, forKey: .city)
    header_country = try container.decodeIfPresent(String.self, forKey: .header_country)
    state = try container.decodeIfPresent(String.self, forKey: .state)
  }

  private enum CodingKeys: String, CodingKey {
    case original, more_results_available, spellcheck_off, show_strict_warning
    case is_navigational, is_news_breaking, country, bad_results
    case should_fallback, postal_code, city, header_country, state
  }
}

struct WebResult: Codable {
  let title: String
  let url: String
  let description: String
  let is_source_local: Bool?
  let is_source_both: Bool?
  let language: String?
  let family_friendly: Bool?
  let type: String?
  let subtype: String?
  let age: String?
  let extra_snippets: [String]?
  let profile: Profile?
  let meta_url: MetaURL?
  let thumbnail: Thumbnail?

  struct Profile: Codable {
    let name: String
    let url: String
    let long_name: String
    let img: String?
  }
}

struct VideoResult: Codable {
  let type: String
  let url: String
  let title: String
  let description: String?
  let age: String?
  let page_age: String?
  let fetched_content_timestamp: Int64?
  let video: VideoInfo
  let meta_url: MetaURL?

  struct VideoInfo: Codable {
    let duration: String?
    let views: Int64?
    let creator: String?
    let publisher: String?
    let requires_subscription: Bool?
    let tags: [String]?
    let author: VideoAuthor?

    struct VideoAuthor: Codable {
      let name: String
      let url: String?
    }
  }
}

struct MixedResult: Codable {
  let type: String
  let title: String?
  let url: String?
  let description: String?
  let age: String?
  let thumbnail: Thumbnail?
  let cluster_id: String?
  let extra_snippets: [String]?
  let meta_url: MetaURL?
  let is_source_local: Bool?
  let is_source_both: Bool?
  let language: String?
  let family_friendly: Bool?
}

struct BraveSearchResponse: Codable {
  let type: String
  let web: WebSearchResults?
  let query: QueryInfo?
  let mixed: MixedResults?
  let videos: VideosResults?

  struct WebSearchResults: Codable {
    let type: String
    let results: [WebResult]
    let mixed: [MixedResult]?
  }

  struct MixedResults: Codable {
    let type: String
    let main: [MixedMainResult]?
    let top: [MixedMainResult]?
    let side: [MixedMainResult]?
  }

  struct MixedMainResult: Codable {
    let type: String
    let index: Int?
    let all: Bool?
  }

  struct VideosResults: Codable {
    let type: String
    let results: [VideoResult]
  }
}

struct BraveNewsResponse: Codable {
  let type: String
  let query: QueryInfo?
  let results: [NewsResult]

  struct NewsResult: Codable {
    let type: String
    let title: String
    let url: String
    let description: String
    let age: String?
    let page_age: String?
    let meta_url: MetaURL?
    let thumbnail: Thumbnail?
  }
}

struct BraveImagesResponse: Codable {
  let type: String
  let query: QueryInfo?
  let results: [ImageResult]

  struct ImageResult: Codable {
    let type: String
    let title: String
    let url: String
    let source: String
    let page_fetched: String?
    let thumbnail: ImageThumbnail
    let properties: ImageProperties
    let meta_url: MetaURL?
    let confidence: String?

    struct ImageThumbnail: Codable {
      let src: String
      let original: String?
    }

    struct ImageProperties: Codable {
      let url: String?
      let width: Int?
      let height: Int?
      let size: Int64?
      let format: String?
      let placeholder: String?
    }
  }
}

struct BraveVideosResponse: Codable {
  let type: String
  let query: QueryInfo?
  let results: [VideoResult]
}

struct BraveSuggestResponse: Codable {
  let type: String
  let query: SuggestQuery
  let results: [SuggestResult]

  struct SuggestQuery: Codable {
    let original: String
  }

  struct SuggestResult: Codable {
    let query: String
  }
}

struct BraveSpellcheckResponse: Codable {
  let type: String
  let query: QueryInfo?
  let results: [SpellcheckResult]

  struct SpellcheckResult: Codable {
    let query: String
  }
}
