import SwiftUI
import UniformTypeIdentifiers

struct ProfilesView: View {
  @EnvironmentObject private var appModel: AppModel
  @State private var selectedProfileID: String?
  @State private var profileEditor: DNSProfile?
  @State private var profilePendingDeletion: DNSProfile?
  @State private var searchText = ""
  @State private var isImporting = false
  @State private var isExporting = false
  @State private var exportDocument = DNSProfilesDocument(profiles: [])
  @State private var transferError: String?

  private var selectedProfile: DNSProfile? {
    guard let selectedProfileID else { return nil }
    return appModel.profiles.first { $0.id == selectedProfileID }
  }

  var body: some View {
    List(selection: $selectedProfileID) {
      profileSection(
        title: "Built-in Profiles",
        profiles: matchingProfiles.filter(\.isBuiltIn)
      )

      profileSection(
        title: "Custom Profiles",
        profiles: matchingProfiles.filter { !$0.isBuiltIn }
      )
    }
    .listStyle(.inset)
    .navigationTitle("DNS Profiles")
    .toolbar {
      ToolbarItemGroup {
        Button {
          profileEditor = .customTemplate
        } label: {
          Label("Add Profile", systemImage: "plus")
        }

        Button {
          if let selectedProfile, !selectedProfile.isBuiltIn {
            profileEditor = selectedProfile
          }
        } label: {
          Label("Edit DNS Profile", systemImage: "pencil")
        }
        .disabled(
          selectedProfile?.isBuiltIn != false
            || appModel.isBusy
            || appModel.isRefreshingSystemStatus
        )

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

        Menu {
          Button {
            if let selectedProfile {
              profileEditor = duplicate(selectedProfile)
            }
          } label: {
            Label("Duplicate Selected Profile", systemImage: "doc.on.doc")
          }
          .disabled(selectedProfile == nil)

          Divider()

          Button {
            isImporting = true
          } label: {
            Label("Import Profiles…", systemImage: "square.and.arrow.down")
          }

          Button {
            exportDocument = DNSProfilesDocument(profiles: appModel.customProfiles)
            isExporting = true
          } label: {
            Label("Export Custom Profiles…", systemImage: "square.and.arrow.up")
          }
          .disabled(appModel.customProfiles.isEmpty)
        } label: {
          Label("Profile Transfer", systemImage: "ellipsis.circle")
        }
      }
    }
    .searchable(text: $searchText, prompt: "Search profiles")
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
    .sheet(item: $profileEditor) { profile in
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
    .fileImporter(
      isPresented: $isImporting,
      allowedContentTypes: [.json],
      allowsMultipleSelection: false
    ) { result in
      importProfiles(result)
    }
    .fileExporter(
      isPresented: $isExporting,
      document: exportDocument,
      contentType: .json,
      defaultFilename: "DNS Security Pro Profiles"
    ) { result in
      if case .failure(let error) = result {
        transferError = error.localizedDescription
      }
    }
    .alert(
      "Profile Transfer Failed",
      isPresented: Binding(
        get: { transferError != nil },
        set: { if !$0 { transferError = nil } }
      )
    ) {
      Button("OK") {
        transferError = nil
      }
    } message: {
      Text(transferError ?? "")
    }
  }

  private var matchingProfiles: [DNSProfile] {
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else { return appModel.profiles }
    return appModel.profiles.filter { profile in
      profile.name.localizedCaseInsensitiveContains(query)
        || profile.endpointLabel.localizedCaseInsensitiveContains(query)
        || profile.dnsProtocol.rawValue.localizedCaseInsensitiveContains(query)
        || profile.profileTraits.contains {
          $0.title.localizedCaseInsensitiveContains(query)
        }
    }
  }

  @ViewBuilder
  private func profileSection(
    title: LocalizedStringKey,
    profiles: [DNSProfile]
  ) -> some View {
    Section(title) {
      if profiles.isEmpty {
        Text(searchText.isEmpty ? "No custom profiles yet." : "No matching profiles.")
          .foregroundStyle(.secondary)
      } else {
        ForEach(profiles) { profile in
          ProfileListRow(
            profile: profile,
            isActive: appModel.selectedProfileID == profile.id,
            isBusy: appModel.isBusy || appModel.isRefreshingSystemStatus,
            probeResult: appModel.probeResults[profile.id],
            isProbing: appModel.probingProfileIDs.contains(profile.id),
            useAction: {
              selectedProfileID = profile.id
              appModel.selectProfile(id: profile.id)
            }
          )
          .tag(profile.id)
          .contextMenu {
            Button("Use This Profile") {
              selectedProfileID = profile.id
              appModel.selectProfile(id: profile.id)
            }
            .disabled(
              appModel.selectedProfileID == profile.id
                || appModel.isBusy
                || appModel.isRefreshingSystemStatus
            )

            Button("Test Resolver") {
              appModel.probe(profile)
            }
            .disabled(appModel.probingProfileIDs.contains(profile.id))

            Button("Duplicate DNS Profile") {
              selectedProfileID = profile.id
              profileEditor = duplicate(profile)
            }

            if !profile.isBuiltIn {
              Button("Edit DNS Profile") {
                selectedProfileID = profile.id
                profileEditor = profile
              }
              .disabled(appModel.isBusy || appModel.isRefreshingSystemStatus)

              Divider()

              Button("Delete Profile", role: .destructive) {
                selectedProfileID = profile.id
                profilePendingDeletion = profile
              }
              .disabled(appModel.isBusy || appModel.isRefreshingSystemStatus)
            }
          }
        }
      }
    }
  }

  private func importProfiles(_ result: Result<[URL], Error>) {
    do {
      guard let url = try result.get().first else { return }
      let hasAccess = url.startAccessingSecurityScopedResource()
      defer {
        if hasAccess {
          url.stopAccessingSecurityScopedResource()
        }
      }
      let archive = try DNSProfileArchive.decode(Data(contentsOf: url))
      appModel.importProfiles(archive.profiles)
    } catch {
      transferError = error.localizedDescription
    }
  }

  private func duplicate(_ profile: DNSProfile) -> DNSProfile {
    var duplicate = profile.withID(UUID().uuidString)
    duplicate.name = String(
      format: String(localized: "%@ Copy"),
      profile.name
    )
    duplicate.isBuiltIn = false
    return duplicate
  }
}

private struct ProfileListRow: View {
  let profile: DNSProfile
  let isActive: Bool
  let isBusy: Bool
  let probeResult: DNSProbeResult?
  let isProbing: Bool
  let useAction: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      Image(
        systemName: profile.dnsProtocol == .https
          ? "network.badge.shield.half.filled"
          : "lock.shield"
      )
      .font(.title3)
      .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
      .frame(width: 28)

      VStack(alignment: .leading, spacing: 3) {
        Text(profile.name)
          .font(.headline)
          .lineLimit(1)

        Text("\(profile.dnsProtocol.shortName) · \(profile.endpointHost)")
          .font(.callout)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.middle)
          .help(profile.endpointLabel)

        if !profile.profileTraits.isEmpty {
          Text(profile.profileTraits.prefix(3).map(\.title).joined(separator: " · "))
            .font(.caption)
            .foregroundStyle(.tertiary)
            .lineLimit(1)
        }
      }

      Spacer(minLength: 12)

      if profile.isBuiltIn {
        Image(systemName: "lock.fill")
          .font(.caption)
          .foregroundStyle(.tertiary)
          .help("This built-in profile is read-only.")
      }

      if isProbing {
        ProgressView()
          .controlSize(.small)
      } else if let probeResult {
        Label {
          if let latency = probeResult.latencyMilliseconds {
            Text("\(latency) ms")
              .monospacedDigit()
          }
        } icon: {
          Image(
            systemName: probeResult.status == .reachable
              ? "checkmark.circle.fill"
              : "exclamationmark.triangle.fill"
          )
        }
        .font(.caption)
        .foregroundStyle(probeResult.status == .reachable ? .green : .orange)
        .help(probeResult.detail)
      }

      if isActive {
        Label("Selected", systemImage: "checkmark.circle.fill")
          .font(.callout)
          .foregroundStyle(Color.accentColor)
          .fixedSize()
      } else {
        Button(action: useAction) {
          ViewThatFits(in: .horizontal) {
            Label("Use This Profile", systemImage: "checkmark.circle")
              .fixedSize()
            Image(systemName: "checkmark.circle")
          }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(isBusy)
        .help("Use This Profile")
      }
    }
    .padding(.vertical, 6)
  }
}
