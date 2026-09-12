import Foundation

public struct BuildStep: Identifiable, Sendable {
  public let id: Int
  public let name: String
  public let state: BuildState
  public init(id: Int, name: String, state: BuildState) {
    self.id = id
    self.name = name
    self.state = state
  }
}

public struct BuildJob: Identifiable, Sendable {
  public let id: Int
  public let name: String
  public let state: BuildState
  public let url: URL
  public let stage: String?
  public let startedAt: Date?
  public let finishedAt: Date?
  public let failure: String?
  public let allowsFailure: Bool
  public let steps: [BuildStep]
  public init(
    id: Int, name: String, state: BuildState, url: URL, stage: String? = nil,
    startedAt: Date? = nil, finishedAt: Date? = nil, failure: String? = nil,
    allowsFailure: Bool = false, steps: [BuildStep] = []
  ) {
    self.id = id
    self.name = name
    self.state = state
    self.url = url
    self.stage = stage
    self.startedAt = startedAt
    self.finishedAt = finishedAt
    self.failure = failure
    self.allowsFailure = allowsFailure
    self.steps = steps
  }
  public var duration: TimeInterval? {
    guard let startedAt, let finishedAt, finishedAt >= startedAt else { return nil }
    return finishedAt.timeIntervalSince(startedAt)
  }
}

public struct BuildJobPage: Sendable {
  public static let pageSize = 100
  public static let maximumPage = 5
  public let jobs: [BuildJob]
  public let hasMore: Bool
  public init(jobs: [BuildJob], hasMore: Bool) {
    self.jobs = jobs
    self.hasMore = hasMore
  }
  public static func validate(runID: Int, page: Int) throws {
    guard runID > 0, (1...maximumPage).contains(page) else {
      throw BuildServiceError("Invalid build or job page.")
    }
  }
}
