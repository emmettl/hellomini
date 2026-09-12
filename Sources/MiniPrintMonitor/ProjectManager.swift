import MiniUI
import SwiftUI

struct ProjectManager: View {
  @Environment(\.miniTheme) private var theme
  @Environment(\.dismiss) private var dismiss
  let model: ProjectQueue
  let added: () -> Void
  @State private var service = CIService.github
  @State private var path = ""
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
      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          ForEach(model.projects) { project in
            HStack {
              VStack(alignment: .leading, spacing: 3) {
                Text(project.path).font(theme.typography.title).lineLimit(1).help(project.path)
                Text(project.service.rawValue).font(theme.typography.small)
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
      }.frame(height: 190)
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
      ProjectTokenEditor(project: project).environment(\.miniTheme, theme)
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
      try model.add(service: service, path: path)
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
      Text("Token for \(project.account)").font(theme.typography.title)
      Text(
        "Optional for public projects. Use Actions read access on GitHub or read_api access on GitLab. Stored in this Mac's Keychain."
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
