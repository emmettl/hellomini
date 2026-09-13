import MiniCore
import MiniUI
import SwiftUI

struct DesktopStatusStrip: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.miniTheme) private var theme
  let model: DesktopModel
  let playfulness: PlayfulnessSettings?
  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      HStack(spacing: 8) {
        ForEach(model.applications.filter { $0.status != nil }, id: \.id) { app in
          if let status = app.status {
            Button {
              model.launch(app)
            } label: {
              Image(systemName: status.symbol)
                .overlay(alignment: .topTrailing) {
                  if status.attention {
                    Circle().fill(theme.ink).frame(width: 5, height: 5).offset(x: 3, y: -2)
                  }
                }
                .opacity(
                  app.id == "alarm-clock" && status.attention && !reduceMotion
                    && playfulness?.enabled == true
                    && Int(context.date.timeIntervalSince1970) % 2 == 0 ? 0.35 : 1)
            }.buttonStyle(.plain).miniHelp(status.message)
              .accessibilityLabel(app.name + ": " + status.message)
          }
        }
        Image(systemName: thermalSymbol).miniHelp("Thermal state: " + thermalLabel)
          .accessibilityLabel("Thermal state: " + thermalLabel)
      }.font(.system(size: 12)).padding(.leading, 8)
    }
  }
  private var thermalSymbol: String {
    switch ProcessInfo.processInfo.thermalState {
    case .nominal: "thermometer.low"
    case .fair: "thermometer.medium"
    case .serious, .critical: "thermometer.high"
    @unknown default: "thermometer.medium"
    }
  }
  private var thermalLabel: String {
    switch ProcessInfo.processInfo.thermalState {
    case .nominal: "Nominal"
    case .fair: "Fair"
    case .serious: "Serious"
    case .critical: "Critical"
    @unknown default: "Unknown"
    }
  }
}
