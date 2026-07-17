import SwiftUI

@main
struct DNSSecurityProMacApp: App {
  @Environment(\.scenePhase) private var scenePhase
  @AppStorage(AppPreferenceKey.showsMenuBarExtra) private var showsMenuBarExtra = true
  @StateObject private var appModel = AppModel()

  var body: some Scene {
    WindowGroup(id: "main") {
      RootView()
        .environmentObject(appModel)
        .task {
          appModel.start()
        }
        .onChange(of: scenePhase) { _, phase in
          if phase == .active {
            appModel.refreshSystemStatus()
          }
        }
    }
    .defaultSize(width: 920, height: 620)
    .commands {
      CommandMenu("DNS") {
        Button("Refresh DNS Status") {
          appModel.refreshSystemStatus(showErrors: true)
        }
        .keyboardShortcut("r", modifiers: [.command, .shift])

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
      }
    }

    MenuBarExtra(isInserted: $showsMenuBarExtra) {
      MenuBarView()
        .environmentObject(appModel)
        .task {
          appModel.start()
        }
    } label: {
      Image(systemName: menuBarSystemImage)
        .accessibilityLabel(Text("DNS Security Pro"))
    }
    .menuBarExtraStyle(.menu)

    Settings {
      AppSettingsView()
    }
  }

  private var dnsToggleTitle: LocalizedStringKey {
    appModel.isSystemEnabled ? "Disconnect DNS" : "Connect DNS"
  }

  private var menuBarSystemImage: String {
    if appModel.hasSystemStatusError { return "exclamationmark.shield.fill" }
    return appModel.isSystemEnabled ? "checkmark.shield.fill" : "shield"
  }
}
