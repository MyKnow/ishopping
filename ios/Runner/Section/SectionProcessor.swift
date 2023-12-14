//
//  SectionProcessor.swift
//  Runner
//
//  Created by 정민호 on 12/5/23.
//

import UIKit
import Vision
import ARKit
import Photos

@available(iOS 17.0, *)
class SectionClassifier {
    private var model: VNCoreMLModel
    private var rows: Int
    private var columns: Int

    init(rows: Int = 3, columns: Int = 3) throws {
        self.rows = rows
        self.columns = columns
        let configuration = MLModelConfiguration()
        self.model = try VNCoreMLModel(for: SectionClassification_A_1214(configuration: configuration).model)
    }

    func classifySections(in frame: ARFrame, completion: @escaping ([String]) -> Void) {
        guard let pixelBuffer = frame.capturedImage.toUIImage() else {
            print("픽셀 버퍼에서 UIImage를 생성할 수 없습니다.")
            return
        }
        UIImageWriteToSavedPhotosAlbum(pixelBuffer, nil, nil, nil)

        let width = pixelBuffer.size.width
        let height = pixelBuffer.size.height
        let sectionWidth = width / CGFloat(columns)
        let sectionHeight = height / CGFloat(rows)

        var predictions: [String] = []

        for rowIndex in 0..<rows {
            for columnIndex in 0..<columns {
                let xOffset = sectionWidth * CGFloat(columnIndex)
                let yOffset = sectionHeight * CGFloat(rowIndex)
                let rect = CGRect(x: xOffset, y: yOffset, width: sectionWidth, height: sectionHeight)
                if let croppedImage = pixelBuffer.cgImage?.cropping(to: rect).flatMap(UIImage.init) {
                    UIImageWriteToSavedPhotosAlbum(croppedImage, nil, nil, nil)
                    classifyImage(croppedImage) { prediction in
                        predictions.append(prediction)
                        if predictions.count == self.rows * self.columns {
                            completion(predictions)
                        }
                    }
                }
            }
        }
    }
    
    private func classifyImage(_ image: UIImage, completion: @escaping (String) -> Void) {
        let handler = VNImageRequestHandler(cgImage: image.cgImage!, options: [:])
        let request = VNCoreMLRequest(model: self.model) { request, error in
            guard let results = request.results as? [VNClassificationObservation],
                let topResult = results.first else {
                completion("")
                return
            }

            let threshold: Float = 0.95
            // Confidence 값이 threshold보다 큰 경우에만 결과 반환
            if topResult.confidence >= threshold {
                print(topResult.confidence)
                completion(topResult.identifier)
            } else {
                completion("알수없음")
            }
        }

        do {
            try handler.perform([request])
        } catch {
            print("분류 실패: \(error.localizedDescription)")
            completion("")
        }
    }
}

extension CVPixelBuffer {
    func toUIImage() -> UIImage? {
        let orientation = UIDevice.current.orientation
        
        let ciImage = CIImage(cvPixelBuffer: self)
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }

        switch orientation {
            case .portrait:
                // `portrait` 모드에서는 x와 y 좌표를 서로 바꿔줍니다.
                return UIImage(cgImage: cgImage, scale: 1.0, orientation: .right).fixOrientation()
            // landscape 모드일 때의 좌표 변환
            //case .landscapeRight:
            default:
                return UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
                // ...
                print("default")
        }
        
    }
}
extension UIImage {
    func fixOrientation() -> UIImage {
        if self.imageOrientation == UIImage.Orientation.up {
            return self
        }
        UIGraphicsBeginImageContextWithOptions(self.size, false, self.scale)
            self.draw(in: CGRect(x:0,y: 0, width: self.size.width, height: self.size.height))
            let normalizedImage:UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return normalizedImage;
    }
}
