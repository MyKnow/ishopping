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


// Fluter에서 사용자 정의 플랫폼 뷰를 생성하는 데 필요함
@available(iOS 17.0, *)
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
@available(iOS 17.0, *)
class FLNativeView: NSObject, FlutterPlatformView, ARSCNViewDelegate {
    // AR 담당 Native View
    private var arView: ARSCNView

    // AR 세션 구성 및 시작
    private let configuration = ARWorldTrackingConfiguration()

    // 가이드 dot 및 거리 label들
    private var gridDots: [UIView] = []
    private var gridLabels: [UILabel] = []

    // 조준점 및 라벨의 갯수
    private final var col: Int = 9
    private final var rw: Int = 21

    // 길게 누르기 인식 시간
    private final var longPressTime: Double = 0.5

    // 거리에 따른 색상을 매핑하는 사전
    private var distanceColorMap: [Float: UIColor] = [
        0.1: .white,
        0.3: .red,
        0.6: .yellow,
        0.9: .orange,
        1.2: .green,
        3.0: .blue,
        6.0: .purple,
        9.0: .black
    ]

    // 딕셔너리의 키들을 배열로 변환
    private var indexDistance: [Float] = []

    // Vision 요청을 저장할 배열
    var requests = [VNRequest]() 

    // 사람용 바운딩 박스 저장하는 배열
    private var humanBoundingBoxViews: [UIView] = []

    // 사람용 바운딩 박스와의 거리를 저장하는 배열
    private var distanceMeasurements: [Float] = []
    
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
        super.init()

        // 여기에 조건문을 추가
        if type(of: configuration).supportsFrameSemantics(.sceneDepth) {
            // Activate sceneDepth
            configuration.frameSemantics = .sceneDepth
        }

        //loadModel()

        arView.session = ARSessionManager.shared.session
        arView.delegate = self
        
        // ViewController 초기화
        viewController = ViewController()
        viewController?.session = ARSessionManager.shared.session
        
        //NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
        //NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)

        indexDistance = Array(distanceColorMap.keys).sorted()

        //setupARView()
        ARSessionManager.shared.runSession()
        setupVision()
        //setupGridDots()
        addShortPressGesture()
        addLongPressGesture()
    }
    deinit {
        ARSessionManager.shared.pauseSession()
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
        if let currentFrame = ARSessionManager.shared.session.currentFrame {
            processFrame(currentFrame)
        }
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
            //ARSessionManager.shared.toggleDepthMap()
            if let currentFrame = ARSessionManager.shared.session.currentFrame {
                // Vision 요청 실행
                let pixelBuffer = currentFrame.capturedImage
                //self.performModelInference(pixelBuffer: pixelBuffer)
                self.detect(image: CIImage(cvPixelBuffer: pixelBuffer))
            }
        }
    }

    private func setupVision() {
        // 사람 감지를 위한 Vision 요청 설정
        let request = VNDetectHumanRectanglesRequest(completionHandler: detectHumanHandler)
        self.requests = [request]
    }

    private func detectHumanHandler(request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            // 기존 경계 상자 제거
            self.humanBoundingBoxViews.forEach { $0.removeFromSuperview() }
            self.humanBoundingBoxViews.removeAll()

            guard let observations = request.results as? [VNHumanObservation] else {
                print("No results")
                return
            }

            for observation in observations {
                let boundingBoxView = self.processBoundingBox(for: observation.boundingBox)
                self.arView.addSubview(boundingBoxView)
                self.humanBoundingBoxViews.append(boundingBoxView)
            }
        }
    }

    func processBoundingBox(for boundingBox: CGRect) -> UIView  {
        // 화면 크기
        let screenSize = self.arView.bounds.size

        // 디바이스 방향
        let orientation = UIDevice.current.orientation

        // 디바이스 방향에 따라 좌표를 조정합니다.
        var x: CGFloat = 0
        var y: CGFloat = 0

        switch orientation {
            case .portrait:
                // `portrait` 모드에서는 x와 y 좌표를 서로 바꿔줍니다.
                x = screenSize.width * boundingBox.maxY - (boundingBox.width * screenSize.width)
                y = boundingBox.minX * screenSize.height
            case .landscapeLeft:
                x = boundingBox.minX * screenSize.width
                y = (1 - boundingBox.maxY) * screenSize.height
            //case .landscapeRight:
                // landscape 모드일 때의 좌표 변환
                // ...
            default:
                print("default")
                // 기본값 또는 다른 방향일 때의 처리
                // ...  
        }

        // 화면을 벗어나더라도 bounding box를 잘라내어 계속 표시하도록 수정
        let width = min(boundingBox.width * screenSize.width, screenSize.width - x)
        let height = min(boundingBox.height * screenSize.height, screenSize.height - y)

        // UIKit의 좌표계에 맞는 위치로 UIView를 생성합니다.
        let boundingBoxView = UIView(frame: CGRect(x: x, y: y, width: width, height: height))
        boundingBoxView.layer.borderColor = UIColor.green.cgColor
        boundingBoxView.layer.borderWidth = 2
        boundingBoxView.backgroundColor = .clear

        return boundingBoxView
    }

    func performHitTestAndMeasureDistance() {
        guard let currentFrame = ARSessionManager.shared.session.currentFrame else {
            //print("Current ARFrame is unavailable.")
            return
        }

        distanceMeasurements.removeAll()

        for boundingBoxView in humanBoundingBoxViews {
            let boxCenter = CGPoint(
                x: boundingBoxView.frame.midX,
                y: boundingBoxView.frame.midY
            )

            if let distance = performHitTesting(boxCenter) {
                distanceMeasurements.append(distance) // 거리 측정값 저장
            }
        }

        // 가장 짧은 거리 출력
        if let shortestDistance = distanceMeasurements.min() {
            //print("Shortest detected human distance: \(shortestDistance) meters")
            // 햅틱 피드백 발생 조건 추가 (예: 거리가 1미터 미만일 때만)
            if shortestDistance < 5.0 && !isVibrating {
                isVibrating = true
                if let distance = self.indexDistance.first(where: { $0 > shortestDistance }) {
                    let timeInterval: TimeInterval = TimeInterval(distance)
                    triggerHapticFeedback(interval: timeInterval)
                }
            }
        }
    }

    func triggerHapticFeedback(interval: TimeInterval) {
        hapticC.notificationFeedback(style: "warning")
        let systemSoundID: SystemSoundID
        var delay: TimeInterval = interval
        if delay < 0.7 {
            delay = 0.4
            systemSoundID = 1111
        } else {
            systemSoundID = 1111
        }
        AudioServicesPlaySystemSound(systemSoundID)

        // 햅틱 피드백 재발 방지를 위해 일정 시간 대기 후 isVibrating 재설정
        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + (delay*0.5)) {
            DispatchQueue.main.async {
                self.isVibrating = false
            }
        }
    }

    func performHitTesting(_ screenPoint: CGPoint) -> Float? {
        if let hitTestResult = arView.hitTest(screenPoint, types: .featurePoint).first {
            if let currentFrame = ARSessionManager.shared.session.currentFrame {
                let cameraPosition = currentFrame.camera.transform
                let distance = calculateDistance(from: cameraPosition, to: hitTestResult.worldTransform)
                return distance
            }
        }
        return nil
    }

    private func processFrame(_ frame: ARFrame) {
        let pixelBuffer = frame.capturedImage
        // pixelBuffer에서 고해상도 이미지를 생성 및 처리

        if let image = imageP.CVPB2UIImage(pixelBuffer: pixelBuffer) {
            imageP.UIImage2PhotoLibrary(image)
            //imageP.UIImage2Server(image)
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

            // 사람 거리 측정
            self.performHitTestAndMeasureDistance()

            // Depth map 오버레이가 활성화된 경우에만 처리
            if ARSessionManager.shared.isDepthMapOverlayEnabled, let currentFrame = ARSessionManager.shared.session.currentFrame, let depthData = currentFrame.sceneDepth {
                ARSessionManager.shared.overlayDepthMap(self.arView)
            }
            if let currentFrame = ARSessionManager.shared.session.currentFrame {
                // Vision 요청 실행
                let pixelBuffer = currentFrame.capturedImage
                //self.performModelInference(pixelBuffer: pixelBuffer)
                //self.detect(image: CIImage(cvPixelBuffer: pixelBuffer))
                let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
                do {
                    try imageRequestHandler.perform(self.requests)
                } catch {
                    print("Failed to perform Vision request: \(error)")
                }
            }
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

        var whiteDotCount = 0
        var redDotCount = 0

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
            guard let currentFrame = ARSessionManager.shared.session.currentFrame else { return }
            let cameraPosition = currentFrame.camera.transform
            let distance = calculateDistance(from: cameraPosition, to: hitPoint)

            let dotColor = colorForDistance(distance)
            dot.backgroundColor = dotColor

            if dotColor == .white {
                whiteDotCount += 1
            } else if dotColor == .red {
                redDotCount += 1
            }

            gridLabels[i].text = String(format: "%.2f m", distance)
            gridLabels[i].frame = CGRect(x: x - 50, y: y + dotSize / 2 + labelHeight / 2, width: 100, height: labelHeight)
        }

        let totalDots = col * rw
        if (whiteDotCount+redDotCount) > totalDots / 2 {
            guard let currentFrame = ARSessionManager.shared.session.currentFrame else { return }
            let pixelBuffer = currentFrame.capturedImage

            if let image = imageP.CVPB2UIImage(pixelBuffer: pixelBuffer) {
                //imageP.UIImage2PhotoLibrary(image)
            }
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

    // CoreML의 CIImage를 처리하고 해석하기 위한 메서드 생성, 이것은 모델의 이미지를 분류하기 위해 사용 됩니다.
    func detect(image: CIImage) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let coreMLModel = try? RamenClassification_NEW(configuration: MLModelConfiguration()),
                let visionModel = try? VNCoreMLModel(for: coreMLModel.model) else {
                fatalError("CoreML 모델 로딩 실패")
            }
            let request = VNCoreMLRequest(model: visionModel) { [weak self] request, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("에러: \(error.localizedDescription)")
                        return
                    }
                    guard let results = request.results as? [VNClassificationObservation] else {
                        print("결과 없음")
                        return
                    }
                    if let firstItem = results.first {
                        let formattedConfidence = String(format: "%.2f", firstItem.confidence)

                        if firstItem.confidence < 0.9 {
                            TTSManager.shared.play("인식되지 않음")
                        } else {
                            print("\(firstItem.identifier.capitalized) : \(formattedConfidence)")
                            TTSManager.shared.play(firstItem.identifier.capitalized)

                        }
                    }
                }
            }
            let handler = VNImageRequestHandler(ciImage: image)
            do {
                try handler.perform([request])
            } catch {
                print("에러: \(error.localizedDescription)")
            }
        }
    }
}
