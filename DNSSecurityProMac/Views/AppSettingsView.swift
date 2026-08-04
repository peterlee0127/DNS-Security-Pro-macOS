import ServiceManagement
import SwiftUI

struct AppSettingsView: View {
  @AppStorage(AppPreferenceKey.showsMenuBarExtra) private var showsMenuBarExtra = true
  @AppStorage(AppPreferenceKey.quitsAfterApplyingDNS) private var quitsAfterApplyingDNS = false
  @AppStorage(AppPreferenceKey.notifiesDNSFailures) private var notifiesDNSFailures = false
  @State private var launchesAtLogin = Self.isLoginItemRequested
  @State private var settingsError: String?

  var body: some View {
    Form {
      Section("General") {
        Toggle("Show DNS Security Pro in the menu bar", isOn: $showsMenuBarExtra)
        Text("Keep quick DNS controls available after closing the main window.")
          .font(.caption)
          .foregroundStyle(.secondary)

        Toggle("Open at Login", isOn: $launchesAtLogin)
        Text(loginItemStatusText)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Section("DNS Changes") {
        Toggle("Quit after applying DNS changes", isOn: $quitsAfterApplyingDNS)
        Text("The installed DNS profile remains active after the app quits.")
          .font(.caption)
          .foregroundStyle(.secondary)

        Toggle("Notify me when a DNS change fails", isOn: $notifiesDNSFailures)
        Text("Notifications are only sent for connection, disconnection, or profile errors.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
    .frame(width: 540, height: 430)
    .navigationTitle("Settings")
    .onAppear {
      launchesAtLogin = Self.isLoginItemRequested
    }
    .onChange(of: launchesAtLogin) { _, isEnabled in
      updateLoginItem(isEnabled: isEnabled)
    }
    .onChange(of: notifiesDNSFailures) { _, isEnabled in
      if isEnabled {
        AppNotificationService.shared.requestAuthorization()
      }
    }
    .alert(
      "Settings Could Not Be Updated",
      isPresented: Binding(
        get: { settingsError != nil },
        set: { if !$0 { settingsError = nil } }
      )
    ) {
      Button("OK") {
        settingsError = nil
      }
    } message: {
      Text(settingsError ?? "")
    }
  }

  private var loginItemStatusText: String {
    switch SMAppService.mainApp.status {
    case .enabled:
      return String(localized: "DNS Security Pro opens automatically after you log in.")
    case .requiresApproval:
      return String(localized: "Approval is required in System Settings → General → Login Items.")
    case .notFound:
      return String(localized: "Login item registration is unavailable for this copy of the app.")
    case .notRegistered:
      return String(localized: "The app will not open automatically.")
    @unknown default:
      return String(localized: "Login item status is unavailable.")
    }
  }

  private static var isLoginItemRequested: Bool {
    switch SMAppService.mainApp.status {
    case .enabled, .requiresApproval:
      return true
    default:
      return false
    }
  }

  private func updateLoginItem(isEnabled: Bool) {
    do {
      if isEnabled {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
    } catch {
      settingsError = error.localizedDescription
      launchesAtLogin = Self.isLoginItemRequested
    }
  }
}
