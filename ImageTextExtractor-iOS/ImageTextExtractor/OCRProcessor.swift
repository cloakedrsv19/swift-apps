import UIKit
import Vision

struct ImageResult {
    let filename: String
    let text: String
    let error: String?
}

actor OCRProcessor {
    func extractText(from items: [(image: UIImage, filename: String)]) async -> [ImageResult] {
        var results: [ImageResult] = []
        for item in items {
            let result = await recognizeText(in: item.image, filename: item.filename)
            results.append(result)
        }
        return results
    }

    private func recognizeText(in image: UIImage, filename: String) async -> ImageResult {
        guard let cgImage = image.cgImage else {
            return ImageResult(filename: filename, text: "", error: "Could not decode image")
        }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(returning: ImageResult(filename: filename, text: "", error: error.localizedDescription))
                    return
                }
                let lines = (request.results as? [VNRecognizedTextObservation] ?? [])
                    .compactMap { $0.topCandidates(1).first?.string }
                let joined = lines.joined(separator: "\n")
                continuation.resume(returning: ImageResult(filename: filename, text: joined, error: nil))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: ImageResult(filename: filename, text: "", error: error.localizedDescription))
            }
        }
    }
}
