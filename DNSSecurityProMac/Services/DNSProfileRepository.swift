import Foundation

struct DNSRepositorySnapshot {
  let profiles: [DNSProfile]
  let selectedProfileID: String
}

enum DNSProfileRepositoryError: LocalizedError {
  case storagePathNotFound
  case storageDirectoryCreationFailed(URL)
  case corruptStoredData
  case writeFailed

  var errorDescription: String? {
    switch self {
    case .storagePathNotFound:
      return "Could not locate the Application Support directory."
    case .storageDirectoryCreationFailed(let url):
      return "Could not create the storage directory at \(url.path)."
    case .corruptStoredData:
      return "The stored profile data is corrupted. Resetting to default profiles."
    case .writeFailed:
      return "Could not write the profile data to disk."
    }
  }
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
      guard let applicationSupport = fileManager.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
      ).first else {
        self.storageURL = URL(fileURLWithPath: "/tmp/DNSSecurityPro/profiles.json")
        return
      }
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
    let stored: StoredState
    do {
      stored = try JSONDecoder().decode(StoredState.self, from: data)
    } catch {
      throw DNSProfileRepositoryError.corruptStoredData
    }

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
    do {
      try fileManager.createDirectory(
        at: parentDirectory,
        withIntermediateDirectories: true
      )
    } catch {
      throw DNSProfileRepositoryError.storageDirectoryCreationFailed(parentDirectory)
    }

    let state = StoredState(
      customProfiles: profiles.filter { !$0.isBuiltIn },
      selectedProfileID: selectedProfileID
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(state)
    do {
      try data.write(to: storageURL, options: .atomic)
    } catch {
      throw DNSProfileRepositoryError.writeFailed
    }
  }
}
