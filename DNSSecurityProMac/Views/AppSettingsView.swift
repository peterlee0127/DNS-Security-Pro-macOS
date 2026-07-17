import SwiftUI

struct AppSettingsView: View {
  @AppStorage(AppPreferenceKey.showsMenuBarExtra) private var showsMenuBarExtra = true
  @AppStorage(AppPreferenceKey.quitsAfterApplyingDNS) private var quitsAfterApplyingDNS = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        VStack(alignment: .leading, spacing: 4) {
          Text("Settings")
            .font(.largeTitle.bold())
          Text("Choose what DNS Security Pro does after you apply a DNS change.")
            .foregroundStyle(.secondary)
        }

        PreferenceCard(
          systemImage: "menubar.rectangle",
          title: "Menu Bar",
          message: "Keep quick DNS controls available after closing the main window."
        ) {
          Toggle("Show DNS Security Pro in the menu bar", isOn: $showsMenuBarExtra)
        }

        PreferenceCard(
          systemImage: "power",
          title: "App Behavior",
          message: "The installed DNS profile remains active after the app quits."
        ) {
          Toggle("Quit after applying DNS changes", isOn: $quitsAfterApplyingDNS)
        }

        Label(
          "You can always reopen the app to change or disable the installed profile.",
          systemImage: "info.circle"
        )
        .font(.callout)
        .foregroundStyle(.secondary)
      }
      .padding(24)
      .frame(maxWidth: 660, alignment: .leading)
    }
    .frame(minWidth: 520, minHeight: 350)
    .navigationTitle("Settings")
  }
}

private struct PreferenceCard<Control: View>: View {
  let systemImage: String
  let title: LocalizedStringKey
  let message: LocalizedStringKey
  @ViewBuilder let control: () -> Control

  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      Image(systemName: systemImage)
        .font(.title2)
        .foregroundStyle(Color.accentColor)
        .frame(width: 38, height: 38)
        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))

      VStack(alignment: .leading, spacing: 7) {
        Text(title)
          .font(.headline)
        control()
        Text(message)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
    }
    .padding(16)
    .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
  }
}
