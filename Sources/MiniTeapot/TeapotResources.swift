import Foundation
import MiniCore

extension Bundle {
  static let teapotResources = MiniResourceBundle.resolve(
    named: "HelloMini_MiniTeapot", developmentBundle: .module)
}
