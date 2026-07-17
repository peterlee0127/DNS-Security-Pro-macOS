import Foundation
import NetworkExtension

final class SystemDNSManager {
  static let shared = SystemDNSManager()

  private init() {}

  func loadStatus(completion: @escaping (Result<Bool, Error>) -> Void) {
    let manager = NEDNSSettingsManager.shared()
    manager.loadFromPreferences { error in
      if let error {
        completion(.failure(error))
      } else {
        completion(.success(manager.isEnabled))
      }
    }
  }

  func install(
    profile: DNSProfile,
    completion: @escaping (Result<Bool, Error>) -> Void
  ) {
    let manager = NEDNSSettingsManager.shared()
    manager.loadFromPreferences { error in
      if let error {
        completion(.failure(error))
        return
      }

      do {
        manager.localizedDescription = "DNS Security Pro"
        manager.dnsSettings = try self.makeSettings(for: profile)
        // nil means the resolver applies on every macOS network interface,
        // including Wi-Fi, Ethernet, and tethered connections.
        manager.onDemandRules = nil
      } catch {
        completion(.failure(error))
        return
      }

      manager.saveToPreferences { saveError in
        if let saveError, !self.isUnchangedConfiguration(saveError) {
          completion(.failure(saveError))
          return
        }

        manager.loadFromPreferences { reloadError in
          if let reloadError {
            completion(.failure(reloadError))
          } else {
            completion(.success(manager.isEnabled))
          }
        }
      }
    }
  }

  func remove(completion: @escaping (Result<Void, Error>) -> Void) {
    let manager = NEDNSSettingsManager.shared()
    manager.loadFromPreferences { loadError in
      if let loadError {
        completion(.failure(loadError))
        return
      }

      manager.removeFromPreferences { removeError in
        if let removeError {
          completion(.failure(removeError))
        } else {
          completion(.success(()))
        }
      }
    }
  }

  private func makeSettings(for profile: DNSProfile) throws -> NEDNSSettings {
    let profile = try profile.validated()

    switch profile.dnsProtocol {
    case .https:
      guard let url = URL(string: profile.endpoint) else {
        throw DNSProfileValidationError.invalidHTTPSURL
      }
      let settings = NEDNSOverHTTPSSettings(servers: profile.servers)
      settings.serverURL = url
      return settings

    case .tls:
      let settings = NEDNSOverTLSSettings(servers: profile.servers)
      settings.serverName = profile.endpoint
      return settings
    }
  }

  private func isUnchangedConfiguration(_ error: Error) -> Bool {
    error.localizedDescription.localizedCaseInsensitiveContains("configuration is unchanged")
  }
}
