import Foundation

struct DNSRepositorySnapshot {
  let profiles: [DNSProfile]
  let selectedProfileID: String
}

final class DNSProfileRepository {
  private struct StoredState: Codable {
    var customProfiles: [DNSProfile]
    var selectedProfileID: String
  }

  private let fileManager: FileManager
  private let storageURL: URL

  init(fileManager: FileManager = .default, storageURL: URL? = nil) {
    self.fileManager = fileManager

    if let storageURL {
      self.storageURL = storageURL
    } else {
      let applicationSupport = fileManager.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
      ).first!
      self.storageURL = applicationSupport
        .appendingPathComponent("DNS Security Pro", isDirectory: true)
        .appendingPathComponent("profiles.json", isDirectory: false)
    }
  }

  func load() throws -> DNSRepositorySnapshot {
    guard fileManager.fileExists(atPath: storageURL.path) else {
      return DNSRepositorySnapshot(
        profiles: DNSProfile.builtInProfiles,
        selectedProfileID: "google-doh"
      )
    }

    let data = try Data(contentsOf: storageURL)
    let stored = try JSONDecoder().decode(StoredState.self, from: data)
    let customProfiles = stored.customProfiles.map { profile in
      var copy = profile
      copy.isBuiltIn = false
      return copy
    }
    let profiles = DNSProfile.builtInProfiles + customProfiles
    let selectedProfileID = profiles.contains { $0.id == stored.selectedProfileID }
      ? stored.selectedProfileID
      : "google-doh"

    return DNSRepositorySnapshot(
      profiles: profiles,
      selectedProfileID: selectedProfileID
    )
  }

  func save(profiles: [DNSProfile], selectedProfileID: String) throws {
    let parentDirectory = storageURL.deletingLastPathComponent()
    try fileManager.createDirectory(
      at: parentDirectory,
      withIntermediateDirectories: true
    )

    let state = StoredState(
      customProfiles: profiles.filter { !$0.isBuiltIn },
      selectedProfileID: selectedProfileID
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(state)
    try data.write(to: storageURL, options: .atomic)
  }
}
