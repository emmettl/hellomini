import Testing

@testable import MiniCalculator

@Test func arithmeticPrecedenceFunctionsAndErrors() throws {
  #expect(try Expression.parse("2+3*4").value() == 14)
  #expect(try Expression.parse("-2^2").value() == -4)
  #expect(try Expression.parse("2^3^2").value() == 512)
  #expect(try Expression.parse("sqrt(9)+abs(-4)+1e2").value() == 107)
  #expect(try Expression.parse("x^2").value(x: -3) == 9)
  for input in ["1/0", "sqrt(-1)", "2+", "(2", "2 3", "foo(1)", "1e999"] {
    #expect(throws: (any Error).self) { try Expression.parse(input).value() }
  }
}
@Test func exactProgrammerMathHandlesBoundaries() throws {
  #expect(try ProgrammerMath.integer("0xffffffffffffffff") == -1)
  #expect(try ProgrammerMath.calculate(9_007_199_254_740_992, "+", 1) == 9_007_199_254_740_993)
  #expect(try ProgrammerMath.calculate(-8, ">>", 2) == -2)
  #expect(throws: (any Error).self) { try ProgrammerMath.calculate(.max, "+", 1) }
  #expect(throws: (any Error).self) { try ProgrammerMath.calculate(.min, "/", -1) }
  #expect(throws: (any Error).self) { try ProgrammerMath.calculate(1, "<<", 64) }
}
@Test func conversionsPreserveUnitsAndTemperatureOffsets() throws {
  #expect(abs(try ConversionUnit.celsius.convert(100, to: .fahrenheit) - 212) < 0.0001)
  #expect(try ConversionUnit.gibibytes.convert(1, to: .bytes) == 1_073_741_824)
  #expect(throws: (any Error).self) { try ConversionUnit.kelvin.convert(-1, to: .celsius) }
  #expect(throws: (any Error).self) { try ConversionUnit.metres.convert(1, to: .grams) }
}
