// Setup-only OCR: avoid enabling XCTest/AX while measuring fresh extension launches.
import Foundation
import ImageIO
import Vision
@main enum Recognize {
    static func main() throws {
        let url = URL(fileURLWithPath: CommandLine.arguments[1])
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.customWords = ["米鍵盤", "English", "Emoji", "Chinese"]
        request.recognitionLanguages = ["zh-Hant", "en-US"]
        try VNImageRequestHandler(url: url).perform([request])
        let source = CGImageSourceCreateWithURL(url as CFURL, nil)!
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
        for observation in request.results ?? [] {
            guard let text = observation.topCandidates(1).first?.string else { continue }
            let box = observation.boundingBox
            let result: [String: Any] = ["text": text, "x": box.midX * Double(image.width) / 3, "y": (1 - box.midY) * Double(image.height) / 3]
            print(String(data: try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]), encoding: .utf8)!)
        }
    }
}
