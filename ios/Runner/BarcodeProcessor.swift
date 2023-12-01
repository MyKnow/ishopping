import UIKit
import Vision

class BarcodeProcessor {
    static let shared = BarcodeProcessor()
    
    func processBarcode(from uiImage: UIImage, completion: @escaping (String?) -> Void) {
        guard let cgImage = uiImage.cgImage else {
            completion(nil)
            return
        }

        let request = VNDetectBarcodesRequest { request, error in
            if let error = error {
                print("Barcode detection error: \(error.localizedDescription)")
                completion(nil)
                return
            }

            let barcodes = request.results as? [VNBarcodeObservation]
            let barcodeString = barcodes?.first?.payloadStringValue
            completion(barcodeString)
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
    }
}
