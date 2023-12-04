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

extension SCNVector3 {
    static func - (left: SCNVector3, right: SCNVector3) -> SCNVector3 {
        return SCNVector3Make(left.x - right.x, left.y - right.y, left.z - right.z)
    }
    
    var length: Float {
        return sqrt(x * x + y * y + z * z)
    }
}


// FlutterPlatformView 프로토콜을 구현하여 Flutter 뷰로 사용될 수 있음
@available(iOS 17.0, *)
class SectionFLNativeView: NSObject, FlutterPlatformView, ARSCNViewDelegate {
    // AR 담당 Native View
    private var arView: ARSCNView
    private var binaryMessenger: FlutterBinaryMessenger
    private var predictionValue: String = "RAMEN"  // 예측값 초기화
    public var shoppingBasketMap: [String: Int]
    private var channel: FlutterMethodChannel

    // Add properties to track the AR object and its position
    private var arObjectNode: SCNNode?
    private var arObjectPosition: simd_float4x4?

    private var labelText: String = "매대 찾기"

    // 마지막으로 읽은 텍스트와 시간을 저장하는 변수 추가
    private var lastReadText: String?
    private var lastReadTime: Date?

    private var findShelfLabel: UILabel?

    // AR 텍스트 노드를 저장하는 배열
    private var arTextNodes: [SCNNode] = []

    // 선택된 텍스트 노드
    private var selectedTextNode: SCNNode?

    // AR 세션 구성 및 시작
    private let configuration = ARWorldTrackingConfiguration()

    // 가이드 dot 및 거리 label들
    private var gridDots: [UIView] = []
    private var gridLabels: [UILabel] = []

    // 선들을 저장하는 배열
    private var gridLines: [UIView] = []

    // 조준점 및 라벨의 갯수
    private final var col: Int = 3
    private final var rw: Int = 3

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
    
    // 사람용 바운딩 박스와의 거리를 저장하는 배열과 각도를 저장하는 배열
    private var distanceMeasurements: [Float] = []
    private var angleMeasurements: [Float] = []
    
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
        // binaryMessenger 초기화
        guard let messenger = messenger else {
            fatalError("Binary messenger is nil in SectionFLNativeView initializer")
        }
        self.binaryMessenger = messenger
        self.channel = FlutterMethodChannel(name: "flutter/PV2P", binaryMessenger: binaryMessenger)

        self.shoppingBasketMap = [:]
        if let args = args as? [String: Any],let shoppingbag = args["shoppingbag"] as? [String:Int] {
            self.shoppingBasketMap = shoppingbag
        }
        super.init()

        TTSManager.shared.play("섹션모드")

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
        
        indexDistance = Array(distanceColorMap.keys).sorted() 

        ARSessionManager.shared.runSession()
        setupVision()
        addShortPressGesture()
        addLongPressGesture()
        addSwipeGesture()
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
        TTSManager.shared.stop()
        TTSManager.shared.play("짧게 누름")
        hapticC.impactFeedback(style: "heavy")
        let screenCenter = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
        addArText()
        if let hitTestResult = arView.hitTest(screenCenter, types: .existingPlaneUsingExtent).first {
            print("test")
            addArObject(at: hitTestResult)
        }
        if let currentFrame = ARSessionManager.shared.session.currentFrame {
            //processFrame(currentFrame)
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
            sendShoppingbagToFlutter()
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
        switch gesture.direction {
        case .left: // 무언갈 진행하는 것
            ARSessionManager.shared.pauseSession()
            break
        case .right: // 무언갈 취소하는 것
            sendDataToFlutter()
            ARSessionManager.shared.pauseSession()
            break
        case .up: // 무언갈 더하는 것
            break
        case .down: // 무언갈 빼는 것
            break
        default:
            break
        }
        // 여기에 각 방향에 따른 추가적인 작업 수행
    }

    private func sendDataToFlutter() {
        let data: [String: Any] = [
            "predictionValue": predictionValue,
            "shoppingbag": shoppingBasketMap // 예시 데이터
        ]
        self.channel.invokeMethod("sendData", arguments: data)
    }
    private func sendShoppingbagToFlutter() {
        let data: [String: Any] = [
            "shoppingbag": shoppingBasketMap // 예시 데이터
        ]
        self.channel.invokeMethod("sendData2F", arguments: data)
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
        angleMeasurements.removeAll()

        for boundingBoxView in humanBoundingBoxViews {
            let boxCenter = CGPoint(
                x: boundingBoxView.frame.midX,
                y: boundingBoxView.frame.midY
            )

            if let (distance, angle) = performHitTesting(boxCenter) {
                distanceMeasurements.append(distance) // 거리 측정값 저장
                angleMeasurements.append(angle)
                self.labelText = "거리 : \(distance), 각도 : \(angle)"
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
                    
                    findShelfLabel?.text = self.labelText
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

    private func processFrame(_ frame: ARFrame) {
        let pixelBuffer = frame.capturedImage
        // pixelBuffer에서 고해상도 이미지를 생성 및 처리

        if let image = imageP.CVPB2UIImage(pixelBuffer: pixelBuffer) {
            imageP.UIImage2PhotoLibrary(image)
            //imageP.UIImage2Server(image)
        }
    }

    // 특정 지점까지의 거리와 각도를 반환하는 함수
    func performHitTesting(_ screenPoint: CGPoint) -> (distance: Float, angle: Float)? {
        guard let hitTestResult = arView.hitTest(screenPoint, types: .featurePoint).first,
            let currentFrame = ARSessionManager.shared.session.currentFrame else {
            return nil
        }

        let cameraTransform = currentFrame.camera.transform
        let hitPoint = hitTestResult.worldTransform

        // 카메라(사용자 위치)로부터의 거리 계산
        let distance = calculateDistance(from: cameraTransform, to: hitPoint)

        // 카메라(사용자 위치)로부터의 각도 계산
        let angle = calculateAngle(from: cameraTransform, to: hitPoint)

        return (distance, angle)
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

    // 카메라에서 노드까지의 거리 계산 함수
    private func calculateDistanceARContents(fromCameraTo nodePosition: SCNVector3) -> Float {
        guard let cameraTransform = arView.session.currentFrame?.camera.transform else {
            return Float.greatestFiniteMagnitude
        }
        let cameraPosition = SCNVector3(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
        return subtract(cameraPosition, nodePosition).length
    }

    // 카메라(사용자)의 포워드 벡터를 계산하는 함수
    func forwardVector(from transform: simd_float4x4) -> simd_float3 {
        return simd_normalize(simd_float3(-transform.columns.2.x, -transform.columns.2.y, -transform.columns.2.z))
    }

    // 두 벡터 사이의 각도를 계산하는 함수
    func angleBetweenVectors(_ vectorA: simd_float3, _ vectorB: simd_float3) -> Float {
        let dotProduct = simd_dot(simd_normalize(vectorA), simd_normalize(vectorB))
        return acos(min(max(dotProduct, -1.0), 1.0)) // 결과는 라디안 단위
    }

    // 특정 지점까지의 각도를 반환하는 함수
    func calculateAngle(from cameraTransform: simd_float4x4, to hitTransform: matrix_float4x4) -> Float {
        let cameraPosition = cameraTransform.columns.3
        let hitPosition = hitTransform.columns.3

        // 카메라 위치에서 타겟 위치까지의 방향 벡터
        let directionToTarget = simd_float3(hitPosition.x - cameraPosition.x, hitPosition.y - cameraPosition.y, hitPosition.z - cameraPosition.z)

        // 카메라의 포워드 벡터
        let cameraForward = forwardVector(from: cameraTransform)

        // 두 벡터 사이의 각도 계산
        return angleBetweenVectors(cameraForward, directionToTarget)
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
            //self.updateGridDotsPosition()
            //self.updateDistanceDisplay()
            self.drawGridLines()
            self.addFindShelfLabel()
            self.updateSelectedTextNode()


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
            // 사람 거리 측정
            self.performHitTestAndMeasureDistance()
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

    private func setupVision() {
        // 사람 감지를 위한 Vision 요청 설정
        let request = VNDetectHumanRectanglesRequest(completionHandler: detectHumanHandler)
        self.requests = [request]
    }

    private func detectHumanHandler(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNHumanObservation] else {
            print("No results")
            return
        }

        DispatchQueue.main.async {
            // 기존 경계 상자 제거
            self.humanBoundingBoxViews.forEach { $0.removeFromSuperview() }
            self.humanBoundingBoxViews.removeAll()

            observations.forEach { observation in
                let boundingBoxView = self.processBoundingBox(for: observation.boundingBox)
                self.arView.addSubview(boundingBoxView)
                self.humanBoundingBoxViews.append(boundingBoxView)
            }
        }
    }

    private func drawGridLines() {
        let screenWidth = arView.bounds.width
        let screenHeight = arView.bounds.height
        let lineThickness: CGFloat = 2
        let totalLinesNeeded = col + rw - 2 // 가로 및 세로에 필요한 총 선의 수

        // 필요한 선의 수보다 더 많은 선이 있는 경우, 초과분 제거
        if gridLines.count > totalLinesNeeded {
            for _ in totalLinesNeeded..<gridLines.count {
                gridLines.removeLast().removeFromSuperview()
            }
        }

        // 세로선 생성 또는 업데이트
        for column in 1..<col {
            let xPosition = CGFloat(column) * screenWidth / CGFloat(col)
            if column - 1 < gridLines.count {
                let line = gridLines[column - 1]
                line.frame = CGRect(x: xPosition, y: 0, width: lineThickness, height: screenHeight)
            } else {
                let line = UIView(frame: CGRect(x: xPosition, y: 0, width: lineThickness, height: screenHeight))
                line.backgroundColor = .white
                arView.addSubview(line)
                gridLines.append(line)
            }
        }

        // 가로선 생성 또는 업데이트
        for row in 1..<rw {
            let yPosition = CGFloat(row) * screenHeight / CGFloat(rw)
            let lineIndex = col - 1 + row - 1
            if lineIndex < gridLines.count {
                let line = gridLines[lineIndex]
                line.frame = CGRect(x: 0, y: yPosition, width: screenWidth, height: lineThickness)
            } else {
                let line = UIView(frame: CGRect(x: 0, y: yPosition, width: screenWidth, height: lineThickness))
                line.backgroundColor = .white
                arView.addSubview(line)
                gridLines.append(line)
            }
        }
    }

    private func addFindShelfLabel() {
        if findShelfLabel == nil {
            let label = UILabel()
            label.backgroundColor = UIColor.black
            label.alpha = 0.7 // 투명도 조정
            label.text = self.labelText
            label.textColor = .red
            label.textAlignment = .center
            label.font = UIFont.boldSystemFont(ofSize: 10)
            label.layer.cornerRadius = 10
            label.layer.masksToBounds = true
            arView.addSubview(label)
            findShelfLabel = label
        }
        findShelfLabel?.frame = CGRect(x: 20, y: arView.safeAreaInsets.top, width: arView.bounds.width - 40, height: 150)
    }

    // Method to add the AR object
    private func addArObject(at hitTestResult: ARHitTestResult) {
        let objectNode = SCNNode(geometry: SCNSphere(radius: 5.0)) // Example: A simple sphere
        objectNode.position = SCNVector3(hitTestResult.worldTransform.columns.3.x,
                                        hitTestResult.worldTransform.columns.3.y,
                                        hitTestResult.worldTransform.columns.3.z)
        arView.scene.rootNode.addChildNode(objectNode)
        arObjectNode = objectNode
        arObjectPosition = hitTestResult.worldTransform
        dump(objectNode)
    }
    // Method to add the AR object
    private func addArText() {
        let textGeometry = SCNText(string: "Hello World", extrusionDepth: 1.0)
        textGeometry.firstMaterial?.diffuse.contents = UIColor.black

        let textNode = SCNNode(geometry: textGeometry)
        textNode.scale = SCNVector3(-0.01, 0.01, 0.01) // 크기 조정

        // 화면 중앙의 hitTest 수행
        let centerPoint = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)

        if let (distance, angle) = performHitTesting(centerPoint) {
            findShelfLabel?.text = "\(distance) : \(angle)"
            if distance < 1.0 {
                textNode.scale = SCNVector3(0.01, 0.01, 0.01) // 크기 조정
            }
        }
        let hitTestResults = arView.hitTest(centerPoint, types: .featurePoint)

        if let closestResult = hitTestResults.first {
            // hitTest 결과로 얻은 위치에 텍스트 배치
            let transform = closestResult.worldTransform
            let position = SCNVector3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
            textNode.position = position

            // 카메라의 현재 방향 얻기
            if let cameraTransform = arView.session.currentFrame?.camera.transform {
                let cameraOrientation = SCNVector3(-cameraTransform.columns.2.x, -cameraTransform.columns.2.y, -cameraTransform.columns.2.z)
                let cameraPosition = SCNVector3(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
                let direction = SCNVector3(cameraOrientation.x + cameraPosition.x, cameraOrientation.y + cameraPosition.y, cameraOrientation.z + cameraPosition.z)
                
                textNode.look(at: direction)
            }

            // 텍스트 노드를 ARSCNView의 루트 노드에 추가
            self.arView.scene.rootNode.addChildNode(textNode)
            self.arTextNodes.append(textNode)
        } else {
            print("Hit test 결과가 없습니다.")
            // 필요한 경우 표면을 찾지 못했을 때 처리
        }
    }

    // 선택된 텍스트 식별 및 정보 출력 함수
    private func updateSelectedTextNode() {
        let screenWidth = CGFloat(arView.bounds.width)
        let screenHeight = CGFloat(arView.bounds.height)
        let currentTime = Date()

        // 중앙 그리드 셀 위치 계산
        let centerX = screenWidth / 2
        let centerY = screenHeight / 2
        let cellWidth = screenWidth / 3
        let cellHeight = screenHeight / 3

        selectedTextNode = nil
        var minDistance: Float = Float.greatestFiniteMagnitude

        for textNode in arTextNodes {
            let textScreenPosition = arView.projectPoint(textNode.position)

            // 중앙 그리드 셀에 있는 노드만 고려
            if abs(Float(textScreenPosition.x) - Float(centerX)) <= Float(cellWidth) / 2 && 
            abs(Float(textScreenPosition.y) - Float(centerY)) <= Float(cellHeight) / 2 {
                let distance = calculateDistanceARContents(fromCameraTo: textNode.position)
                if distance < minDistance {
                    minDistance = distance
                    selectedTextNode = textNode
                }
            }
        }

        if let selectedNode = selectedTextNode, let text = (selectedNode.geometry as? SCNText)?.string as? String {
            // 마지막으로 읽은 텍스트와 현재 텍스트가 다르고, 마지막 읽은 시간으로부터 2초가 경과했는지 확인
            if text != lastReadText || lastReadTime == nil || currentTime.timeIntervalSince(lastReadTime!) >= 10 {
                TTSManager.shared.play("\(text), Distance: \(minDistance)")
                lastReadText = text
                lastReadTime = currentTime
            }
        }
    }


    
    // SCNVector3의 연산자 오버로딩을 클래스 내부에 추가
    private func subtract(_ left: SCNVector3, _ right: SCNVector3) -> SCNVector3 {
        return SCNVector3Make(left.x - right.x, left.y - right.y, left.z - right.z)
    }
}
