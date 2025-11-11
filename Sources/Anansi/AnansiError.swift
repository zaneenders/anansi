enum AnansiError: Error {
  case fileDoesNotExist(path: String)
  case oldStringNotFound(oldString: String)

  var errorDescription: String? {
    switch self {
    case .fileDoesNotExist(let path):
      return "File does not exist: \(path)"
    case .oldStringNotFound(let oldString):
      return "Old string not found in file: '\(oldString)'"
    }
  }
}
