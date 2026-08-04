import SwiftUI

struct DashboardView: View {
  @EnvironmentObject private var appModel: AppModel

  private var profileSelection: Binding<String> {
    Binding(
      get: { appModel.selectedProfileID },
      set: { appModel.selectProfile(id: $0) }
    )
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 12) {
        protectionCard

        if appModel.requiresSystemApproval {
          approvalNotice
        }
      }
      .padding(24)
      .frame(maxWidth: 680, alignment: .leading)
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
    VStack(alignment: .leading, spacing: 18) {
      HStack(spacing: 16) {
        ZStack {
          Circle()
            .fill(statusColor.opacity(appModel.isSystemEnabled ? 0.16 : 0.08))
            .frame(width: 58, height: 58)
          Image(systemName: statusSystemImage)
            .font(.system(size: 28))
            .foregroundStyle(statusColor)
        }

        VStack(alignment: .leading, spacing: 3) {
          Text(statusTitle)
            .font(.title2.bold())
          Text(statusMessage)
            .font(.callout)
            .foregroundStyle(.secondary)
        }

        Spacer(minLength: 12)

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

      Divider()

      VStack(alignment: .leading, spacing: 6) {
        Text("DNS Profile")
          .font(.caption)
          .foregroundStyle(.secondary)

        HStack(spacing: 10) {
          Picker("DNS Profile", selection: profileSelection) {
            ForEach(appModel.profiles) { profile in
              Text("\(profile.name) · \(profile.dnsProtocol.shortName)")
                .tag(profile.id)
            }
          }
          .labelsHidden()
          .frame(maxWidth: 320)
          .disabled(appModel.isBusy || appModel.isRefreshingSystemStatus)

          if let profile = appModel.selectedProfile {
            Text(profile.endpointHost)
              .font(.callout)
              .foregroundStyle(.secondary)
              .lineLimit(1)
              .truncationMode(.middle)
          }
        }
      }

      if let profile = appModel.selectedProfile {
        Divider()
        dnsHealthRow(profile)
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

  private func dnsHealthRow(_ profile: DNSProfile) -> some View {
    HStack(spacing: 12) {
      Image(systemName: probeSystemImage(for: profile))
        .foregroundStyle(probeColor(for: profile))
        .frame(width: 22)

      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 7) {
          Text("Resolver Health")
            .font(.callout.weight(.medium))
          if let latency = appModel.probeResults[profile.id]?.latencyMilliseconds {
            Text("\(latency) ms")
              .font(.caption.monospacedDigit())
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(Color.green.opacity(0.12), in: Capsule())
          }
        }

        Text(probeDetail(for: profile))
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }

      Spacer(minLength: 12)

      Button {
        appModel.probe(profile)
      } label: {
        if appModel.probingProfileIDs.contains(profile.id) {
          ProgressView()
            .controlSize(.small)
        } else {
          Label("Test Resolver", systemImage: "waveform.path.ecg")
        }
      }
      .disabled(appModel.probingProfileIDs.contains(profile.id))
      .controlSize(.small)
    }
  }

  private func probeSystemImage(for profile: DNSProfile) -> String {
    guard let result = appModel.probeResults[profile.id] else {
      return "questionmark.circle"
    }
    return result.status == .reachable
      ? "checkmark.circle.fill"
      : "exclamationmark.triangle.fill"
  }

  private func probeColor(for profile: DNSProfile) -> Color {
    guard let result = appModel.probeResults[profile.id] else { return .secondary }
    return result.status == .reachable ? .green : .orange
  }

  private func probeDetail(for profile: DNSProfile) -> String {
    if appModel.probingProfileIDs.contains(profile.id) {
      return String(localized: "Sending an encrypted DNS query…")
    }
    guard let result = appModel.probeResults[profile.id] else {
      return String(localized: "Not tested yet.")
    }
    let relativeTime = RelativeDateTimeFormatter().localizedString(
      for: result.measuredAt,
      relativeTo: Date()
    )
    return "\(result.detail) \(relativeTime)"
  }

  private var approvalNotice: some View {
    HStack(spacing: 10) {
      Image(systemName: "info.circle.fill")
        .foregroundStyle(Color.accentColor)
      VStack(alignment: .leading, spacing: 2) {
        Text("System approval is required to connect.")
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
    if !appModel.hasLoadedSystemStatus || appModel.isRefreshingSystemStatus {
      return .accentColor
    }
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
      : "Choose a profile, then connect encrypted DNS."
  }
}
