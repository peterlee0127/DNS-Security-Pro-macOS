import SwiftUI

struct ProfileEditorView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var profile: DNSProfile
  @State private var serversText: String
  @State private var excludedWiFiText: String
  @State private var excludedDomainsText: String

  let onSave: (DNSProfile) -> Bool

  init(profile: DNSProfile, onSave: @escaping (DNSProfile) -> Bool) {
    _profile = State(initialValue: profile)
    _serversText = State(initialValue: profile.servers.joined(separator: ", "))
    _excludedWiFiText = State(
      initialValue: profile.wiFiExclusions.joined(separator: ", ")
    )
    _excludedDomainsText = State(
      initialValue: profile.domainExclusions.joined(separator: ", ")
    )
    self.onSave = onSave
  }

  var body: some View {
    VStack(spacing: 0) {
      Form {
        Section("Profile") {
          TextField("Name", text: $profile.name)
          Picker("Protocol", selection: $profile.dnsProtocol) {
            ForEach(DNSProtocol.allCases) { dnsProtocol in
              Text(dnsProtocol.rawValue).tag(dnsProtocol)
            }
          }
        }

        Section("Resolver") {
          TextField(endpointTitle, text: $profile.endpoint)
          TextField("Bootstrap Servers", text: $serversText)
          Text("Separate multiple IPv4 or IPv6 addresses with commas.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Section("Automatic Rules") {
          TextField("Disable on Wi-Fi Networks", text: $excludedWiFiText)
          Text("Enter SSIDs separated by commas, for example Office Wi-Fi, Home.")
            .font(.caption)
            .foregroundStyle(.secondary)

          TextField("Exclude Domains", text: $excludedDomainsText)
          Text("Matching domains and their subdomains use the normal system DNS.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Section {
          Label(protocolHelp, systemImage: "info.circle")
            .foregroundStyle(.secondary)
        }
      }
      .formStyle(.grouped)
      .onChange(of: profile.dnsProtocol) { _, dnsProtocol in
        updateEndpointPlaceholder(for: dnsProtocol)
        serversText = ""
      }
    }
    .frame(width: 580, height: 620)
    .navigationTitle(profile.name.isEmpty ? "New DNS Profile" : "Edit DNS Profile")
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Cancel") {
          dismiss()
        }
      }
      ToolbarItem(placement: .confirmationAction) {
        Button("Save") {
          profile.servers = serversText
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
          profile.excludedWiFiSSIDs = commaSeparatedValues(excludedWiFiText)
          profile.excludedDomains = commaSeparatedValues(excludedDomainsText)
          if onSave(profile) {
            dismiss()
          }
        }
        .keyboardShortcut(.defaultAction)
      }
    }
  }

  private var endpointTitle: LocalizedStringKey {
    profile.dnsProtocol == .https ? "HTTPS Endpoint URL" : "TLS Server Name"
  }

  private var protocolHelp: LocalizedStringKey {
    profile.dnsProtocol == .https
      ? "DNS over HTTPS requires an https:// endpoint URL. Bootstrap servers are optional."
      : "DNS over TLS requires a certificate server name and at least one bootstrap server."
  }

  private func updateEndpointPlaceholder(for dnsProtocol: DNSProtocol) {
    let endpoint = profile.endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
    switch dnsProtocol {
    case .https where endpoint.isEmpty:
      profile.endpoint = "https://"
    case .tls where endpoint == "https://":
      profile.endpoint = ""
    default:
      break
    }
  }

  private func commaSeparatedValues(_ text: String) -> [String] {
    text
      .split(separator: ",")
      .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }
}
