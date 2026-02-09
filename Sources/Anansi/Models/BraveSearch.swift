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
  let moreResultsAvailable: Bool?
  let spellcheckOff: Bool?
  let showStrictWarning: Bool?
  let isNavigational: Bool?
  let isNewsBreaking: Bool?
  let country: String?
  let badResults: Bool?
  let shouldFallback: Bool?
  let postalCode: String?
  let city: String?
  let headerCountry: String?
  let state: String?

  enum CodingKeys: String, CodingKey {
    case original
    case moreResultsAvailable = "more_results_available"
    case spellcheckOff = "spellcheck_off"
    case showStrictWarning = "show_strict_warning"
    case isNavigational = "is_navigational"
    case isNewsBreaking = "is_news_breaking"
    case country
    case badResults = "bad_results"
    case shouldFallback = "should_fallback"
    case postalCode = "postal_code"
    case city
    case headerCountry = "header_country"
    case state
  }
}

struct WebResult: Codable {
  let title: String
  let url: String
  let description: String
  let isSourceLocal: Bool?
  let isSourceBoth: Bool?
  let language: String?
  let familyFriendly: Bool?
  let type: String?
  let subtype: String?
  let age: String?
  let extraSnippets: [String]?
  let profile: Profile?
  let metaURL: MetaURL?
  let thumbnail: Thumbnail?

  struct Profile: Codable {
    let name: String
    let url: String
    let longName: String
    let img: String?

    enum CodingKeys: String, CodingKey {
      case name, url, img
      case longName = "long_name"
    }
  }

  enum CodingKeys: String, CodingKey {
    case title, url, description, type, subtype, age, language
    case isSourceLocal = "is_source_local"
    case isSourceBoth = "is_source_both"
    case familyFriendly = "family_friendly"
    case extraSnippets = "extra_snippets"
    case profile
    case metaURL = "meta_url"
    case thumbnail
  }
}

struct VideoResult: Codable {
  let type: String
  let url: String
  let title: String
  let description: String?
  let age: String?
  let pageAge: String?
  let fetchedContentTimestamp: Int64?
  let video: VideoInfo
  let metaURL: MetaURL?

  struct VideoInfo: Codable {
    let duration: String?
    let views: Int64?
    let creator: String?
    let publisher: String?
    let requiresSubscription: Bool?
    let tags: [String]?
    let author: VideoAuthor?

    struct VideoAuthor: Codable {
      let name: String
      let url: String?
    }

    enum CodingKeys: String, CodingKey {
      case duration, views, creator, publisher, tags, author
      case requiresSubscription = "requires_subscription"
    }
  }

  enum CodingKeys: String, CodingKey {
    case type, url, title, description, age, video
    case pageAge = "page_age"
    case fetchedContentTimestamp = "fetched_content_timestamp"
    case metaURL = "meta_url"
  }
}

struct MixedResult: Codable {
  let type: String
  let title: String?
  let url: String?
  let description: String?
  let age: String?
  let thumbnail: Thumbnail?
  let clusterId: String?
  let extraSnippets: [String]?
  let metaURL: MetaURL?
  let isSourceLocal: Bool?
  let isSourceBoth: Bool?
  let language: String?
  let familyFriendly: Bool?

  enum CodingKeys: String, CodingKey {
    case type, title, url, description, age, language
    case thumbnail
    case clusterId = "cluster_id"
    case extraSnippets = "extra_snippets"
    case metaURL = "meta_url"
    case isSourceLocal = "is_source_local"
    case isSourceBoth = "is_source_both"
    case familyFriendly = "family_friendly"
  }
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

struct WebResults: Codable {
  let type: String
  let results: [WebResult]
  let mixed: [MixedResult]?
}

struct VideoResults: Codable {
  let type: String
  let results: [VideoResult]
}

struct BraveSearchResponse: Codable {
  let type: String
  let web: WebResults?
  let query: QueryInfo?
  let mixed: MixedResults?
  let videos: VideoResults?
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
    let pageAge: String?
    let metaURL: MetaURL?
    let thumbnail: Thumbnail?

    enum CodingKeys: String, CodingKey {
      case type, title, url, description, age
      case pageAge = "page_age"
      case metaURL = "meta_url"
      case thumbnail
    }
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
    let pageFetched: String?
    let thumbnail: ImageThumbnail
    let properties: ImageProperties
    let metaURL: MetaURL?
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

    enum CodingKeys: String, CodingKey {
      case type, title, url, source, properties, confidence
      case pageFetched = "page_fetched"
      case thumbnail
      case metaURL = "meta_url"
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

