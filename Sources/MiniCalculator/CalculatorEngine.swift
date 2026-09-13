import Foundation

enum CalculationError: LocalizedError {
  case invalid(String)
  var errorDescription: String? {
    if case .invalid(let message) = self { return message }
    return nil
  }
}

indirect enum Expression: Sendable {
  case number(Double)
  case variable
  case unary(String, Expression)
  case binary(String, Expression, Expression)
  func value(x: Double = 0) throws -> Double {
    let result: Double
    switch self {
    case .number(let n): result = n
    case .variable: result = x
    case .unary(let op, let a):
      let v = try a.value(x: x)
      switch op {
      case "-": result = -v
      case "+": result = v
      case "sin": result = sin(v)
      case "cos": result = cos(v)
      case "tan": result = tan(v)
      case "sqrt": result = sqrt(v)
      case "abs": result = abs(v)
      case "log": result = log10(v)
      case "ln": result = log(v)
      default: throw CalculationError.invalid("Unknown function.")
      }
    case .binary(let op, let a, let b):
      let l = try a.value(x: x)
      let r = try b.value(x: x)
      switch op {
      case "+": result = l + r
      case "-": result = l - r
      case "*": result = l * r
      case "/": result = l / r
      case "%": result = l.truncatingRemainder(dividingBy: r)
      default: result = pow(l, r)
      }
    }
    guard result.isFinite else {
      throw CalculationError.invalid("The result is undefined or too large.")
    }
    return result
  }
  static func parse(_ text: String) throws -> Expression {
    var parser = ExpressionParser(text: text)
    let expression = try parser.expression()
    parser.spaces()
    guard parser.index == parser.characters.count else {
      throw CalculationError.invalid("Unexpected text after the expression.")
    }
    return expression
  }
}

private struct ExpressionParser {
  let characters: [Character]
  var index = 0
  init(text: String) { characters = Array(text) }
  mutating func spaces() {
    while index < characters.count && characters[index].isWhitespace { index += 1 }
  }
  mutating func expression(_ minimum: Int = 0, depth: Int = 0) throws -> Expression {
    guard characters.count <= 512, depth < 48 else {
      throw CalculationError.invalid("Use a shorter expression.")
    }
    spaces()
    guard index < characters.count else {
      throw CalculationError.invalid("An expression is missing.")
    }
    let first = characters[index]
    var left: Expression
    if first == "+" || first == "-" {
      index += 1
      left = .unary(String(first), try expression(25, depth: depth + 1))
    } else if first == "(" {
      index += 1
      left = try expression(depth: depth + 1)
      try close()
    } else if first.isLetter {
      let start = index
      while index < characters.count && characters[index].isLetter { index += 1 }
      let name = String(characters[start..<index]).lowercased()
      if name == "pi" {
        left = .number(.pi)
      } else if name == "e" {
        left = .number(M_E)
      } else if name == "x" {
        left = .variable
      } else {
        guard ["sin", "cos", "tan", "sqrt", "abs", "log", "ln"].contains(name) else {
          throw CalculationError.invalid("Unknown name: \(name)")
        }
        spaces()
        guard index < characters.count && characters[index] == "(" else {
          throw CalculationError.invalid("Functions need parentheses.")
        }
        index += 1
        left = .unary(name, try expression(depth: depth + 1))
        try close()
      }
    } else {
      let start = index
      while index < characters.count && (characters[index].isNumber || characters[index] == ".") {
        index += 1
      }
      if index < characters.count && (characters[index] == "e" || characters[index] == "E") {
        index += 1
        if index < characters.count && (characters[index] == "+" || characters[index] == "-") {
          index += 1
        }
        while index < characters.count && characters[index].isNumber { index += 1 }
      }
      guard let number = Double(String(characters[start..<index])), number.isFinite else {
        throw CalculationError.invalid("Expected a number.")
      }
      left = .number(number)
    }
    while true {
      spaces()
      guard index < characters.count else { break }
      let op = String(characters[index])
      guard let power = ["+": 10, "-": 10, "*": 20, "/": 20, "%": 20, "^": 30][op], power >= minimum
      else { break }
      index += 1
      left = .binary(op, left, try expression(op == "^" ? power : power + 1, depth: depth + 1))
    }
    return left
  }
  mutating func close() throws {
    spaces()
    guard index < characters.count && characters[index] == ")" else {
      throw CalculationError.invalid("A closing parenthesis is missing.")
    }
    index += 1
  }
}

enum ProgrammerMath {
  static func integer(_ text: String) throws -> Int64 {
    let text = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if text.hasPrefix("0x"), let n = UInt64(text.dropFirst(2), radix: 16) {
      return Int64(bitPattern: n)
    }
    if text.hasPrefix("0b"), let n = UInt64(text.dropFirst(2), radix: 2) {
      return Int64(bitPattern: n)
    }
    guard let n = Int64(text) else {
      throw CalculationError.invalid("Use a signed 64-bit integer, 0x hex, or 0b binary.")
    }
    return n
  }
  static func calculate(_ a: Int64, _ op: String, _ b: Int64) throws -> Int64 {
    let result: (partialValue: Int64, overflow: Bool)
    switch op {
    case "+": result = a.addingReportingOverflow(b)
    case "-": result = a.subtractingReportingOverflow(b)
    case "*": result = a.multipliedReportingOverflow(by: b)
    case "/", "%":
      guard b != 0, !(a == .min && b == -1) else {
        throw CalculationError.invalid("Division by zero or signed overflow.")
      }
      return op == "/" ? a / b : a % b
    case "AND": return a & b
    case "OR": return a | b
    case "XOR": return a ^ b
    case "<<", ">>":
      guard (0..<64).contains(b) else { throw CalculationError.invalid("Shift by 0–63 bits.") }
      return op == "<<" ? a &<< b : a &>> b
    default: throw CalculationError.invalid("Unknown operation.")
    }
    guard !result.overflow else { throw CalculationError.invalid("Signed 64-bit overflow.") }
    return result.partialValue
  }
}

enum ConversionUnit: String, CaseIterable {
  case metres, kilometres, feet, miles, grams, kilograms, pounds, celsius, fahrenheit, kelvin,
    bytes, kibibytes, mebibytes, gibibytes
  var group: Int {
    switch self {
    case .metres, .kilometres, .feet, .miles: 0
    case .grams, .kilograms, .pounds: 1
    case .celsius, .fahrenheit, .kelvin: 2
    default: 3
    }
  }
  var scale: Double {
    switch self {
    case .kilometres, .kilograms: 1000
    case .feet: 0.3048
    case .miles: 1609.344
    case .pounds: 453.59237
    case .fahrenheit: 5 / 9
    case .kibibytes: 1024
    case .mebibytes: 1_048_576
    case .gibibytes: 1_073_741_824
    default: 1
    }
  }
  var offset: Double { self == .fahrenheit ? 273.15 - 32 * scale : self == .celsius ? 273.15 : 0 }
  func convert(_ value: Double, to unit: Self) throws -> Double {
    guard group == unit.group else { throw CalculationError.invalid("Choose compatible units.") }
    let base = value * scale + offset
    guard group != 2 || base >= -0.0000001 else {
      throw CalculationError.invalid("Temperature is below absolute zero.")
    }
    let result = (base - unit.offset) / unit.scale
    guard result.isFinite else { throw CalculationError.invalid("Value is too large.") }
    return result
  }
}
