import Flutter
import UIKit
import ARKit
import Photos
import Metal
import AVFoundation
import Foundation
import Alamofire

// Fluter에서 사용자 정의 플랫폼 뷰를 생성하는 데 필요함
@available(iOS 16.0, *)
class FLNativeViewFactory: NSObject, FlutterPlatformViewFactory {
    // Flutter와 Native 코드 간의 통신을 위한 Flutter 바이너리 메신저에 대한 참조를 저장함
    private var messenger: FlutterBinaryMessenger

    // FlutterBinaryMessenger로 팩토리?를 초기화함
    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    // FLNativeView를 생성하고 반환함
    // 뷰의 프레임, 식별자, 선택적 인자
    func create(
        withFrame frame: CGRect, 
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return FLNativeView(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args,
            binaryMessenger: messenger)
    }

    // Flutter와 네이티브 코드 간의 메시지를 인코딩 및 디코딩하기 위한 메시지 코덱을 반환함
    // create 메소드에서 비-nil 인자를 사용할 경우에만 필요
    public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
          return FlutterStandardMessageCodec.sharedInstance()
    }
}

// FlutterPlatformView 프로토콜을 구현하여 Flutter 뷰로 사용될 수 있음
@available(iOS 16.0, *)
class FLNativeView: NSObject, FlutterPlatformView, ARSCNViewDelegate {
    // AR 담당 Native View
    private var arView: ARSCNView

    private var session: ARSession {
        return arView.session
    }

    // 가이드 dot 및 거리 label들
    private var gridDots: [UIView] = []
    private var gridLabels: [UILabel] = []

    // 조준점 및 라벨의 갯수
    private final var col: Int = 10;
    private final var rw: Int = 20;

    // 거리에 따른 색상을 매핑하는 사전
    private var distanceColorMap: [Float: UIColor] = [
        0.3: .red,
        0.6: .yellow,
        0.9: .orange,
        1.2: .green,
        2.0: .blue,
        3.0: .purple,
        5.0: .black
    ]


     // 뷰의 프레임, 뷰 식별자, 선택적 인자, 그리고 바이너리 메신저를 사용하여 네이티브 뷰를 초기화
    init( frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?, binaryMessenger messenger: FlutterBinaryMessenger?) {
        // ARSCNView 인스턴스 생성 및 초기화
        arView = ARSCNView(frame: frame)
        super.init()

        setupARView()
        setupGridDots()
        addTapGesture()
    }
    deinit {
        // ARSession을 일시정지시키는 코드
        arView.session.pause()
    }

    // ARView를 설정
    private func setupARView() {
        // AR 세션 구성 및 시작
        let configuration = ARWorldTrackingConfiguration()
        
        // 4K 비디오 포맷 확인 및 설정
        if let bestVideoFormat = ARWorldTrackingConfiguration.supportedVideoFormats.max(by: { $0.imageResolution.height < $1.imageResolution.height }) {
            configuration.videoFormat = bestVideoFormat
            print("HI-Res video format is supported and set.")
        } else {
            print("HI-Res video format is not supported on this device.")
        }
        
        arView.session.run(configuration)
        arView.delegate = self
    }

    // Tap 하면 실행
    @objc func handleTap(_ sender: UITapGestureRecognizer) {
        if let currentFrame = session.currentFrame {
            processFrame(currentFrame)
        }
    }

    private func addTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        arView.addGestureRecognizer(tapGesture)
    }


    private func processFrame(_ frame: ARFrame) {
        let pixelBuffer = frame.capturedImage
        // pixelBuffer에서 고해상도 이미지를 생성 및 처리

        if let image = convertToUIImage(pixelBuffer: pixelBuffer) {
            saveImageToPhotoLibrary(image)
        }
    }

    private func convertToUIImage(pixelBuffer: CVPixelBuffer) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        // 이미지 방향 설정 (반시계로 돌아가는 문제)
        return UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)
    }


    private func saveImageToPhotoLibrary(_ image: UIImage) {
        ////// 서버로 전송 시도 /////
        // 서버 url
        let url: String = "http://ec2-43-201-111-213.ap-northeast-2.compute.amazonaws.com:8080/api-corner/corner_detect/"
       
        let image = image

        guard let imageData = image.jpegData(compressionQuality: 1.0) else {
            print("Failed to conver image to data")
            return
        }

        let Current_time = Date().timeIntervalSince1970
        let rounded_time = round(Current_time)
        let rounded_time_str = String(rounded_time)

        let random_value = Int.random(in: 11..<100) // 0부터 99 사이의 랜덤한 값
        let random_str = String(random_value)

        let picture_id = rounded_time_str + random_str
        print(picture_id)

        // Alamofire를 사용하여 이미지를 서버로 POST (Alamofire 다운 및 info.plist 수정 필요)
        AF.upload(multipartFormData: { multipartFormData in
            multipartFormData.append(imageData, withName: "picture", fileName: "image.jpg", mimeType: "image/jpeg")
            multipartFormData.append(picture_id.data(using: .utf8)!, withName: "picture_id")
        }, to: url)
        .responseJSON { response in
            switch response.result {
            case .success(let value):
                print("Success: \(value)")
                if let jsonDictionary = value as? [String: Any] {
                    print(jsonDictionary["info"]!)      // jsonDictionary["info"] 안에 코너 or 제품 설명 정보 들어감
                }

            case .failure(let error):
                print("Error: \(error)")
            }
        }

        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }, completionHandler: { success, error in
                    if success {
                        print("Image saved successfully.")
                    } else {
                        print("Error saving image: \(String(describing: error))")
                    }
                })
            }
        }
    }

    // 거리 계산 함수
    func calculateDistance(from cameraTransform: simd_float4x4, to hitTransform: matrix_float4x4) -> Float {
        let cameraPosition = cameraTransform.columns.3
        let hitPosition = hitTransform.columns.3
        return sqrt(
            pow(cameraPosition.x - hitPosition.x, 2) +
            pow(cameraPosition.y - hitPosition.y, 2) +
            pow(cameraPosition.z - hitPosition.z, 2)
        )
    }

    private func setupGridDots() {
        let dotSize: CGFloat = 10
        let labelHeight: CGFloat = 20
        let screenWidth = arView.bounds.width
        let screenHeight = arView.bounds.height

        for row in 0..<rw {
            for column in 0..<col {
                // 점 생성
                let dot = UIView(frame: CGRect(x: 0, y: 0, width: dotSize, height: dotSize))
                dot.backgroundColor = .red
                dot.layer.cornerRadius = dotSize / 2
                let x = CGFloat(column) * screenWidth / CGFloat(col) + screenWidth / CGFloat(2*col)
                let y = CGFloat(row) * screenHeight / CGFloat(rw) + screenHeight / CGFloat(2*rw)
                dot.center = CGPoint(x: x, y: y)
                arView.addSubview(dot)
                gridDots.append(dot)

                // 레이블 생성
                let label = UILabel(frame: CGRect(x: x - 50, y: y + dotSize, width: 100, height: labelHeight))
                label.textAlignment = .center
                label.textColor = .white
                label.backgroundColor = .black.withAlphaComponent(0.5)
                //arView.addSubview(label)
                gridLabels.append(label)
            }
        }
    }

    // ARSCNViewDelegate 메서드
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        DispatchQueue.main.async {
            self.updateGridDotsPosition()
            self.updateDistanceDisplay()
        }
    }

    private func updateGridDotsPosition() {
        let screenWidth = arView.bounds.width
        let screenHeight = arView.bounds.height

        for (i, dot) in gridDots.enumerated() {
            let rowIndex = i / col // 가로 줄 개수로 나눔
            let columnIndex = i % col // 가로 줄 개수로 나머지 연산

            let x = CGFloat(columnIndex) * screenWidth / CGFloat(col) + screenWidth / CGFloat(2 * col)
            let y = CGFloat(rowIndex) * screenHeight / CGFloat(rw) + screenHeight / CGFloat(2 * rw)
            dot.center = CGPoint(x: x, y: y)
        }
    }

    private func updateDistanceDisplay() {
        let screenWidth = arView.bounds.width
        let screenHeight = arView.bounds.height
        let labelHeight: CGFloat = 20
        let dotSize: CGFloat = 10

        for (i, dot) in gridDots.enumerated() {
            let row = i / col
            let column = i % col
            let x = CGFloat(column) * screenWidth / CGFloat(col) + screenWidth / CGFloat(2 * col)
            let y = CGFloat(row) * screenHeight / CGFloat(rw) + screenHeight / CGFloat(2 * rw)
            let screenPoint = CGPoint(x: x, y: y)

            guard let hitTestResults = arView.hitTest(screenPoint, types: .featurePoint).first else {
                gridLabels[i].text = "N/A"
                dot.backgroundColor = .gray
                continue
            }
            let hitPoint = hitTestResults.worldTransform
            guard let currentFrame = arView.session.currentFrame else { return }
            let cameraPosition = currentFrame.camera.transform
            let distance = calculateDistance(from: cameraPosition, to: hitPoint)

            // 거리에 따른 색상 설정
            dot.backgroundColor = colorForDistance(distance)

            gridLabels[i].text = String(format: "%.2f m", distance)
            gridLabels[i].frame = CGRect(x: x - 50, y: y + dotSize / 2 + labelHeight / 2, width: 100, height: labelHeight)
        }
    }

    // 거리에 해당하는 색상을 반환하는 함수
    private func colorForDistance(_ distance: Float) -> UIColor {
        // 거리에 따른 색상 매핑 순회
        for (key, color) in distanceColorMap.sorted(by: { $0.key < $1.key }) {
            if distance <= key {
                return color
            }
        }
        // 매핑된 색상이 없는 경우 기본 색상 반환
        return .white
    }




    // 기본 UIView 객체를 반환
    func view() -> UIView {
        return arView
    }
}
