import Foundation
import MiniBuildCore
import Security

enum CIToken {
  static func query(_ account: String) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "HelloMini.CI",
      kSecAttrAccount as String: account,
    ]
  }
  static func read(_ account: String) throws -> String? {
    var query = query(account)
    query[kSecReturnData as String] = true
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess, let data = item as? Data else {
      throw BuildServiceError("Could not read the CI token from Keychain (\(status)).")
    }
    return String(data: data, encoding: .utf8)
  }
  static func save(_ token: String, account: String) throws {
    let query = query(account)
    let value = [kSecValueData as String: Data(token.utf8)]
    var status = SecItemUpdate(query as CFDictionary, value as CFDictionary)
    if status == errSecItemNotFound {
      status = SecItemAdd(query.merging(value) { _, new in new } as CFDictionary, nil)
    }
    guard status == errSecSuccess else {
      throw BuildServiceError("Could not save the CI token to Keychain (\(status)).")
    }
  }
  static func forget(_ account: String) throws {
    let status = SecItemDelete(query(account) as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw BuildServiceError("Could not remove the token (\(status)).")
    }
  }
}
