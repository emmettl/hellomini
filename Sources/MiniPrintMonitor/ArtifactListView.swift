import AppKit
import MiniBuildCore
import MiniUI
import Observation
import SwiftUI

@MainActor @Observable final class ArtifactListModel {
  let build: ProjectBuild
  var artifacts: [BuildArtifact] = []
  var busy = false
  var more = false
  var page = 0
  var error: String?
  var notice =
    "Choose an artifact, then a new ZIP destination. Downloads are not opened or extracted."
  var written: Int64 = 0
  var expected: Int64?
  @ObservationIgnored var request: Task<Void, Never>?
  @ObservationIgnored var downloader: ArtifactDownload?
  init(build: ProjectBuild) { self.build = build }
  func load() async {
    guard !busy, page < 5 else { return }
    busy = true
    defer { busy = false }
    do {
      let project = build.project
      let result = try await project.provider().artifacts(
        project: project.path, runID: build.run.id, page: page + 1,
        token: CIToken.read(project.account))
      try Task.checkCancellation()
      var seen = Set<Int>()
      artifacts = (artifacts + result.artifacts).filter { seen.insert($0.id).inserted }
      page += 1
      more = result.hasMore
      error = nil
    } catch { if !Task.isCancelled { self.error = error.localizedDescription } }
  }
  func download(_ artifact: BuildArtifact) {
    guard !busy, !artifact.expired else { return }
    guard artifact.size.map({ $0 <= ArtifactDownload.maximumBytes }) ?? true else {
      error = "Artifact exceeds the 512 MB limit."
      return
    }
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.zip]
    panel.nameFieldStringValue = "Artifact-\(artifact.id).zip"
    panel.message =
      "Save \(artifact.name) from \(build.project.label), run #\(build.run.id). Choose a new filename; existing files are never replaced. Archives are not extracted."
    guard panel.runModal() == .OK, let url = panel.url else { return }
    guard !FileManager.default.fileExists(atPath: url.path) else {
      error = "Choose a new filename; existing files are kept."
      return
    }
    busy = true
    written = 0
    expected = artifact.size
    error = nil
    let download = ArtifactDownload()
    downloader = download
    request = Task {
      defer {
        busy = false
        downloader = nil
      }
      do {
        let project = build.project
        let request = try project.provider().artifactRequest(
          project: project.path, artifactID: artifact.id, token: CIToken.read(project.account))
        try await download.download(request, to: url) { [weak self = self] written, expected in
          Task { @MainActor [weak self = self] in
            self?.written = written
            self?.expected = expected
          }
        }
        notice =
          "Saved \(artifact.name). Keep normal macOS security checks when opening its contents."
      } catch {
        self.error =
          Task.isCancelled
          ? "Download cancelled. No destination file was created." : error.localizedDescription
      }
    }
  }
  func cancel() {
    request?.cancel()
    downloader?.cancel()
  }
}
struct ArtifactListView: View {
  @Environment(\.miniTheme) private var theme
  @Environment(\.dismiss) private var dismiss
  @State private var model: ArtifactListModel
  init(build: ProjectBuild) { _model = State(initialValue: ArtifactListModel(build: build)) }
  init(model: ArtifactListModel) { _model = State(initialValue: model) }
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Build Artifacts · #\(model.build.run.id)").font(theme.typography.title)
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 10) {
          ForEach(model.artifacts) { artifact in
            VStack(alignment: .leading, spacing: 4) {
              Text(artifact.name).textSelection(.enabled)
              HStack {
                Text(
                  artifact.expired
                    ? "Expired"
                    : artifact.size.map {
                      ByteCountFormatter.string(fromByteCount: $0, countStyle: .file)
                    } ?? "Size unknown"
                ).font(theme.typography.small)
                Spacer()
                Button("Download…") { model.download(artifact) }.disabled(
                  model.busy || artifact.expired)
              }
            }
            Divider()
          }
          if model.artifacts.isEmpty {
            Text(
              model.busy
                ? "Checking artifacts…" : "No downloadable artifacts reported for this run.")
          }
        }
      }.frame(height: 150)
      if model.busy && model.downloader != nil {
        Text(
          "\(ByteCountFormatter.string(fromByteCount: model.written, countStyle: .file))"
            + (model.expected.map {
              " / " + ByteCountFormatter.string(fromByteCount: $0, countStyle: .file)
            } ?? " received"))
      }
      Text(model.error ?? model.notice).font(theme.typography.small).textSelection(.enabled)
      HStack {
        if model.error != nil {
          Button("Retry List") { model.request = Task { await model.load() } }.disabled(model.busy)
        }
        if model.more && model.page < 5 {
          Button("More") { model.request = Task { await model.load() } }.disabled(model.busy)
        }
        if model.busy { Button("Cancel", action: model.cancel) }
        Spacer()
        Button("Done") {
          model.cancel()
          dismiss()
        }.keyboardShortcut(.cancelAction).miniControlBounds("artifacts.done")
      }
    }.padding(12).frame(width: 480).foregroundStyle(theme.ink).background(theme.paper).buttonStyle(
      RetroButtonStyle()
    )
    .onAppear { model.request = Task { await model.load() } }.onDisappear { model.cancel() }
  }
}
