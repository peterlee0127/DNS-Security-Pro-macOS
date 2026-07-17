import AppKit
import SwiftUI

struct MenuBarView: View {
  @Environment(\.openWindow) private var openWindow
  @EnvironmentObject private var appModel: AppModel

  var body: some View {
    Label(statusTitle, systemImage: statusSystemImage)

    if let profile = appModel.selectedProfile {
      Text("\(profile.name) · \(profile.dnsProtocol.shortName)")
    }

    Divider()

    Button {
      appModel.setDNSActive(!appModel.isSystemEnabled)
    } label: {
      Text(dnsToggleTitle)
    }
    .disabled(
      appModel.isBusy
        || appModel.isRefreshingSystemStatus
        || !appModel.hasLoadedSystemStatus
        || appModel.hasSystemStatusError
    )

    Divider()

    Menu("Switch DNS Profile") {
      ForEach(appModel.profiles) { profile in
        Button {
          appModel.selectProfile(id: profile.id)
        } label: {
          if profile.id == appModel.selectedProfileID {
            Label(
              "\(profile.name) · \(profile.dnsProtocol.shortName)",
              systemImage: "checkmark"
            )
          } else {
            Text("\(profile.name) · \(profile.dnsProtocol.shortName)")
          }
        }
      }
    }
    .disabled(appModel.isBusy || appModel.isRefreshingSystemStatus)

    Button("Refresh DNS Status") {
      appModel.refreshSystemStatus(showErrors: true)
    }
    .disabled(appModel.isBusy || appModel.isRefreshingSystemStatus)

    Divider()

    Button("Open DNS Security Pro") {
      openWindow(id: "main")
      NSApplication.shared.activate(ignoringOtherApps: true)
    }

    SettingsLink {
      Text("Settings…")
    }

    Divider()

    Button("Quit DNS Security Pro") {
      NSApplication.shared.terminate(nil)
    }
  }

  private var statusTitle: LocalizedStringKey {
    guard appModel.hasLoadedSystemStatus, !appModel.isRefreshingSystemStatus else {
      return "Checking DNS status…"
    }
    if appModel.hasSystemStatusError { return "DNS status is unavailable" }
    return appModel.isSystemEnabled ? "Encrypted DNS is active" : "Encrypted DNS is off"
  }

  private var statusSystemImage: String {
    if appModel.hasSystemStatusError { return "exclamationmark.shield.fill" }
    return appModel.isSystemEnabled ? "checkmark.shield.fill" : "shield"
  }

  private var dnsToggleTitle: LocalizedStringKey {
    appModel.isSystemEnabled ? "Disconnect DNS" : "Connect DNS"
  }
}
