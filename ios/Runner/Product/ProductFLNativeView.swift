import Flutter
import UIKit
import ARKit
import Photos
import Metal
import AVFoundation
import Foundation
import Alamofire
import Vision
import CoreML
import NotificationCenter
import CoreImage

// FlutterPlatformView 프로토콜을 구현하여 Flutter 뷰로 사용될 수 있음
@available(iOS 17.0, *)
class ProductFLNativeView: NSObject, FlutterPlatformView, ARSCNViewDelegate {
    // AR 담당 Native View
    private var arView: ARSCNView
    private var binaryMessenger: FlutterBinaryMessenger
    private var nowSection: String
    private var channel: FlutterMethodChannel

    // AR 세션 구성 및 시작
    private let configuration = ARWorldTrackingConfiguration()

    // 길게 누르기 인식 시간
    private final var longPressTime: Double = 0.5

    public var shoppingBasketMap: [String: Int]

    public var isBasketMode: Bool = false

    public var isEditMode: Bool = false
    public var editCount: Int = 1

    public var nowProduct: String = ""

    public var willBuy: Bool = false

    // Vision 요청을 저장할 배열
    var requests = [VNRequest]()

    // HapticFeedbackManager 인스턴스 생성
    let hapticC = HapticFeedbackManager()

    // ImageProcessor 인스턴스 생성
    let imageP = ImageProcessor()

    // ViewController 인스턴스 추가 (필요에 따라)
    var viewController: ViewController?

    private var model: VNCoreMLModel!

    private var isVibrating: Bool = false

    private var alertTimer: Timer?

    // 뷰의 프레임, 뷰 식별자, 선택적 인자, 그리고 바이너리 메신저를 사용하여 네이티브 뷰를 초기화
    init( frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?, binaryMessenger messenger: FlutterBinaryMessenger?) {
        // ARSCNView 인스턴스 생성 및 초기화
        arView = ARSCNView(frame: frame)
        guard let messenger = messenger else {
            fatalError("Binary messenger is nil in SectionFLNativeView initializer")
        }
        self.binaryMessenger = messenger

        self.channel = FlutterMethodChannel(name: "flutter/SB2S", binaryMessenger: self.binaryMessenger)
        self.nowSection = "ALL"
        self.shoppingBasketMap = [:]
        if let args = args as? [String: Any] {
            if let shoppingbag = args["shoppingbag"] as? [String:Int] {
                self.shoppingBasketMap = shoppingbag
            }
            if let predictionValue = args["predictionValue"] as? String {
                self.nowSection = predictionValue
            }
        } 
        super.init()

        TTSManager.shared.play("제품모드, \(self.nowSection)")

        // 여기에 조건문을 추가
        if type(of: configuration).supportsFrameSemantics(.sceneDepth) {
            // Activate sceneDepth
            configuration.frameSemantics = .sceneDepth
        }

        arView.session = ARSessionManager.shared.session
        arView.delegate = self
        
        // ViewController 초기화
        viewController = ViewController()
        viewController?.session = ARSessionManager.shared.session
        
        ARSessionManager.shared.runSession()
        addShortPressGesture()
        addLongPressGesture()
        addSwipeGesture()
    }
    deinit {
        //ARSessionManager.shared.pauseSession()
        //TTSManager.shared.stop()
    }


    private func sendShoppingbagToSection() {
        let data: [String: Any] = [
            "shoppingbag": shoppingBasketMap // 예시 데이터
        ]
        self.channel.invokeMethod("sendData2S", arguments: data)
    }

    private func sendShoppingbagToFlutter() {
        let data: [String: Any] = [
            "shoppingbag": shoppingBasketMap // 예시 데이터
        ]
        self.channel.invokeMethod("sendData2F", arguments: data)
    }

    // 짧게 누르기 제스쳐 추가
    private func addShortPressGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleShortPress))
        arView.addGestureRecognizer(tapGesture)
    }
    // 짧게 누르기 제스쳐 핸들러
    @objc func handleShortPress(_ sender: UITapGestureRecognizer) {
        TTSManager.shared.play("짧게 누름")
        hapticC.impactFeedback(style: "heavy")
    }

    // 길게 누르기 제스쳐 추가
    private func addLongPressGesture() {
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        longPressGesture.minimumPressDuration = longPressTime // 1초 이상 길게 누르기
        arView.addGestureRecognizer(longPressGesture)
    }
    // 길게 누르기 제스처 핸들러
    @objc func handleLongPress(_ sender: UILongPressGestureRecognizer) {
        if sender.state == .began {
            TTSManager.shared.play("길게 누름")
            hapticC.notificationFeedback(style: "success")
            if self.willBuy {
                // TODO:결제 처리
            } else {
                //ARSessionManager.shared.toggleDepthMap()
                if let currentFrame = ARSessionManager.shared.session.currentFrame {
                    // Vision 요청 실행
                    let nowImage = currentFrame.capturedImage
                    //self.performModelInference(pixelBuffer: pixelBuffer)
                    self.detect(image: CIImage(cvPixelBuffer: nowImage))
                }
            }
        }
    }

    // 스와이프 제스쳐 추가
    private func addSwipeGesture() {
        let directions: [UISwipeGestureRecognizer.Direction] = [.left, .right, .up, .down]

        for direction in directions {
            let swipe = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
            swipe.direction = direction
            arView.addGestureRecognizer(swipe)
        }
    }
    // 스와이프 제스쳐 핸들러
    @objc private func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
        hapticC.impactFeedback(style: "Heavy")
        TTSManager.shared.stop()
        switch gesture.direction {
        case .left: // 무언갈 취소하는 것
            TTSManager.shared.play("왼쪽")
            if self.isEditMode {
                self.isEditMode = false
                self.isBasketMode = false
                TTSManager.shared.play("수정 취소")
            }
            else if self.isBasketMode {
                self.isBasketMode = false
                TTSManager.shared.play("취소")
                self.nowProduct = ""
            } else if self.willBuy {
                self.isBasketMode = false
                self.willBuy = false
                TTSManager.shared.play("결제 취소")
            } else {
                print("!")
                TTSManager.shared.play("세션 모드로 이동")
                sendShoppingbagToSection()
            }
            break
        case .right: // 무언갈 진행하는 것
            TTSManager.shared.play("오른쪽")
            if self.isEditMode{
                self.isBasketMode = false
                self.shoppingBasket(self.nowProduct)
            }
            else if self.willBuy {
                self.sendShoppingbagToFlutter()
            } else {
                self.totalProduct()
            }
            break
        case .up: // 무언갈 더하는 것
            TTSManager.shared.play("위")
            if self.isEditMode{
                self.editCount += 1
                self.editProduct(self.nowProduct)
            } else if self.isBasketMode {
                self.isBasketMode = false
                self.isEditMode = true
                self.editCount += 1
                self.editProduct(self.nowProduct)
            }
            break
        case .down: // 무언갈 빼는 것
            TTSManager.shared.play("아래")
            if self.isEditMode{
                self.editCount -= 1
                self.editProduct(self.nowProduct)
            } else if self.isBasketMode {
                self.isBasketMode = false
                self.isEditMode = true
                self.editProduct(self.nowProduct)
            }
            break
        default:
            break
        }
        // 여기에 각 방향에 따른 추가적인 작업 수행
    }

    // ARSCNViewDelegate 메서드
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        DispatchQueue.main.async {
            // Depth map 오버레이가 활성화된 경우에만 처리
            if ARSessionManager.shared.isDepthMapOverlayEnabled, let currentFrame = ARSessionManager.shared.session.currentFrame, let depthData = currentFrame.sceneDepth {
                ARSessionManager.shared.overlayDepthMap(self.arView)
            }
            if let currentFrame = ARSessionManager.shared.session.currentFrame {
                // Vision 요청 실행
                let pixelBuffer = currentFrame.capturedImage
                let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
                do {
                    try imageRequestHandler.perform(self.requests)
                } catch {
                    print("Failed to perform Vision request: \(error)")
                }
            }
        }
    }

    // 기본 UIView 객체를 반환
    func view() -> UIView {
        return arView
    }

    func detect(image: CIImage) {
        // CoreML 모델 로딩
        var coreMLModel: MLModel?

        switch self.nowSection {
        case "라면매대":
            coreMLModel = try? RamenClassification_1208(configuration: MLModelConfiguration()).model
        case "간편식품매대":
            coreMLModel = try? SGClassification_1214(configuration: MLModelConfiguration()).model
        case "ALL" :
            coreMLModel = try? RamenClassification_1208(configuration: MLModelConfiguration()).model
        default:
            TTSManager.shared.play("해당하는 섹션이 없습니다.")
            return
        }

        guard let visionModel = try? VNCoreMLModel(for: coreMLModel!),
            let request = try? VNCoreMLRequest(model: visionModel, completionHandler: { [weak self] request, error in
                self?.handleClassification(request: request, error: error)
            }) else {
            print("CoreML 모델 로딩 실패")
            return
        }

        let handler = VNImageRequestHandler(ciImage: image)
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                print("에러: \(error.localizedDescription)")
            }
        }
    }


    private func handleClassification(request: VNRequest, error: Error?) {
        DispatchQueue.global().async { [self] in
            if let error = error {
                print("에러: \(error.localizedDescription)")
                return
            }
            guard let results = request.results as? [VNClassificationObservation],
                let firstItem = results.first else {
                print("결과 없음")
                return
            }

            guard let currentFrame = ARSessionManager.shared.session.currentFrame else { return }
            let pixelBuffer = currentFrame.capturedImage

            BarcodeProcessor.shared.processBarcode(from: imageP.CVPB2UIImage(pixelBuffer: pixelBuffer)!) { barcodeString in
                if let barcode = barcodeString {
                    // Handle barcode detected
                    TTSManager.shared.play(barcode)
                } else {
                    // Handle no barcode found
                    if firstItem.confidence < 0.98 {
                        // Convert CIImage to UIImage;
                        TTSManager.shared.play("인식되지 않음")
                    } else {
                        let formattedConfidence = String(format: "%.2f", firstItem.confidence)
                        TTSManager.shared.stop()
                        self.nowProduct = firstItem.identifier.capitalized
                        self.isBasketMode = true
                        print("\(self.nowProduct) : \(formattedConfidence)")
                        //TTSManager.shared.play(formattedConfidence)
                        self.editCount = self.productCount(self.nowProduct)
                        self.sendProductNameToServer(self.nowProduct)
                    }
                }
            }
        }
    }

    func sendProductNameToServer(_ productName: String) {
        // 서버 URL
        let url = "http://ec2-3-36-61-193.ap-northeast-2.compute.amazonaws.com:8080/api-corner/get-info/"

        // POST 요청의 본문에 포함될 파라미터
        let parameters: [String: Any] = ["product_name": productName]

        // Alamofire를 사용하여 POST 요청 실행
        AF.request(url, method: .post, parameters: parameters, encoding: JSONEncoding.default).responseJSON { [weak self] response in
            guard let strongSelf = self else { return }

            switch response.result {
            case .success(let value):
                if let jsonDictionary = value as? [String: Any], let receivedPrice = jsonDictionary["price"] as? Int {
                    // 서버 응답 후 가격 정보 처리
                    DispatchQueue.main.async {
                        strongSelf.handleServerResponse(productName: productName, receivedPrice: receivedPrice)
                    }
                }
            case .failure(let error):
                print("Error: \(error)")
                DispatchQueue.main.async {
                    // 에러 발생 시 처리
                    TTSManager.shared.play("가격 정보를 가져오는 데 실패했습니다.")
                }
            }
        }
    }

    private func handleServerResponse(productName: String, receivedPrice: Int) {
        // 서버 응답에 따른 UI 처리
        TTSManager.shared.play(productName)
        TTSManager.shared.play("현재 장바구니에 \(editCount)개 있음")
        TTSManager.shared.play("가격은 \(receivedPrice)원")
        TTSManager.shared.play("갯수를 수정하려면 위, 아래로 스와이프")
        TTSManager.shared.play("취소하려면 왼쪽으로 스와이프")
    }

    public func shoppingBasket(_ item: String) {
        shoppingBasketMap.updateValue(editCount, forKey: item)
        self.editCount = 1
        self.isEditMode = false
        self.isBasketMode = false
        if self.productCount(item) == 0 {
            shoppingBasketMap[item] = nil
            TTSManager.shared.play("\(item) 장바구니에서 제거")
        } else {
            TTSManager.shared.play("\(item)이 장바구니에 \(self.productCount(item))개 있음")
            TTSManager.shared.play("결제하려면 오른쪽으로 스와이프")
        }
    }
    public func productCount(_ item: String) -> Int {
        // Non optional Type
        var count: Int = shoppingBasketMap[item, default:0]
        return count
    }
    public func editProduct (_ item: String) {
        if self.editCount < 0 {self.editCount = 0}
        TTSManager.shared.play("현재 \(self.editCount)개")
    }
    public func totalProduct() {
        if shoppingBasketMap.isEmpty {
            TTSManager.shared.play("현재 장바구니가 비어 있습니다.")
        } else {
            /*
            TTSManager.shared.play("현재 장바구니에 있는 상품은, ")
            for (key, value) in shoppingBasketMap {
                print("상품: \(key), 갯수: \(value)")
                TTSManager.shared.play("\(key), \(value)개, ")
            }
            TTSManager.shared.play("수정하려면 화면을 위로 스와이프, ")
            TTSManager.shared.play("취소하려면 화면을 왼쪽으로 스와이프, ")
            TTSManager.shared.play("결제하려면 화면을 1초 이상 길게 누르세요")
            */
            self.sendShoppingbagToFlutter()
            //self.willBuy = true
        }
    }
}
