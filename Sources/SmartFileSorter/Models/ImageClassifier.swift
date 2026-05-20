import Foundation
import Vision

public enum ImageCategory: String {
    case screenshot = "screenshot"
    case photo = "photo"
    case documentScan = "document scan"
    case meme = "meme"
    case unknown = "unknown"
}

public class ImageClassifier {
    public static func classify(url: URL, completion: @escaping (ImageCategory) -> Void) {
        let requestHandler = VNImageRequestHandler(url: url, options: [:])
        let request = VNClassifyImageRequest { request, error in
            guard let results = request.results as? [VNClassificationObservation], error == nil else {
                completion(.unknown)
                return
            }
            
            let screenshotKeywords = ["screen shot", "screenshot", "screen capture", "interface"]
            let documentKeywords = ["document", "receipt", "envelope", "page", "paper"]
            let memeKeywords = ["cartoon", "comic", "illustration", "meme", "text"]
            
            var isScreenshot = false
            var isDocument = false
            var isMeme = false
            var isPhoto = false
            
            for obs in results {
                let identifier = obs.identifier.lowercased()
                let confidence = obs.confidence
                
                if confidence > 0.5 {
                    if screenshotKeywords.contains(where: { identifier.contains($0) }) {
                        isScreenshot = true
                    } else if documentKeywords.contains(where: { identifier.contains($0) }) {
                        isDocument = true
                    } else if memeKeywords.contains(where: { identifier.contains($0) }) {
                        isMeme = true
                    } else if identifier.contains("photo") || identifier.contains("outdoor") || identifier.contains("person") || identifier.contains("scene") {
                        isPhoto = true
                    }
                }
            }
            
            if isScreenshot {
                completion(.screenshot)
            } else if isDocument {
                completion(.documentScan)
            } else if isMeme {
                completion(.meme)
            } else if isPhoto {
                completion(.photo)
            } else {
                completion(.unknown)
            }
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            try? requestHandler.perform([request])
        }
    }
}
