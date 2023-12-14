import UIKit
import Vision
import Alamofire

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

    func sendProductInfoToServer(_ code: String, completion: @escaping (String?, Int?) -> Void) {
        // 서버 URL
        var url: String
        var parameters: [String: Any]

        // 입력된 코드가 숫자로 시작하는지 여부로 바코드와 QR 코드를 구분
        if let firstCharacter = code.first, firstCharacter.isNumber {
            // 바코드의 경우
            url = "http://ec2-3-36-61-193.ap-northeast-2.compute.amazonaws.com:8080/api-corner/get-info-by-barcode/"
            parameters = ["barcode_num": code]
        } else {
            // QR 코드의 경우
            url = "http://ec2-3-36-61-193.ap-northeast-2.compute.amazonaws.com:8080/api-corner/get-info-by-qr/"
            parameters = ["qr": code]
        }

        // Alamofire를 사용하여 POST 요청 실행
        AF.request(url, method: .post, parameters: parameters, encoding: JSONEncoding.default).responseJSON { response in
            switch response.result {
            case .success(let value):
                if let jsonDictionary = value as? [String: Any], let productName = jsonDictionary["product_name"] as? String, let receivedPrice = jsonDictionary["price"] as? Int {
                    // 서버 응답 후 제품 정보 처리
                    completion(productName, receivedPrice)
                } else {
                    // 제품 정보가 없는 경우
                    completion(nil, nil)
                }
            case .failure(let error):
                print("Error: \(error)")
                // 에러 발생 시 처리
                completion(nil, nil)
            }
        }
    }

}
