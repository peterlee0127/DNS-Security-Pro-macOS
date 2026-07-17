import AppKit
import SwiftUI

struct DashboardView: View {
  @EnvironmentObject private var appModel: AppModel
  @State private var showsDetails = false

  private var profileSelection: Binding<String> {
    Binding(
      get: { appModel.selectedProfileID },
      set: { appModel.selectProfile(id: $0) }
    )
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        VStack(alignment: .leading, spacing: 3) {
          Text("Encrypted DNS for your Mac")
            .font(.system(size: 28, weight: .bold))
          Text("Private DNS on Wi-Fi, Ethernet, and every macOS network interface.")
            .font(.callout)
            .foregroundStyle(.secondary)
        }

        protectionCard
        activeProfileCard

        if appModel.hasLoadedSystemStatus,
           !appModel.hasSystemStatusError,
           !appModel.isSystemEnabled {
          approvalNotice
        }
      }
      .padding(24)
      .frame(maxWidth: 760, alignment: .leading)
    }
    .navigationTitle("Dashboard")
    .toolbar {
      ToolbarItem {
        Button {
          appModel.refreshSystemStatus(showErrors: true)
        } label: {
          Label("Refresh DNS Status", systemImage: "arrow.clockwise")
        }
        .disabled(appModel.isBusy || appModel.isRefreshingSystemStatus)
      }
    }
  }

  private var protectionCard: some View {
    HStack(spacing: 18) {
      ZStack {
        Circle()
          .fill(statusColor.opacity(appModel.isSystemEnabled ? 0.16 : 0.08))
          .frame(width: 72, height: 72)
        Image(systemName: statusSystemImage)
          .font(.system(size: 34))
          .foregroundStyle(statusColor)
      }

      VStack(alignment: .leading, spacing: 4) {
        Text(statusTitle)
          .font(.title2.bold())
        if let profile = appModel.selectedProfile {
          Text("\(profile.name) · \(profile.dnsProtocol.shortName)")
            .font(.headline)
            .foregroundStyle(appModel.isSystemEnabled ? .primary : .secondary)
        }
        Text(statusMessage)
          .font(.callout)
          .foregroundStyle(.secondary)
      }

      Spacer(minLength: 16)

      if !appModel.hasLoadedSystemStatus
        || appModel.isBusy
        || appModel.isRefreshingSystemStatus {
        ProgressView()
          .controlSize(.large)
      } else if appModel.hasSystemStatusError {
        Button("Try Again") {
          appModel.refreshSystemStatus(showErrors: true)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
      } else if appModel.isSystemEnabled {
        Button("Disconnect") {
          appModel.setDNSActive(false)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
      } else {
        Button("Connect") {
          appModel.setDNSActive(true)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
      }
    }
    .padding(20)
    .background(
      appModel.isSystemEnabled ? Color.green.opacity(0.09) : Color.secondary.opacity(0.055),
      in: RoundedRectangle(cornerRadius: 14, style: .continuous)
    )
    .overlay {
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .stroke(statusColor.opacity(appModel.isSystemEnabled ? 0.34 : 0.14), lineWidth: 1)
    }
  }

  private var activeProfileCard: some View {
    GroupBox("Selected Profile") {
      VStack(alignment: .leading, spacing: 12) {
        Picker("DNS Profile", selection: profileSelection) {
          ForEach(appModel.profiles) { profile in
            Text("\(profile.name) · \(profile.dnsProtocol.shortName)")
              .tag(profile.id)
          }
        }
        .labelsHidden()
        .disabled(appModel.isBusy || appModel.isRefreshingSystemStatus)

        if let profile = appModel.selectedProfile {
          HStack(spacing: 8) {
            Text(profile.dnsProtocol.shortName)
              .font(.caption.bold())
              .padding(.horizontal, 7)
              .padding(.vertical, 3)
              .background(Color.accentColor.opacity(0.14), in: Capsule())
            Text(profile.endpointHost)
              .font(.callout)
              .foregroundStyle(.secondary)
            Spacer()
          }

          DisclosureGroup("Details", isExpanded: $showsDetails) {
            VStack(alignment: .leading, spacing: 10) {
              Divider()
              DetailRow(title: "Endpoint", value: profile.endpointLabel) {
                copyToPasteboard(profile.endpointLabel)
              }
              DetailRow(
                title: "Bootstrap Servers",
                value: profile.servers.isEmpty
                  ? String(localized: "Automatic")
                  : profile.servers.joined(separator: ", ")
              ) {
                copyToPasteboard(profile.servers.joined(separator: ", "))
              }
            }
            .padding(.top, 6)
          }
          .font(.callout)
        }
      }
      .padding(6)
    }
  }

  private var approvalNotice: some View {
    HStack(spacing: 10) {
      Image(systemName: "info.circle.fill")
        .foregroundStyle(Color.accentColor)
      VStack(alignment: .leading, spacing: 2) {
        Text("System approval may be required the first time you connect.")
          .font(.callout)
        Text("System Settings → Network → VPN & Filters → DNS Security Pro")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      Button("Open Network Settings") {
        appModel.openNetworkSettings()
      }
      .controlSize(.small)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 11)
    .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
  }

  private var statusColor: Color {
    if appModel.hasSystemStatusError { return .orange }
    return appModel.isSystemEnabled ? .green : Color(nsColor: .secondaryLabelColor)
  }

  private var statusSystemImage: String {
    if appModel.hasSystemStatusError { return "exclamationmark.shield.fill" }
    return appModel.isSystemEnabled ? "checkmark.shield.fill" : "shield"
  }

  private var statusTitle: LocalizedStringKey {
    if !appModel.hasLoadedSystemStatus || appModel.isRefreshingSystemStatus {
      return "Checking DNS status…"
    }
    if appModel.hasSystemStatusError {
      return "DNS status is unavailable"
    }
    return appModel.isSystemEnabled ? "Encrypted DNS is active" : "Encrypted DNS is off"
  }

  private var statusMessage: LocalizedStringKey {
    if !appModel.hasLoadedSystemStatus || appModel.isRefreshingSystemStatus {
      return "Reading the current macOS DNS configuration."
    }
    if appModel.hasSystemStatusError {
      return "Refresh to read the current macOS DNS configuration again."
    }
    return appModel.isSystemEnabled
      ? "Your Mac is protected by the selected encrypted DNS profile."
      : "Connect when you want to use this profile."
  }

  private func copyToPasteboard(_ value: String) {
    guard !value.isEmpty else { return }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(value, forType: .string)
  }
}

private struct DetailRow: View {
  let title: LocalizedStringKey
  let value: String
  let copyAction: () -> Void

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 12) {
      Text(title)
        .foregroundStyle(.secondary)
        .frame(width: 125, alignment: .leading)
      Text(value)
        .textSelection(.enabled)
        .lineLimit(2)
      Spacer()
      Button(action: copyAction) {
        Image(systemName: "doc.on.doc")
      }
      .buttonStyle(.plain)
      .foregroundStyle(.secondary)
      .help("Copy")
    }
  }
}
