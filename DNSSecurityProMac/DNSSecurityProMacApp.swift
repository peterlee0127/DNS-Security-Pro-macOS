import SwiftUI

@main
struct DNSSecurityProMacApp: App {
  @Environment(\.scenePhase) private var scenePhase
  @AppStorage(AppPreferenceKey.showsMenuBarExtra) private var showsMenuBarExtra = true
  @StateObject private var appModel = AppModel()

  var body: some Scene {
    WindowGroup(id: "main-v2") {
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
    .defaultSize(width: 900, height: 560)
    .windowResizability(.automatic)
    .commands {
      TutorialCommands()

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
        .keyboardShortcut("d", modifiers: [.command, .shift])
        .disabled(
          appModel.isBusy
            || appModel.isRefreshingSystemStatus
            || !appModel.hasLoadedSystemStatus
            || appModel.hasSystemStatusError
        )

        Button("Test Selected Resolver") {
          if let profile = appModel.selectedProfile {
            appModel.probe(profile)
          }
        }
        .keyboardShortcut("t", modifiers: [.command, .shift])
        .disabled(
          appModel.selectedProfile.map {
            appModel.probingProfileIDs.contains($0.id)
          } ?? true
        )
      }
    }

    MenuBarExtra(isInserted: $showsMenuBarExtra) {
      MenuBarView()
        .environmentObject(appModel)
    } label: {
      Image(systemName: menuBarSystemImage)
        .accessibilityLabel(Text("DNS Security Pro"))
    }
    .menuBarExtraStyle(.menu)

    Window("Tutorial", id: "tutorial") {
      TutorialView()
        .environmentObject(appModel)
    }
    .defaultSize(width: 660, height: 520)

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

private struct TutorialCommands: Commands {
  @Environment(\.openWindow) private var openWindow

  var body: some Commands {
    CommandGroup(after: .help) {
      Button("Tutorial") {
        openWindow(id: "tutorial")
      }
    }
  }
}
