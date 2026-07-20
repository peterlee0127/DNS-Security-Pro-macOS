import SwiftUI

struct ProfilesView: View {
  @EnvironmentObject private var appModel: AppModel
  @State private var selectedProfileID: String?
  @State private var newProfile: DNSProfile?
  @State private var profilePendingDeletion: DNSProfile?

  private var selectedProfile: DNSProfile? {
    guard let selectedProfileID else { return nil }
    return appModel.profiles.first { $0.id == selectedProfileID }
  }

  var body: some View {
    HSplitView {
      profileList
        .frame(minWidth: 210, idealWidth: 235, maxWidth: 280)

      Group {
        if let selectedProfile {
          ProfileDetailView(
            profile: selectedProfile,
            deleteAction: { profilePendingDeletion = selectedProfile }
          )
          .id(selectedProfile.id)
        } else {
          ContentUnavailableView(
            "Select a DNS profile",
            systemImage: "server.rack",
            description: Text("Choose a profile from the list to view its settings.")
          )
        }
      }
      .frame(minWidth: 390, maxWidth: .infinity, maxHeight: .infinity)
    }
    .navigationTitle("DNS Profiles")
    .toolbar {
      ToolbarItemGroup {
        Button {
          newProfile = .customTemplate
        } label: {
          Label("Add Profile", systemImage: "plus")
        }

        Button(role: .destructive) {
          if let selectedProfile, !selectedProfile.isBuiltIn {
            profilePendingDeletion = selectedProfile
          }
        } label: {
          Label("Delete Profile", systemImage: "trash")
        }
        .disabled(
          selectedProfile?.isBuiltIn != false
            || appModel.isBusy
            || appModel.isRefreshingSystemStatus
        )
      }
    }
    .onAppear {
      if selectedProfileID == nil {
        selectedProfileID = appModel.selectedProfileID
      }
    }
    .onChange(of: appModel.profiles) { _, profiles in
      guard let selectedProfileID else {
        self.selectedProfileID = appModel.selectedProfileID
        return
      }
      if !profiles.contains(where: { $0.id == selectedProfileID }) {
        self.selectedProfileID = appModel.selectedProfileID
      }
    }
    .sheet(item: $newProfile) { profile in
      ProfileEditorView(profile: profile) { updatedProfile in
        let saved = appModel.saveProfile(updatedProfile)
        if saved {
          selectedProfileID = updatedProfile.id
        }
        return saved
      }
    }
    .confirmationDialog(
      "Delete this DNS profile?",
      isPresented: Binding(
        get: { profilePendingDeletion != nil },
        set: { if !$0 { profilePendingDeletion = nil } }
      ),
      presenting: profilePendingDeletion
    ) { profile in
      Button("Delete Profile", role: .destructive) {
        appModel.deleteProfile(profile)
        selectedProfileID = appModel.selectedProfileID
        profilePendingDeletion = nil
      }
      Button("Cancel", role: .cancel) {
        profilePendingDeletion = nil
      }
    } message: { profile in
      Text("\(profile.name) · \(profile.dnsProtocol.shortName)")
    }
  }

  private var profileList: some View {
    VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: 3) {
        Text("DNS Profiles")
          .font(.title2.bold())
        Text("Manage built-in profiles or edit your custom resolvers.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .padding(16)

      Divider()

      List(selection: $selectedProfileID) {
        profileSection(
          title: "Built-in Profiles",
          profiles: appModel.profiles.filter(\.isBuiltIn)
        )

        profileSection(
          title: "Custom Profiles",
          profiles: appModel.customProfiles
        )
      }
      .listStyle(.sidebar)
    }
  }

  @ViewBuilder
  private func profileSection(
    title: LocalizedStringKey,
    profiles: [DNSProfile]
  ) -> some View {
    Section(title) {
      if profiles.isEmpty {
        Text("No custom profiles yet.")
          .foregroundStyle(.secondary)
      } else {
        ForEach(profiles) { profile in
          ProfileListRow(
            profile: profile,
            isActive: appModel.selectedProfileID == profile.id
          )
          .tag(profile.id)
          .contextMenu {
            Button("Use This Profile") {
              appModel.selectProfile(id: profile.id)
            }
            .disabled(appModel.isBusy || appModel.isRefreshingSystemStatus)
            if !profile.isBuiltIn {
              Divider()
              Button("Delete Profile", role: .destructive) {
                profilePendingDeletion = profile
              }
              .disabled(appModel.isBusy || appModel.isRefreshingSystemStatus)
            }
          }
        }
      }
    }
  }
}

private struct ProfileListRow: View {
  let profile: DNSProfile
  let isActive: Bool

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: profile.dnsProtocol == .https ? "network.badge.shield.half.filled" : "lock.shield")
        .foregroundStyle(isActive ? Color.primary : Color.secondary)
        .frame(width: 20)

      VStack(alignment: .leading, spacing: 2) {
        Text(profile.name)
          .lineLimit(1)
        Text(profile.dnsProtocol.shortName)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()

      if profile.isBuiltIn {
        Image(systemName: "lock.fill")
          .font(.caption)
          .foregroundStyle(.tertiary)
      }
      if isActive {
        Circle()
          .fill(Color.green)
          .frame(width: 7, height: 7)
          .help("Selected Profile")
      }
    }
    .padding(.vertical, 3)
  }
}

private struct ProfileDetailView: View {
  @EnvironmentObject private var appModel: AppModel
  let profile: DNSProfile
  let deleteAction: () -> Void

  @State private var draft: DNSProfile
  @State private var serversText: String

  init(profile: DNSProfile, deleteAction: @escaping () -> Void) {
    self.profile = profile
    self.deleteAction = deleteAction
    _draft = State(initialValue: profile)
    _serversText = State(initialValue: profile.servers.joined(separator: ", "))
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        header

        if profile.isBuiltIn {
          builtInDetails
        } else {
          customEditor
        }
      }
      .padding(24)
      .frame(maxWidth: 680, alignment: .leading)
    }
  }

  private var header: some View {
    HStack(alignment: .top, spacing: 14) {
      Image(systemName: profile.dnsProtocol == .https ? "network.badge.shield.half.filled" : "lock.shield")
        .font(.system(size: 32))
        .foregroundStyle(Color.accentColor)
        .frame(width: 48, height: 48)
        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))

      VStack(alignment: .leading, spacing: 5) {
        HStack(spacing: 8) {
          Text(profile.name)
            .font(.title.bold())
            .lineLimit(1)
            .minimumScaleFactor(0.8)
          Text(profile.isBuiltIn ? "Built-in" : "Custom")
            .font(.caption.bold())
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(.quaternary, in: Capsule())
        }
        Text("\(profile.dnsProtocol.rawValue) · \(profile.endpointHost)")
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.middle)
      }

      Spacer()

      if appModel.selectedProfileID == profile.id {
        ViewThatFits(in: .horizontal) {
          Label("Selected", systemImage: "checkmark.circle.fill")
            .fixedSize()
          Image(systemName: "checkmark.circle.fill")
            .help("Selected")
        }
        .foregroundStyle(Color.accentColor)
      }
    }
  }

  private var builtInDetails: some View {
    VStack(alignment: .leading, spacing: 16) {
      Label("This built-in profile is read-only.", systemImage: "lock.fill")
        .font(.callout)
        .foregroundStyle(.secondary)

      GroupBox("Profile Details") {
        VStack(spacing: 12) {
          LabeledContent("Protocol") {
            Text(profile.dnsProtocol.rawValue)
              .lineLimit(1)
          }
          Divider()
          LabeledContent("Endpoint") {
            Text(profile.endpointLabel)
              .lineLimit(1)
              .truncationMode(.middle)
              .help(profile.endpointLabel)
          }
          Divider()
          LabeledContent("Bootstrap Servers") {
            Text(bootstrapServersLabel)
              .lineLimit(1)
              .truncationMode(.middle)
              .help(bootstrapServersLabel)
          }
        }
        .textSelection(.enabled)
        .padding(8)
      }

      Button("Use This Profile") {
        appModel.selectProfile(id: profile.id)
      }
      .buttonStyle(.borderedProminent)
      .disabled(
        appModel.selectedProfileID == profile.id
          || appModel.isBusy
          || appModel.isRefreshingSystemStatus
      )
    }
  }

  private var bootstrapServersLabel: String {
    profile.servers.isEmpty
      ? String(localized: "Automatic")
      : profile.servers.joined(separator: ", ")
  }

  private var customEditor: some View {
    VStack(alignment: .leading, spacing: 18) {
      GroupBox("Profile Details") {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 12) {
          GridRow {
            Text("Name")
              .foregroundStyle(.secondary)
            TextField("Name", text: $draft.name)
          }
          GridRow {
            Text("Protocol")
              .foregroundStyle(.secondary)
            Picker("Protocol", selection: $draft.dnsProtocol) {
              ForEach(DNSProtocol.allCases) { dnsProtocol in
                Text(dnsProtocol.rawValue).tag(dnsProtocol)
              }
            }
            .labelsHidden()
            .onChange(of: draft.dnsProtocol) { _, dnsProtocol in
              updateEndpointPlaceholder(for: dnsProtocol)
            }
          }
          GridRow {
            Text(endpointTitle)
              .foregroundStyle(.secondary)
            TextField(endpointTitle, text: $draft.endpoint)
          }
          GridRow {
            Text("Bootstrap Servers")
              .foregroundStyle(.secondary)
            TextField("Bootstrap Servers", text: $serversText)
          }
        }
        .padding(8)
      }

      Text(protocolHelp)
        .font(.caption)
        .foregroundStyle(.secondary)

      HStack(spacing: 10) {
        Button(hasChanges ? "Save & Use Profile" : "Use This Profile") {
          save(useAfterSaving: true)
        }
        .buttonStyle(.borderedProminent)
        .disabled(appModel.isBusy || appModel.isRefreshingSystemStatus)

        Button("Save Changes") {
          save(useAfterSaving: false)
        }
        .disabled(
          !hasChanges || appModel.isBusy || appModel.isRefreshingSystemStatus
        )

        Button("Revert Changes") {
          draft = profile
          serversText = profile.servers.joined(separator: ", ")
        }
        .disabled(!hasChanges || appModel.isBusy || appModel.isRefreshingSystemStatus)

        Spacer(minLength: 0)
      }

      Divider()

      HStack {
        Spacer()
        Button("Delete Profile", role: .destructive, action: deleteAction)
          .disabled(appModel.isBusy || appModel.isRefreshingSystemStatus)
      }
    }
  }

  private var candidate: DNSProfile {
    var candidate = draft
    candidate.servers = serversText
      .split(separator: ",")
      .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
    return candidate
  }

  private var hasChanges: Bool {
    candidate != profile
  }

  private var endpointTitle: LocalizedStringKey {
    draft.dnsProtocol == .https ? "HTTPS Endpoint URL" : "TLS Server Name"
  }

  private var protocolHelp: LocalizedStringKey {
    draft.dnsProtocol == .https
      ? "DNS over HTTPS requires an https:// endpoint URL. Bootstrap servers are optional."
      : "DNS over TLS requires a certificate server name and at least one bootstrap server."
  }

  private func updateEndpointPlaceholder(for dnsProtocol: DNSProtocol) {
    let endpoint = draft.endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
    switch dnsProtocol {
    case .https where endpoint.isEmpty:
      draft.endpoint = "https://"
    case .tls where endpoint == "https://":
      draft.endpoint = ""
    default:
      break
    }
  }

  private func save(useAfterSaving: Bool) {
    let candidate = candidate
    if hasChanges, !appModel.saveProfile(candidate) {
      return
    }
    draft = candidate
    serversText = candidate.servers.joined(separator: ", ")
    if useAfterSaving, appModel.selectedProfileID != candidate.id {
      appModel.selectProfile(id: candidate.id)
    }
  }
}
