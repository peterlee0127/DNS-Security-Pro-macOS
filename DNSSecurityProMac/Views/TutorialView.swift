import SwiftUI

struct TutorialView: View {
  @EnvironmentObject private var appModel: AppModel

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        VStack(alignment: .leading, spacing: 5) {
          Text("Set Up Encrypted DNS")
            .font(.largeTitle.bold())
          Text("Choose a profile, connect, and approve the configuration the first time.")
            .foregroundStyle(.secondary)
        }

        VStack(spacing: 12) {
          TutorialStepCard(
            number: 1,
            systemImage: "server.rack",
            title: "Choose a DNS profile",
            message: "Choose a built-in resolver on Dashboard, or add your own DoH or DoT profile in DNS Profiles."
          )

          TutorialStepCard(
            number: 2,
            systemImage: "bolt.shield",
            title: "Connect encrypted DNS",
            message: "Choose Connect on Dashboard. DNS Security Pro installs the selected encrypted DNS configuration."
          )

          TutorialStepCard(
            number: 3,
            systemImage: "lock.shield",
            title: "Approve macOS",
            message: "In System Settings, open Network → VPN & Filters → DNS Security Pro, then approve the DNS configuration.",
            actionTitle: "Open Network Settings",
            action: { appModel.openNetworkSettings() }
          )

          TutorialStepCard(
            number: 4,
            systemImage: "waveform.path.ecg",
            title: "Verify the resolver",
            message: "Return to Dashboard and choose Test Resolver to send an encrypted DNS query and measure its latency."
          )
        }

        HStack(alignment: .top, spacing: 12) {
          Image(systemName: "info.circle.fill")
            .foregroundStyle(Color.accentColor)
          VStack(alignment: .leading, spacing: 4) {
            Text("Good to know")
              .font(.headline)
            Text("Closing DNS Security Pro does not disable an installed profile. Choose Disconnect on Dashboard when you want to return to the system DNS.")
              .font(.callout)
              .foregroundStyle(.secondary)
          }
        }
        .padding(15)
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
      }
      .padding(24)
      .frame(maxWidth: 720, alignment: .leading)
    }
    .frame(minWidth: 560, minHeight: 440)
    .navigationTitle("Tutorial")
  }
}

private struct TutorialStepCard: View {
  let number: Int
  let systemImage: String
  let title: LocalizedStringKey
  let message: LocalizedStringKey
  var actionTitle: LocalizedStringKey?
  var action: (() -> Void)?

  init(
    number: Int,
    systemImage: String,
    title: LocalizedStringKey,
    message: LocalizedStringKey,
    actionTitle: LocalizedStringKey? = nil,
    action: (() -> Void)? = nil
  ) {
    self.number = number
    self.systemImage = systemImage
    self.title = title
    self.message = message
    self.actionTitle = actionTitle
    self.action = action
  }

  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      ZStack {
        Circle()
          .fill(Color.accentColor)
        Text(number.formatted())
          .font(.headline)
          .foregroundStyle(.white)
      }
      .frame(width: 32, height: 32)
      .accessibilityHidden(true)

      Image(systemName: systemImage)
        .font(.title2)
        .foregroundStyle(Color.accentColor)
        .frame(width: 30, height: 32)

      VStack(alignment: .leading, spacing: 6) {
        Text(title)
          .font(.headline)
        Text(message)
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        if let actionTitle, let action {
          Button(actionTitle, action: action)
            .controlSize(.small)
            .padding(.top, 2)
        }
      }

      Spacer(minLength: 0)
    }
    .padding(15)
    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
  }
}
