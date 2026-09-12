import Foundation

/// SwiftPM executables look beside the binary; signed macOS apps keep assets in Contents/Resources.
public enum MiniResourceBundle {
  public static func resolve(named name: String, developmentBundle: @autoclosure () -> Bundle)
    -> Bundle
  {
    if let url = Bundle.main.resourceURL?.appendingPathComponent(name + ".bundle"),
      let bundle = Bundle(url: url)
    {
      return bundle
    }
    return developmentBundle()
  }
}
