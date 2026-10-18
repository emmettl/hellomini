import AppKit
import MiniUI
import SwiftUI

extension CalculatorView {
  var programmer: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        TextField("Left operand", text: $a)
        Picker("Operation", selection: $operation) {
          ForEach(["+", "-", "*", "/", "%", "AND", "OR", "XOR", "<<", ">>"], id: \.self) {
            Text($0)
          }
        }.labelsHidden().frame(width: 90)
        TextField("Right operand", text: $b)
      }
      Button("Calculate exactly") {
        perform {
          let n = try ProgrammerMath.calculate(
            ProgrammerMath.integer(a), operation, ProgrammerMath.integer(b))
          return
            "\(n)\n0x\(String(UInt64(bitPattern: n), radix: 16).uppercased())\n0b\(String(UInt64(bitPattern: n), radix: 2))"
        }
      }.buttonStyle(RetroButtonStyle())
      Text(
        "Signed 64-bit arithmetic. Hex and binary describe bit patterns.\nArithmetic overflow is reported; shifts discard bits and right shifts preserve the sign."
      )
      .font(theme.typography.small)
    }
  }
  var conversions: some View {
    VStack(alignment: .leading, spacing: 12) {
      TextField("Amount", text: $amount)
      HStack {
        Picker("From", selection: $from) {
          ForEach(ConversionUnit.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        Picker("To", selection: $to) {
          ForEach(ConversionUnit.allCases.filter { $0.group == from.group }, id: \.self) {
            Text($0.rawValue).tag($0)
          }
        }
      }
      .onChange(of: from) { _, unit in if to.group != unit.group { to = unit } }
      Button("Convert") {
        perform {
          guard let value = Double(amount), value.isFinite else {
            throw CalculationError.invalid("Enter a number.")
          }
          return String(format: "%.12g", try from.convert(value, to: to)) + " " + to.rawValue
        }
      }.buttonStyle(RetroButtonStyle())
    }
  }
  var timeConversions: some View {
    VStack(alignment: .leading, spacing: 10) {
      TextField("Unix seconds", text: $timestamp).accessibilityLabel("Unix timestamp in seconds")
      HStack {
        Button("Seconds → UTC") {
          perform {
            guard let seconds = Double(timestamp), seconds.isFinite, abs(seconds) < 200_000_000_000
            else {
              throw CalculationError.invalid(
                "Enter Unix seconds within the supported calendar range.")
            }
            return ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: seconds))
          }
        }
        Button("Now") { timestamp = String(Int64(Date().timeIntervalSince1970)) }
      }.buttonStyle(RetroButtonStyle())
      TextField("ISO 8601 date", text: $isoDate).accessibilityLabel("ISO 8601 date with timezone")
      Button("Date → seconds") {
        perform {
          let formatter = ISO8601DateFormatter()
          formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
          guard
            let date = formatter.date(from: isoDate) ?? ISO8601DateFormatter().date(from: isoDate)
          else {
            throw CalculationError.invalid(
              "Use an ISO 8601 date with timezone, such as 2026-01-01T12:00:00Z.")
          }
          return String(format: "%.3f", date.timeIntervalSince1970)
        }
      }.buttonStyle(RetroButtonStyle())
    }
  }
}
