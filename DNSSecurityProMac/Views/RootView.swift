import AppKit
import SwiftUI

private enum AppSection: String, Identifiable {
  case dashboard
  case profiles
  case tutorial
  case about
  case settings

  var id: String { rawValue }

  var title: LocalizedStringKey {
    switch self {
    case .dashboard: return "Dashboard"
    case .profiles: return "DNS Profiles"
    case .tutorial: return "Tutorial"
    case .about: return "About"
    case .settings: return "Settings"
    }
  }

  var systemImage: String {
    switch self {
    case .dashboard: return "shield.lefthalf.filled"
    case .profiles: return "server.rack"
    case .tutorial: return "graduationcap"
    case .about: return "info.circle"
    case .settings: return "gearshape"
    }
  }
}

struct RootView: View {
  @EnvironmentObject private var appModel: AppModel
  @State private var selection: AppSection? = .dashboard

  var body: some View {
    NavigationSplitView {
      VStack(spacing: 0) {
        sidebarHeader

        List(selection: $selection) {
          Label {
            HStack {
              Text(AppSection.dashboard.title)
              Spacer()
              Circle()
                .fill(sidebarStatusColor)
                .frame(width: 7, height: 7)
                .accessibilityLabel(
                  Text(sidebarStatusTitle)
                )
            }
          } icon: {
            Image(systemName: AppSection.dashboard.systemImage)
          }
          .tag(AppSection.dashboard)

          Label(AppSection.profiles.title, systemImage: AppSection.profiles.systemImage)
            .tag(AppSection.profiles)

          Label(AppSection.tutorial.title, systemImage: AppSection.tutorial.systemImage)
            .tag(AppSection.tutorial)
        }
        .listStyle(.sidebar)

        Divider()

        VStack(spacing: 4) {
          SidebarFooterButton(
            section: .about,
            selection: $selection
          )
          SidebarFooterButton(
            section: .settings,
            selection: $selection
          )
        }
        .padding(8)
      }
      .navigationSplitViewColumnWidth(min: 185, ideal: 210, max: 240)
    } detail: {
      switch selection ?? .dashboard {
      case .dashboard:
        DashboardView()
      case .profiles:
        ProfilesView()
      case .tutorial:
        TutorialView()
      case .about:
        AboutView()
      case .settings:
        AppSettingsView()
      }
    }
    .frame(minWidth: 900, minHeight: 540)
    .alert(item: $appModel.alert) { alert in
      Alert(
        title: Text(alert.title),
        message: Text(alert.message),
        dismissButton: .default(Text("OK"))
      )
    }
  }

  private var sidebarHeader: some View {
    HStack(spacing: 11) {
      Image(nsImage: NSApplication.shared.applicationIconImage)
        .resizable()
        .frame(width: 34, height: 34)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

      VStack(alignment: .leading, spacing: 1) {
        Text("DNS Security Pro")
          .font(.headline)
        Text("Native macOS Edition")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 13)
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

private struct SidebarFooterButton: View {
  let section: AppSection
  @Binding var selection: AppSection?

  var body: some View {
    Button {
      selection = section
    } label: {
      Label(section.title, systemImage: section.systemImage)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(
          selection == section ? Color.accentColor.opacity(0.16) : Color.clear,
          in: RoundedRectangle(cornerRadius: 7)
        )
    }
    .buttonStyle(.plain)
  }
}
