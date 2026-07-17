import AppKit
import Foundation

enum AppPreferenceKey {
  static let showsMenuBarExtra = "showsMenuBarExtra"
  static let quitsAfterApplyingDNS = "quitsAfterApplyingDNS"
}

@MainActor
final class AppModel: ObservableObject {
  @Published private(set) var profiles: [DNSProfile] = DNSProfile.builtInProfiles
  @Published private(set) var selectedProfileID = "google-doh"
  @Published private(set) var isSystemEnabled = false
  @Published private(set) var hasLoadedSystemStatus = false
  @Published private(set) var hasSystemStatusError = false
  @Published private(set) var isRefreshingSystemStatus = false
  @Published private(set) var isBusy = false
  @Published var alert: AppAlert?

  private let repository: DNSProfileRepository
  private let systemDNSManager: SystemDNSManager
  private var hasStarted = false

  init(
    repository: DNSProfileRepository = DNSProfileRepository(),
    systemDNSManager: SystemDNSManager = .shared
  ) {
    self.repository = repository
    self.systemDNSManager = systemDNSManager
  }

  var selectedProfile: DNSProfile? {
    profiles.first { $0.id == selectedProfileID }
  }

  var customProfiles: [DNSProfile] {
    profiles.filter { !$0.isBuiltIn }
  }

  func start() {
    guard !hasStarted else { return }
    hasStarted = true

    do {
      let snapshot = try repository.load()
      profiles = snapshot.profiles
      selectedProfileID = snapshot.selectedProfileID
    } catch {
      alert = AppAlert(
        title: String(localized: "Profiles Could Not Be Loaded"),
        message: error.localizedDescription
      )
    }

    refreshSystemStatus()
  }

  func refreshSystemStatus(showErrors: Bool = false) {
    guard !isRefreshingSystemStatus else { return }
    isRefreshingSystemStatus = true
    systemDNSManager.loadStatus { [weak self] result in
      DispatchQueue.main.async {
        guard let self else { return }
        self.isRefreshingSystemStatus = false
        self.hasLoadedSystemStatus = true
        switch result {
        case .success(let isEnabled):
          self.isSystemEnabled = isEnabled
          self.hasSystemStatusError = false
        case .failure(let error):
          self.hasSystemStatusError = true
          if showErrors {
            self.alert = AppAlert(
              title: String(localized: "DNS Status Error"),
              message: error.localizedDescription
            )
          }
        }
      }
    }
  }

  func setDNSActive(_ enabled: Bool) {
    guard !isBusy, !isRefreshingSystemStatus else { return }
    guard hasLoadedSystemStatus, !hasSystemStatusError else {
      refreshSystemStatus(showErrors: true)
      return
    }
    isBusy = true

    if enabled {
      guard let selectedProfile else {
        isBusy = false
        alert = AppAlert(
          title: String(localized: "No DNS Profile Selected"),
          message: String(localized: "Choose a profile before connecting.")
        )
        return
      }

      systemDNSManager.install(profile: selectedProfile) { [weak self] result in
        DispatchQueue.main.async {
          guard let self else { return }
          self.isBusy = false
          switch result {
          case .success(let isEnabled):
            self.isSystemEnabled = isEnabled
            self.hasLoadedSystemStatus = true
            self.hasSystemStatusError = false
            if !isEnabled {
              self.alert = AppAlert(
                title: String(localized: "Approval Required"),
                message: String(localized: "Open System Settings → Network → VPN & Filters → DNS Security Pro, approve the configuration, then return and refresh the status.")
              )
            } else {
              self.quitAfterSuccessfulDNSChangeIfNeeded()
            }
          case .failure(let error):
            self.alert = AppAlert(
              title: String(localized: "DNS Could Not Be Enabled"),
              message: error.localizedDescription
            )
          }
        }
      }
    } else {
      systemDNSManager.remove { [weak self] result in
        DispatchQueue.main.async {
          guard let self else { return }
          self.isBusy = false
          switch result {
          case .success:
            self.isSystemEnabled = false
            self.hasLoadedSystemStatus = true
            self.hasSystemStatusError = false
            self.quitAfterSuccessfulDNSChangeIfNeeded()
          case .failure(let error):
            self.alert = AppAlert(
              title: String(localized: "DNS Could Not Be Disabled"),
              message: error.localizedDescription
            )
          }
        }
      }
    }
  }

  func selectProfile(id: String) {
    guard !isBusy, !isRefreshingSystemStatus else { return }
    guard profiles.contains(where: { $0.id == id }) else { return }

    let previousProfileID = selectedProfileID
    selectedProfileID = id
    guard persist() else {
      selectedProfileID = previousProfileID
      return
    }

    if isSystemEnabled, !hasSystemStatusError, let selectedProfile {
      isBusy = true
      systemDNSManager.install(profile: selectedProfile) { [weak self] result in
        DispatchQueue.main.async {
          guard let self else { return }
          self.isBusy = false
          switch result {
          case .success(let enabled):
            self.isSystemEnabled = enabled
            self.hasLoadedSystemStatus = true
            self.hasSystemStatusError = false
            if enabled {
              self.quitAfterSuccessfulDNSChangeIfNeeded()
            } else {
              self.alert = AppAlert(
                title: String(localized: "Approval Required"),
                message: String(localized: "Open System Settings → Network → VPN & Filters → DNS Security Pro, approve the configuration, then return and refresh the status.")
              )
            }
          case .failure(let error):
            self.selectedProfileID = previousProfileID
            self.persist(showErrors: false)
            self.alert = AppAlert(
              title: String(localized: "DNS Profile Could Not Be Applied"),
              message: error.localizedDescription
            )
          }
        }
      }
    }
  }

  @discardableResult
  func saveProfile(_ profile: DNSProfile) -> Bool {
    guard !isBusy, !isRefreshingSystemStatus else { return false }
    do {
      let validatedProfile = try profile.validated()
      guard !validatedProfile.isBuiltIn else {
        throw AppModelError.builtInProfileIsImmutable
      }

      let duplicate = profiles.contains {
        $0.id != validatedProfile.id
          && $0.name.caseInsensitiveCompare(validatedProfile.name) == .orderedSame
          && $0.dnsProtocol == validatedProfile.dnsProtocol
      }
      guard !duplicate else {
        throw AppModelError.duplicateProfile
      }

      let previousProfiles = profiles
      if let index = profiles.firstIndex(where: { $0.id == validatedProfile.id }) {
        guard !profiles[index].isBuiltIn else {
          throw AppModelError.builtInProfileIsImmutable
        }
        profiles[index] = validatedProfile
      } else {
        profiles.append(validatedProfile)
      }
      profiles.sort(by: Self.profileSort)
      guard persist() else {
        profiles = previousProfiles
        return false
      }

      if isSystemEnabled, selectedProfileID == validatedProfile.id {
        selectProfile(id: validatedProfile.id)
      }
      return true
    } catch {
      alert = AppAlert(
        title: String(localized: "Profile Could Not Be Saved"),
        message: error.localizedDescription
      )
      return false
    }
  }

  func deleteProfile(_ profile: DNSProfile) {
    guard !isBusy, !isRefreshingSystemStatus else { return }
    guard !profile.isBuiltIn else {
      alert = AppAlert(
        title: String(localized: "Built-in Profile"),
        message: String(localized: "Built-in profiles cannot be edited or deleted.")
      )
      return
    }

    let previousProfiles = profiles
    let previousProfileID = selectedProfileID
    let wasSelected = previousProfileID == profile.id
    profiles.removeAll { $0.id == profile.id }
    if wasSelected {
      selectedProfileID = "google-doh"
    }
    guard persist() else {
      profiles = previousProfiles
      selectedProfileID = previousProfileID
      return
    }

    if wasSelected, isSystemEnabled {
      selectProfile(id: selectedProfileID)
    }
  }

  func openNetworkSettings() {
    if let networkURL = URL(
      string: "x-apple.systempreferences:com.apple.Network-Settings.extension"
    ), NSWorkspace.shared.open(networkURL) {
      return
    }

    guard let settingsURL = URL(string: "x-apple.systempreferences:") else { return }
    NSWorkspace.shared.open(settingsURL)
  }

  @discardableResult
  private func persist(showErrors: Bool = true) -> Bool {
    do {
      try repository.save(profiles: profiles, selectedProfileID: selectedProfileID)
      return true
    } catch {
      if showErrors {
        alert = AppAlert(
          title: String(localized: "Profiles Could Not Be Saved"),
          message: error.localizedDescription
        )
      }
      return false
    }
  }

  private func quitAfterSuccessfulDNSChangeIfNeeded() {
    guard UserDefaults.standard.bool(forKey: AppPreferenceKey.quitsAfterApplyingDNS) else {
      return
    }
    NSApplication.shared.terminate(nil)
  }

  private static func profileSort(_ lhs: DNSProfile, _ rhs: DNSProfile) -> Bool {
    if lhs.isBuiltIn != rhs.isBuiltIn {
      return lhs.isBuiltIn && !rhs.isBuiltIn
    }
    if lhs.name != rhs.name {
      return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
    return lhs.dnsProtocol.rawValue < rhs.dnsProtocol.rawValue
  }
}

struct AppAlert: Identifiable {
  let id = UUID()
  let title: String
  let message: String
}

enum AppModelError: LocalizedError {
  case builtInProfileIsImmutable
  case duplicateProfile

  var errorDescription: String? {
    switch self {
    case .builtInProfileIsImmutable:
      return String(localized: "Built-in profiles cannot be edited or deleted.")
    case .duplicateProfile:
      return String(localized: "A profile with the same name and protocol already exists.")
    }
  }
}
