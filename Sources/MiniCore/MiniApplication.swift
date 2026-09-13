import AppKit
import SwiftUI

/// An in-process application supplies content and commands. The desktop owns its window and focus.
@MainActor public protocol MiniApplication: AnyObject {
  var id: String { get }
  var name: String { get }
  var icon: MiniApplicationIcon { get }
  var defaultSize: CGSize { get }
  var minimumSize: CGSize { get }
  var title: String { get }
  var menus: [RetroMenu] { get }
  func content() -> AnyView
}

extension MiniApplication {
  public var minimumSize: CGSize { defaultSize }
  public var title: String { name }
  public var menus: [RetroMenu] { [] }
}

public enum MiniApplicationIcon {
  case folder, computer, activity, clock, settings, teapot, aquarium, scrapbook, calculator, puzzle,
    disk, chooser, wastebasket, printer
}

public struct RetroShortcut {
  public let key: String
  public let modifiers: NSEvent.ModifierFlags
  public let label: String

  public init(key: String, modifiers: NSEvent.ModifierFlags = .command, label: String) {
    self.key = key
    self.modifiers = modifiers
    self.label = label
  }

  public func matches(_ event: NSEvent) -> Bool {
    event.characters(byApplyingModifiers: [])?.lowercased() == key
      && event.modifierFlags.intersection([.command, .shift, .control, .option]) == modifiers
  }
}

public struct RetroMenuItem: Identifiable {
  public let id: String
  public let title: String
  public let shortcut: RetroShortcut?
  public let enabled: Bool
  public let checked: Bool
  public let action: (@MainActor () -> Void)?

  public init(
    id: String, title: String = "", shortcut: RetroShortcut? = nil, enabled: Bool = true,
    checked: Bool = false, action: (@MainActor () -> Void)? = nil
  ) {
    self.id = id
    self.title = title
    self.shortcut = shortcut
    self.enabled = enabled
    self.checked = checked
    self.action = action
  }

  public static func separator(_ id: String) -> Self { Self(id: id, enabled: false) }
  public var isSeparator: Bool { action == nil }
}

public struct RetroMenu: Identifiable {
  public let id: String
  public let title: String
  public let width: CGFloat
  public var items: [RetroMenuItem]

  public init(id: String, title: String, width: CGFloat = 270, items: [RetroMenuItem]) {
    self.id = id
    self.title = title
    self.width = width
    self.items = items
  }
}
