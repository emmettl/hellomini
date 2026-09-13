import MiniUI
import SwiftUI

struct ProjectManager: View {
  @Environment(\.miniTheme) private var theme
  @Environment(\.miniDisplay) private var display
  @Environment(\.dismiss) private var dismiss
  let model: ProjectQueue
  let added: () -> Void
  @State private var service = CIService.github
  @State private var path = ""
  @State private var customServer = false
  @State private var serverAddress = ""
  @State private var error: String?
  @State private var tokenProject: CIProject?
  @State private var removing: CIProject?

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("The printer's address book").font(theme.typography.display(21))
      HStack {
        Picker("Provider", selection: $service) {
          ForEach(CIService.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }.labelsHidden().frame(width: 110)
        TextField("owner/project", text: $path).accessibilityLabel("CI project path")
          .onSubmit(add)
        Button("Add", action: add).disabled(model.busy || model.storageError != nil)
      }
      Toggle("Self-hosted server", isOn: $customServer).font(theme.typography.small)
      if customServer {
        TextField("https://ci.example.com", text: $serverAddress)
          .accessibilityLabel("CI server website address")
        Text(
          "HTTPS website address; omit API paths. GitHub Enterprise Server or GitLab Self-Managed."
        )
        .font(theme.typography.small)
      }
      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          ForEach(model.projects) { project in
            HStack {
              VStack(alignment: .leading, spacing: 3) {
                Text(project.path).font(theme.typography.title).lineLimit(1).miniHelp(project.path)
                Text(project.service.rawValue + " · " + project.serverAddress).font(
                  theme.typography.small
                ).lineLimit(1).miniHelp(project.serverAddress)
              }
              Spacer()
              Button("Token…") { tokenProject = project }.disabled(model.busy)
                .accessibilityLabel("Token for " + project.account)
              Button("Remove") { removing = project }.disabled(model.busy)
                .accessibilityLabel("Remove " + project.account)
            }
            Rectangle().frame(height: 1)
          }
          if model.projects.isEmpty { Text("No projects saved yet.").font(theme.typography.small) }
        }
      }.frame(height: display.tinyScreen ? min(190, display.logicalSize.height * 0.3) : 190)
      Text(
        "Up to 12 projects. Removing a project keeps its Keychain token; use Token… to forget it first."
      )
      .font(theme.typography.small).fixedSize(horizontal: false, vertical: true)
      if let error = model.storageError ?? error {
        Text(error).font(theme.typography.small).fixedSize(horizontal: false, vertical: true)
      }
      HStack {
        if model.busy { Text("Refreshing projects…").font(theme.typography.small) }
        Spacer()
        Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
      }
    }
    .buttonStyle(RetroButtonStyle()).padding(20).frame(width: 550)
    .foregroundStyle(theme.ink).background(theme.paper)
    .sheet(item: $tokenProject) { project in
      ProjectTokenEditor(project: project).environment(\.miniTheme, theme).miniSheet(width: 470)
    }
    .confirmationDialog(
      "Remove \(removing?.account ?? "project") from Print Monitor?",
      isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }),
      titleVisibility: .visible
    ) {
      Button("Remove project") {
        guard let project = removing else { return }
        do {
          try model.remove(project)
          error = nil
        } catch { self.error = error.localizedDescription }
        removing = nil
      }
    }
  }
  private func add() {
    do {
      try model.add(service: service, path: path, server: customServer ? serverAddress : nil)
      path = ""
      error = nil
      added()
    } catch { self.error = error.localizedDescription }
  }
}

private struct ProjectTokenEditor: View {
  @Environment(\.miniTheme) private var theme
  @Environment(\.dismiss) private var dismiss
  let project: CIProject
  @State private var token = ""
  @State private var error: String?
  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("Token for \(project.path)").font(theme.typography.title)
      Text("Server: " + project.serverAddress).font(theme.typography.small).textSelection(
        .enabled)
      Text(
        "Optional for public projects. Reading needs Actions read access on GitHub or read_api on GitLab. Clear jam needs Actions write access on GitHub, or api scope and pipeline retry permission on GitLab. Stored in this Mac's Keychain."
      )
      .font(theme.typography.small)
      SecureField("Token", text: $token)
      HStack {
        Button("Save token") { update { try CIToken.save(token, account: project.account) } }
          .disabled(token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        Button("Forget token") { update { try CIToken.forget(project.account) } }
        Spacer()
        Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
      }.buttonStyle(RetroButtonStyle())
      if let error { Text(error).font(theme.typography.small) }
    }.padding(20).frame(width: 470).foregroundStyle(theme.ink).background(theme.paper)
      .onDisappear { token = "" }
  }
  private func update(_ action: () throws -> Void) {
    do {
      try action()
      token = ""
      dismiss()
    } catch { self.error = error.localizedDescription }
  }
}
