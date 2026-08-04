import SwiftUI
import UniformTypeIdentifiers

struct DNSProfileArchive: Codable {
  static let currentSchemaVersion = 1

  let schemaVersion: Int
  let exportedAt: Date
  let profiles: [DNSProfile]

  init(profiles: [DNSProfile]) {
    schemaVersion = Self.currentSchemaVersion
    exportedAt = Date()
    self.profiles = profiles
  }

  static func decode(_ data: Data) throws -> DNSProfileArchive {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let archive = try decoder.decode(DNSProfileArchive.self, from: data)
    guard archive.schemaVersion <= currentSchemaVersion else {
      throw DNSProfileArchiveError.unsupportedVersion
    }
    return archive
  }
}

enum DNSProfileArchiveError: LocalizedError {
  case unsupportedVersion

  var errorDescription: String? {
    switch self {
    case .unsupportedVersion:
      return String(localized: "This DNS profile archive was created by a newer app version.")
    }
  }
}

struct DNSProfilesDocument: FileDocument {
  static var readableContentTypes: [UTType] { [.json] }

  var archive: DNSProfileArchive

  init(profiles: [DNSProfile]) {
    archive = DNSProfileArchive(profiles: profiles)
  }

  init(configuration: ReadConfiguration) throws {
    guard let data = configuration.file.regularFileContents else {
      throw CocoaError(.fileReadCorruptFile)
    }
    archive = try DNSProfileArchive.decode(data)
  }

  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return FileWrapper(regularFileWithContents: try encoder.encode(archive))
  }
}
