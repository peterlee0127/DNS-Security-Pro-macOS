import SwiftUI

private enum AppSection: String, Identifiable {
  case dashboard
  case profiles

  var id: String { rawValue }

  var title: LocalizedStringKey {
    switch self {
    case .dashboard: return "Dashboard"
    case .profiles: return "DNS Profiles"
    }
  }

  var systemImage: String {
    switch self {
    case .dashboard: return "shield.lefthalf.filled"
    case .profiles: return "server.rack"
    }
  }
}

struct RootView: View {
  @EnvironmentObject private var appModel: AppModel
  @State private var selection: AppSection? = .dashboard

  var body: some View {
    NavigationSplitView {
      List(selection: $selection) {
        Label {
          HStack {
            Text(AppSection.dashboard.title)
            Spacer()
            Circle()
              .fill(sidebarStatusColor)
              .frame(width: 7, height: 7)
              .accessibilityLabel(Text(sidebarStatusTitle))
          }
        } icon: {
          Image(systemName: AppSection.dashboard.systemImage)
        }
        .tag(AppSection.dashboard)

        Label(AppSection.profiles.title, systemImage: AppSection.profiles.systemImage)
          .tag(AppSection.profiles)
      }
      .listStyle(.sidebar)
      .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 220)
    } detail: {
      switch selection ?? .dashboard {
      case .dashboard:
        DashboardView()
      case .profiles:
        ProfilesView()
      }
    }
    .frame(minWidth: 860, minHeight: 520)
    .alert(item: $appModel.alert) { alert in
      Alert(
        title: Text(alert.title),
        message: Text(alert.message),
        dismissButton: .default(Text("OK"))
      )
    }
  }

  private var sidebarStatusTitle: LocalizedStringKey {
    guard appModel.hasLoadedSystemStatus, !appModel.isRefreshingSystemStatus else {
      return "Checking DNS status…"
    }
    if appModel.hasSystemStatusError { return "DNS status is unavailable" }
    return appModel.isSystemEnabled ? "Encrypted DNS is active" : "Encrypted DNS is off"
  }

  private var sidebarStatusColor: Color {
    if appModel.isRefreshingSystemStatus { return Color.secondary.opacity(0.35) }
    if appModel.hasSystemStatusError { return .orange }
    return appModel.isSystemEnabled ? .green : Color.secondary.opacity(0.35)
  }
}
