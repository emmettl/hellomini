public enum DesktopEffects {
  public static let physicalWindows = MiniPlayfulEffect(
    id: "desktop.physical-windows", name: "Physical windows",
    description: "A little weight and spring when a dragged window settles.",
    enabledByDefault: false)

  public static let livingDither = MiniPlayfulEffect(
    id: "desktop.livingDither", name: "Living dither",
    description: "A slow field of ink dots ripples around desktop windows.", enabledByDefault: false
  )
  public static let genie = MiniPlayfulEffect(
    id: "desktop.genie", name: "Genie minimise",
    description: "Pour Aqua windows into the dock when they are minimised, and back out again.")
  public static let dockLaunchBounce = MiniPlayfulEffect(
    id: "desktop.dockLaunchBounce", name: "Dock launch bounce",
    description: "Give newly opened Aqua applications two little hops in the dock.")
  public static let menuBlink = MiniPlayfulEffect(
    id: "desktop.menuBlink", name: "Menu command blink",
    description: "Flash chosen System 7 commands three times before closing the menu.")
  public static let dockMagnification = MiniPlayfulEffect(
    id: "desktop.dockMagnification", name: "Dock magnification",
    description: "Enlarge Aqua dock icons as the pointer passes over them.")
}
