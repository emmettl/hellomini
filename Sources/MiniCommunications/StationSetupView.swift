import AppKit
import MiniUI
import SwiftUI

struct StationSetupView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.miniTheme) private var theme
  @Bindable var model: StationModel
  @State private var draft: StationConfiguration
  @State private var token = ""
  @State private var forgetToken = false
  @State private var error: String?
  @State private var editing: UUID?

  init(model: StationModel) {
    self.model = model
    _draft = State(initialValue: model.configuration)
    _editing = State(initialValue: model.configuration.channels.first?.id)
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Station Setup").font(theme.typography.title)
      TextField("Station name", text: $draft.name)
      TextField("Prometheus server URL", text: $draft.endpoint)
        .help(
          "Base URL, including any server subpath. HTTPS required except localhost. The app appends /api/v1/query and /api/v1/query_range."
        )
      SecureField("Bearer token — blank keeps saved token", text: $token)
      Toggle("Forget token for this server", isOn: $forgetToken)
        .onChange(of: forgetToken) { _, value in if value { token = "" } }
      Text(
        "Tokens stay in Keychain, bound to the exact server URL. Changing servers never transfers a saved token."
      )
      .font(theme.typography.small)
      HStack {
        Button("Motion Studies preset") {
          draft.channels = StationConfiguration.motionStudies.channels
          draft.name = StationConfiguration.motionStudies.name
          editing = draft.channels.first?.id
        }
        Button("Import…", action: importDraft)
        Button("Add channel") {
          let channel = StationChannel()
          draft.channels.append(channel)
          editing = channel.id
        }.disabled(draft.channels.count >= 8)
      }
      if !draft.channels.isEmpty {
        Picker("Channel", selection: $editing) {
          ForEach(draft.channels) { Text($0.name).tag(Optional($0.id)) }
        }
        if let index = draft.channels.firstIndex(where: { $0.id == editing }) {
          channelForm($draft.channels[index])
          Button("Remove this channel") {
            draft.channels.remove(at: index)
            editing = draft.channels.first?.id
          }
        }
      }
      Divider()
      Toggle("Connect when saved and resume on launch", isOn: $draft.connected)
      Toggle("Sound on loss and recovery", isOn: $draft.audibleAlerts)
      Text(
        "Sounds also respect System sounds and Extra silliness. The station polls every 30 seconds while Hello Mini runs, including with this accessory closed."
      )
      .font(theme.typography.small)
      if let error { Text(error).font(theme.typography.small).foregroundStyle(theme.accent) }
      HStack {
        Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
        Spacer()
        Button("Save station") {
          do {
            try model.save(draft, token: token, forgetToken: forgetToken)
            dismiss()
          } catch {
            self.error = (error as? StationError)?.message ?? "Station settings could not be saved."
          }
        }.keyboardShortcut(.defaultAction)
      }
    }.padding(16).font(theme.typography.body).foregroundStyle(theme.ink)
      .buttonStyle(RetroButtonStyle())
  }
  private func channelForm(_ channel: Binding<StationChannel>) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      TextField("Channel name / callsign", text: channel.name)
      TextField("PromQL query — exactly one series", text: channel.query, axis: .vertical)
        .lineLimit(2...4)
      TextField("Evidence timestamp query (optional)", text: channel.evidenceQuery, axis: .vertical)
        .lineLimit(1...3)
      Text(
        "Evidence query returns the original observation time as Unix seconds. A fresh query result alone may contain old source data."
      )
      .font(theme.typography.small)
      Picker("Reading", selection: channel.kind) {
        Text("Number").tag(ReadingKind.number)
        Text("Seconds").tag(ReadingKind.seconds)
        Text("State code").tag(ReadingKind.state)
      }
      if channel.wrappedValue.kind == .state {
        Text(
          "State codes: 0 healthy, 1 waiting, 2 degraded, 3 paused, 4 unknown. These are this dashboard’s convention, not an OpenTelemetry standard."
        ).font(theme.typography.small)
      } else {
        if channel.wrappedValue.kind == .number { TextField("Unit (optional)", text: channel.unit) }
        HStack {
          Text("Attention threshold")
          TextField("None", value: channel.threshold, format: .number)
        }
        Toggle("Below threshold is bad", isOn: channel.belowIsBad)
      }
      HStack {
        Text("Freshness limit (seconds)")
        TextField("180", value: channel.maxAge, format: .number)
      }
    }.padding(10).overlay(Rectangle().stroke(theme.ink.opacity(0.4), lineWidth: 1))
  }
  private func importDraft() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.json]
    panel.allowsMultipleSelection = false
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      guard
        try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]).isRegularFile == true,
        (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max) <= 64_000
      else { throw StationError("Choose a regular station JSON file up to 64 KB.") }
      let data = try Data(contentsOf: url)
      guard data.count <= 64_000 else { throw StationError("Station file is too large.") }
      var imported = try JSONDecoder().decode(StationConfiguration.self, from: data).validated()
      imported.connected = false
      draft = imported
      token = ""
      forgetToken = false
      editing = draft.channels.first?.id
      error = "Imported as a draft, disconnected. Review the server and queries before saving."
    } catch {
      self.error = (error as? StationError)?.message ?? "Invalid or unsupported station file."
    }
  }
}
