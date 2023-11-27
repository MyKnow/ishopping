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

        // DepthMap View
        private var depthOverlayView: UIImageView?

        // AR 세션 구성 및 시작
        private let configuration = ARWorldTrackingConfiguration()

        public var session: ARSession {
            return arView.session
        }

        // 가이드 dot 및 거리 label들
        private var gridDots: [UIView] = []
        private var gridLabels: [UILabel] = []

        // 조준점 및 라벨의 갯수
        private final var col: Int = 9
        private final var rw: Int = 21

        // 길게 누르기 인식 시간
        private final var longPressTime: Double = 0.5

        // 오버레이어 투명 정도
        private final var layerAlpha: CGFloat = 0.9

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
        public var indexDistance: [Float] = []

        // Depth map 오버레이 상태를 추적하는 변수
        private var isDepthMapOverlayEnabled = false

        // Vision 요청을 저장할 배열
        var requests = [VNRequest]()

        // HapticFeedbackManager 인스턴스 생성
        let hapticM = HapticFeedbackManager()

        // ImageProcessor 인스턴스 생성
        let imageP = ImageProcessor()

        // HumanDetectionManager 인스턴스 생성
        private lazy var humanC: HumanDetectionManager = {
            return HumanDetectionManager(arView: arView, indexDistance: indexDistance, isVibrating: isVibrating, requests: requests)
        }()

        // 
        public var isVibrating: Bool = false

        // 
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

            indexDistance = Array(distanceColorMap.keys).sorted()

            setupARView()
            //setupVision()
            //setupGridDots()
            addShortPressGesture()
            addLongPressGesture()
        }
        deinit {
            // ARSession을 일시정지시키는 코드
            arView.session.pause()
        }

        // ARView를 설정
        private func setupARView() {
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

        // 짧게 누르기 제스쳐 추가
        private func addShortPressGesture() {
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleShortPress))
            arView.addGestureRecognizer(tapGesture)
        }
        // 짧게 누르기 제스쳐 핸들러
        @objc func handleShortPress(_ sender: UITapGestureRecognizer) {
            print("Short Press")
            hapticM.impactFeedback(style: "heavy")
            if let currentFrame = session.currentFrame {
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
                print(isDepthMapOverlayEnabled)
                hapticM.notificationFeedback(style: "success")
                // Depth map 오버레이 상태 토글
                isDepthMapOverlayEnabled.toggle()

                // AR 세션의 frame semantics 업데이트
                if isDepthMapOverlayEnabled {
                    configuration.frameSemantics.insert(.sceneDepth)
                } else {
                    configuration.frameSemantics.remove(.sceneDepth)
                    depthOverlayView?.removeFromSuperview()
                    depthOverlayView = nil
                }

                // AR 세션 다시 시작
                arView.session.run(configuration)
            }
        }

        func performHitTesting(_ screenPoint: CGPoint) -> Float? {
            if let hitTestResult = arView.hitTest(screenPoint, types: .featurePoint).first {
                if let currentFrame = arView.session.currentFrame {
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
                imageP.UIImage2Server(image)
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


                // Depth map 오버레이가 활성화된 경우에만 처리
                if self.isDepthMapOverlayEnabled, let currentFrame = self.arView.session.currentFrame, let depthData = currentFrame.sceneDepth {
                    self.overlayDepthMap(depthData.depthMap)
                }

                // 사람 거리 측정
                self.humanC.performHitTestAndMeasureDistance()

                if let currentFrame = self.arView.session.currentFrame {
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

        // Depth map 오버레이를 추가하는 메서드
        private func overlayDepthMap(_ depthMap: CVPixelBuffer) {
            guard let depthImage = convertDepthDataToUIImage(depthMap) else { return }
            dump(depthMap)

            if depthOverlayView == nil {
                depthOverlayView = UIImageView(frame: arView.bounds)
                depthOverlayView?.contentMode = .scaleAspectFill // 변경: 이미지가 뷰의 경계를 채우도록 설정
                depthOverlayView?.clipsToBounds = true // 뷰 경계 밖의 이미지 부분을 잘라냄
                depthOverlayView?.alpha = layerAlpha // 반투명 설정
                arView.addSubview(depthOverlayView!)
            }

            depthOverlayView?.frame = arView.bounds // ARView 크기에 맞게 조정
            depthOverlayView?.image = depthImage
        }

        //
        private func convertDepthDataToUIImage(_ depthMap: CVPixelBuffer) -> UIImage? {
            let ciImage = CIImage(cvPixelBuffer: depthMap)
            let context = CIContext(options: nil)
            guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
                return nil
            }
            return UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)
            //return UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
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
                guard let currentFrame = arView.session.currentFrame else { return }
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
                guard let currentFrame = arView.session.currentFrame else { return }
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
        
        func detect(image: CIImage) {
            guard let coreMLModel = try? RamenClassifier(configuration: MLModelConfiguration()),
                let visionModel = try? VNCoreMLModel(for: coreMLModel.model) else {
                fatalError("Loading CoreML Model Failed")
            }
            let request = VNCoreMLRequest(model: visionModel) { request, error in
                guard error == nil else {
                    fatalError("Failed Request")
                }
                guard let classification = request.results as? [VNClassificationObservation] else {
                    fatalError("Faild convert VNClassificationObservation")
                }
                
                /*
                //  타이틀을 가장 정확도 높은 이름으로 설정
                if let fitstItem = classification.first {
                    self.navigationItem.title = fitstItem.identifier.capitalized
                }
                */
            }
            
            let handler = VNImageRequestHandler(ciImage: image)
            do {
                try handler.perform([request])
            } catch {
                print(error)
            }
        }
    }
