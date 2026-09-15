import CoreGraphics
import Foundation
import ImageIO
import Vision

/// Reads text from a scrap's own saved picture, entirely on this Mac.
enum ScrapTextRecognizer {
  /// `fast` trades accuracy for speed; the app uses accurate recognition.
  static func recognize(_ data: Data, fast: Bool = false) async throws -> String {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { throw ScrapbookError.invalidImage }
    var request = RecognizeTextRequest()
    request.recognitionLevel = fast ? .fast : .accurate
    request.usesLanguageCorrection = true
    let observations = try await request.perform(on: image)
    return observations.map(\.transcript).joined(separator: "\n")
  }
}
