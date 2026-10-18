import Foundation

public struct BuildRunPage: Sendable {
  public let runs: [BuildRun]
  public let hasMore: Bool
  public init(runs: [BuildRun], hasMore: Bool) {
    self.runs = runs
    self.hasMore = hasMore
  }
  public static func validate(page: Int, branch: String) throws {
    guard (1...50).contains(page), branch.utf8.count <= 250 else {
      throw BuildServiceError("Use a branch up to 250 bytes and browse at most 50 pages.")
    }
  }
}
public struct BuildArtifact: Identifiable, Sendable {
  public let id: Int
  public let name: String
  public let size: Int64?
  public let expired: Bool
  public init(id: Int, name: String, size: Int64?, expired: Bool) {
    self.id = id
    self.name = name
    self.size = size
    self.expired = expired
  }
}
public struct BuildArtifactPage: Sendable {
  public let artifacts: [BuildArtifact]
  public let hasMore: Bool
  public init(artifacts: [BuildArtifact], hasMore: Bool) {
    self.artifacts = artifacts
    self.hasMore = hasMore
  }
}
extension BuildProvider {
  public func history(project: String, branch: String, page: Int, token: String?) async throws
    -> BuildRunPage
  {
    throw BuildServiceError("History is not supported by this provider.")
  }
  public func artifacts(project: String, runID: Int, page: Int, token: String?) async throws
    -> BuildArtifactPage
  {
    throw BuildServiceError("Artifacts are not supported by this provider.")
  }
  public func artifactRequest(project: String, artifactID: Int, token: String?) throws -> URLRequest
  {
    throw BuildServiceError("Artifact downloads are not supported by this provider.")
  }
}
