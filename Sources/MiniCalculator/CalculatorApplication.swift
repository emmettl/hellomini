import AppKit
import MiniCore
import MiniUI
import SwiftUI

@MainActor public final class CalculatorApplication: MiniApplication {
  public let id = "calculator"
  public let name = "Desk Calculator"
  public let icon = MiniApplicationIcon.calculator
  public let defaultSize = CGSize(width: 700, height: 480)
  public let minimumSize = CGSize(width: 440, height: 250)
  public static let effect = MiniPlayfulEffect(
    id: "calculator.mathematics", name: "Unreasonable mathematics",
    description: "Allow the calculator's animated Mandelbrot excursion.")
  private let calculation: CalculatorModel
  private let sendToScrapbook: @MainActor (String) async throws -> Void
  private let playfulness: PlayfulnessSettings
  public init(
    playfulness: PlayfulnessSettings, defaults: UserDefaults = .standard,
    sendToScrapbook: @escaping @MainActor (String) async throws -> Void = { _ in
      throw NSError(
        domain: "HelloMini.Calculator", code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Scrapbook is unavailable in this host."])
    }
  ) {
    self.playfulness = playfulness
    calculation = CalculatorModel(defaults: defaults)
    self.sendToScrapbook = sendToScrapbook
  }
  public func content() -> AnyView {
    AnyView(
      CalculatorView(
        playfulness: playfulness, calculation: calculation, sendToScrapbook: sendToScrapbook))
  }
}
