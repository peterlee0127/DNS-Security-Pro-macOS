import SwiftUI

struct AboutView: View {
  // swiftlint:disable force_unwrapping
  private let websiteURL = URL(string: "https://dns-security.peterlee.app/dohdot")!
  private let mobileAppURL = URL(string: "https://apps.apple.com/app/id1533938029")!
  // swiftlint:enable force_unwrapping

  var body: some View {
    ScrollView {
      VStack(spacing: 22) {
        Image(systemName: "lock.shield.fill")
          .font(.system(size: 76))
          .foregroundStyle(Color.accentColor)
          .padding(.top, 36)

        VStack(spacing: 6) {
          Text("DNS Security Pro")
            .font(.largeTitle.bold())
          Text("Native macOS Edition")
            .font(.title3)
            .foregroundStyle(.secondary)
        }

        Text("A focused, native SwiftUI app for switching system-wide encrypted DNS profiles on macOS. No Mac Catalyst or embedded iOS interface.")
          .multilineTextAlignment(.center)
          .foregroundStyle(.secondary)
          .frame(maxWidth: 540)

        GroupBox {
          VStack(alignment: .leading, spacing: 14) {
            Label("Native SwiftUI and AppKit lifecycle", systemImage: "macwindow")
            Label("System DNS configuration through NetworkExtension", systemImage: "network")
            Label("Built-in and custom DoH / DoT profiles", systemImage: "server.rack")
            Label("Local profile storage with no account required", systemImage: "externaldrive")
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(8)
        }
        .frame(maxWidth: 600)

        HStack(spacing: 12) {
          Link(destination: mobileAppURL) {
            Label("Get the iPhone and iPad app", systemImage: "iphone")
          }
          .buttonStyle(.borderedProminent)

          Link(destination: websiteURL) {
            Label("Learn about encrypted DNS", systemImage: "safari")
          }
          .buttonStyle(.bordered)
        }

        Text(versionText)
          .font(.caption)
          .foregroundStyle(.tertiary)
          .padding(.top, 8)
      }
      .padding(32)
      .frame(maxWidth: .infinity)
    }
    .navigationTitle("About")
  }

  private var versionText: String {
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    return String(format: String(localized: "Version %@ (%@)"), version, build)
  }
}
