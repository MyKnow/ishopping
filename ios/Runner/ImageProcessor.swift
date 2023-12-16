//
//  ImageProcessor.swift
//  Runner
//
//  Created by 정민호 on 11/24/23.
//

import UIKit
import Photos
import CoreImage
import Alamofire

class ImageProcessor {
    func CVPB2UIImage(pixelBuffer: CVPixelBuffer) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)
    }

    func UIImage2PhotoLibrary(_ image: UIImage) {
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }, completionHandler: { success, error in
                    // 저장 성공 또는 실패 처리
                })
            }
        }
    }

    func UIImage2Server(_ image: UIImage) {
        DispatchQueue.global(qos: .userInitiated).async {
            // 서버 URL
            let url: String = "http://ec2-43-201-111-213.ap-northeast-2.compute.amazonaws.com/api-corner/corner_detect/"

            guard let imageData = image.jpegData(compressionQuality: 1.0) else {
                print("Failed to convert image to data")
                return
            }

            let currentTime = Date().timeIntervalSince1970
            let roundedTime = round(currentTime)
            let roundedTimeStr = String(roundedTime)

            let randomValue = Int.random(in: 11..<100)
            let randomStr = String(randomValue)

            let pictureId = roundedTimeStr + randomStr
            print(pictureId)

            // Alamofire를 사용하여 이미지를 서버로 POST
            AF.upload(multipartFormData: { multipartFormData in
                multipartFormData.append(imageData, withName: "picture", fileName: "image.jpg", mimeType: "image/jpeg")
                multipartFormData.append(pictureId.data(using: .utf8)!, withName: "picture_id")
            }, to: url)
            .responseJSON { response in
                DispatchQueue.main.async {
                    // UI 관련 업데이트는 메인 스레드에서 수행
                    switch response.result {
                    case .success(let value):
                        print("Success: \(value)")
                        if let jsonDictionary = value as? [String: Any] {
                            print(jsonDictionary["info"]!)  // jsonDictionary["info"]에 정보 포함
                        }
                    case .failure(let error):
                        print("Error: \(error)")
                    }
                }
            }
        }
    }
    // 필요에 따라 추가 메서드 구현
}