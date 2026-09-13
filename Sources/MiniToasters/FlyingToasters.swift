import MiniCore
import MiniScreensaver
import MiniUI
import SwiftUI

public enum FlyingToasters {
  public static let metadata = MiniScreensaver(
    id: "flying-toasters", name: "Flying Toasters",
    description: "Winged kitchen appliances on a very important journey.")
  public static let effect = MiniPlayfulEffect(
    id: "toasters.flight", name: "Flying toaster animation",
    description: "Let the toasters flap their wings and accompany the toast.")
  @MainActor public static func definition(playfulness: PlayfulnessSettings)
    -> MiniScreensaverDefinition
  {
    MiniScreensaverDefinition(metadata: metadata) {
      AnyView(MiniMetalScene(.toasters, animate: playfulness.allows(effect.id)))
    }
  }
}
