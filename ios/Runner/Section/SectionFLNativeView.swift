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
import SceneKit

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

    private var overlayView: UIView?

    // Add properties to track the AR object and its position
    private var arObjectNode: SCNNode?
    private var arObjectPosition: simd_float4x4?

    // 텍스트 노드와 관련된 정보를 저장할 구조체
    struct TextNodeInfo {
        var node: SCNNode
        var firstVisibleTime: Date?
    }
    // 텍스트 노드 관련 정보를 저장하는 배열
    private var textNodeInfos: [TextNodeInfo] = []

    var sectionPredictions: [String] = []
    var sectionBest: [String] = []

    private var labelText: String = "매대 찾기"

    // 마지막으로 읽은 텍스트와 시간을 저장하는 변수 추가
    private var lastReadText: String?
    private var lastReadTime: Date?

    private var findShelfLabel: UILabel?

    // 선택된 텍스트 노드
    private var selectedTextNode: SCNNode?
    private var selectMode: Bool = false;

    // AR 세션 구성 및 시작
    private let configuration = ARWorldTrackingConfiguration()

    private var selectSection: String?

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


    private var gridWorldCoordinates: [SCNVector3] = []
    private var selectCoord: SCNVector3 = SCNVector3(0, 0, 0) // 초기 좌표값 설정


    // 타이머를 클래스 프로퍼티로 추가
    private var monitoringTimer: Timer?

    private var isGoMode: Bool = false
    private var willFind: Bool = false
    
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
        setupGridDots()
        addShortPressGesture()
        addLongPressGesture()
        addSwipeGesture()
    }
    deinit {
        // 타이머를 무효화
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        TTSManager.shared.stop()
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
        if self.selectMode {
            self.willFind = false
            self.selectSection = self.sectionBest[1]
            self.selectCoord = self.gridWorldCoordinates[1]
            self.addArText()
        } else {
            //let screenCenter = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
            //addArText()
            findSection()
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
            if self.willFind {
                sendDataToFlutter()
                ARSessionManager.shared.pauseSession()
            } else {
                TTSManager.shared.play("길게 누름")
                hapticC.notificationFeedback(style: "success")
                sendShoppingbagToFlutter()
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
        TTSManager.shared.stop()
        hapticC.impactFeedback(style: "Heavy")
        switch gesture.direction {
        case .left: // 무언갈 진행하는 것
            TTSManager.shared.play("왼쪽")
            if self.selectMode {
                self.selectMode = false
                TTSManager.shared.play("취소")
            }
            break
        case .right: // 무언갈 취소하는 것
            TTSManager.shared.play("오른쪽")
            break
        case .up: // 무언갈 더하는 것
            TTSManager.shared.play("위")
            if self.selectMode {
                self.selectSection = self.sectionBest[0]
                self.selectCoord = self.gridWorldCoordinates[0]
                self.selectMode = false
                self.addArText()
            }
            break
        case .down: // 무언갈 빼는 것
            TTSManager.shared.play("아래")
            if self.selectMode {
                self.selectSection = self.sectionBest[2]
                self.selectCoord = self.gridWorldCoordinates[2]
                self.selectMode = false
                self.addArText()
            }
            break
        default:
            break
        }
        // 여기에 각 방향에 따른 추가적인 작업 수행
    }

    private func sendDataToFlutter() {
        let data: [String: Any] = [
            "predictionValue": self.predictionValue,
            "shoppingbag": self.shoppingBasketMap // 예시 데이터
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
    private func calculateDistanceARContents2D(fromCameraTo nodePosition: SCNVector3) -> Float {
        guard let cameraTransform = arView.session.currentFrame?.camera.transform else {
            return Float.greatestFiniteMagnitude
        }
        let cameraPosition = SCNVector3(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
        
        // 2D 평면에서의 거리를 계산합니다 (x와 z 좌표만 고려)
        let deltaX = cameraPosition.x - nodePosition.x
        let deltaZ = cameraPosition.z - nodePosition.z
        
        // 거리를 계산하여 반환합니다.
        return sqrt(deltaX * deltaX + deltaZ * deltaZ)
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

    func calculateAngleBetweenCameraAndArText(_ cameraTransform: simd_float4x4, _ arTextNodePosition: SCNVector3) -> Float {
        // 카메라 위치
        let cameraPosition = SCNVector3(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)

        // ARText의 위치에서 카메라 위치를 빼서 방향 벡터를 계산합니다.
        let direction = SCNVector3Make(arTextNodePosition.x - cameraPosition.x, arTextNodePosition.y - cameraPosition.y, arTextNodePosition.z - cameraPosition.z)

        // 카메라의 전방 벡터
        let forward = SCNVector3(-cameraTransform.columns.2.x, -cameraTransform.columns.2.y, -cameraTransform.columns.2.z)

        // 수평 각도만 계산
        let directionHorizontal = SCNVector3(direction.x, 0, direction.z)
        let forwardHorizontal = SCNVector3(forward.x, 0, forward.z)

        // 내적을 사용하여 각도를 계산
        let dotProduct = dot(directionHorizontal.normalized(), forwardHorizontal.normalized())
        var angleRadians = acos(min(max(dotProduct, -1.0), 1.0))

        // 스마트폰 각도에 따라 달라짐
        if UIDevice.current.orientation.isPortrait { 
            // 카메라 아래쪽 벡터
            let down = SCNVector3(cameraTransform.columns.1.x, cameraTransform.columns.1.y, cameraTransform.columns.1.z)

            // 왼쪽 또는 오른쪽에 있는지 확인
            let isLeft = dot(directionHorizontal, down) < 0
            if isLeft {
                angleRadians *= -1
            }
        //} else if UIDevice.current.orientation.isLandscape { 
        } else { 
            // 카메라의 오른쪽 벡터 계산
            let right = SCNVector3(cameraTransform.columns.0.x, cameraTransform.columns.0.y, cameraTransform.columns.0.z)

            // 왼쪽 또는 오른쪽에 있는지 확인
            let isLeft = dot(directionHorizontal, right) < 0
            if isLeft {
                angleRadians *= -1
            }
        }

        // 라디안을 도로 변환
        return angleRadians * (180.0 / Float.pi)
    }

    func dot(_ vector1: SCNVector3, _ vector2: SCNVector3) -> Float {
        return vector1.x * vector2.x + vector1.y * vector2.y + vector1.z * vector2.z
    }

    private func setupGridDots() {
        let dotSize: CGFloat = 10
        let labelHeight: CGFloat = 20
        let labelWidth: CGFloat = 100
        let labelBackgroundOpacity: CGFloat = 0.5
        let labelCornerRadius: CGFloat = 10
        let labelTextColor: UIColor = .red
        let labelFont: UIFont = UIFont.boldSystemFont(ofSize: 14)
        
        let screenWidth = arView.bounds.width
        let screenHeight = arView.bounds.height
        let sectionWidth = screenWidth / CGFloat(col)
        let sectionHeight = screenHeight / CGFloat(rw)

        for row in 0..<rw {
            for column in 0..<col {
                let x = CGFloat(column) * sectionWidth + sectionWidth / 2
                let y = CGFloat(row) * sectionHeight + sectionHeight / 2

                // 점 생성
                let dot = UIView(frame: CGRect(x: x - dotSize / 2, y: y - dotSize / 2, width: dotSize, height: dotSize))
                dot.backgroundColor = .red
                dot.layer.cornerRadius = dotSize / 2
                arView.addSubview(dot)
                gridDots.append(dot)

                // 레이블 생성
                let label = UILabel(frame: CGRect(x: x - labelWidth / 2, y: y - labelHeight / 2, width: labelWidth, height: labelHeight))
                label.text = "\(row * col + column + 1)" // 1부터 9까지의 숫자
                label.textAlignment = .center
                label.textColor = labelTextColor
                label.backgroundColor = .black.withAlphaComponent(labelBackgroundOpacity)
                label.adjustsFontSizeToFitWidth = true // 텍스트 크기를 라벨 너비에 맞게 조정
                label.layer.cornerRadius = labelCornerRadius
                label.layer.masksToBounds = true
                label.font = labelFont
                arView.addSubview(label)
                gridLabels.append(label)
            }
        }
    }

    // ARSCNViewDelegate 메서드
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        DispatchQueue.main.async {
            self.updateGridDotsPosition()
            //self.updateDistanceDisplay()
            self.drawGridLines()
            self.addFindShelfLabel()

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

            // 카메라와의 거리가 1m 이내이고, 1초 이상 화면에 보이는 텍스트 노드를 찾아 제거
            for (index, textNodeInfo) in self.textNodeInfos.enumerated().reversed() {
                let distance = self.calculateDistanceARContents(fromCameraTo: textNodeInfo.node.position)
                
                if distance < 1.0 {
                    // 텍스트 노드 제거
                    textNodeInfo.node.removeFromParentNode()
                    self.textNodeInfos.remove(at: index)
                }
            }
        }
    }

    private func updateGridDotsPosition() {
        let screenWidth = arView.bounds.width
        let screenHeight = arView.bounds.height
        let sectionWidth = screenWidth / CGFloat(col)
        let sectionHeight = screenHeight / CGFloat(rw)

        for (index, dot) in gridDots.enumerated() {
            let rowIndex = index / col // 가로 줄 개수로 나눔
            let columnIndex = index % col // 가로 줄 개수로 나머지 연산

            let x = CGFloat(columnIndex) * sectionWidth + sectionWidth / 2
            let y = CGFloat(rowIndex) * sectionHeight + sectionHeight / 2
            dot.center = CGPoint(x: x, y: y)

            // 레이블 위치와 텍스트 업데이트
            let label = gridLabels[index]
            label.center = CGPoint(x: x, y: y + dot.frame.size.height + 10) // 10은 점과 레이블 사이의 간격입니다
            
            // 예측값을 포함한 텍스트 설정
            let predictionText = index < sectionPredictions.count ? sectionPredictions[index] : "N/A"
            label.text = "번호 \(index + 1): \(predictionText)"
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
    private func addArText() {
        // 텍스트 지오메트리 생성
        let sectionText: String
        if let section = self.selectSection {
            sectionText = "↓ \(section)" // selectSection이 nil이 아닐 경우
        } else {
            sectionText = "섹션 없음" // selectSection이 nil일 경우 대체 텍스트
        }
        let textGeometry = SCNText(string: sectionText, extrusionDepth: 1.0)

        textGeometry.firstMaterial?.diffuse.contents = UIColor.red

        let textNode = SCNNode(geometry: textGeometry)
        textNode.scale = SCNVector3(-0.01, 0.01, 0.02) // 크기 조정

        // 이미 저장된 좌표에 텍스트 노드 위치 설정
        textNode.position = self.selectCoord

        // 카메라의 현재 방향 얻기
        if let cameraTransform = arView.session.currentFrame?.camera.transform {
            let cameraOrientation = SCNVector3(-cameraTransform.columns.2.x, -cameraTransform.columns.2.y, -cameraTransform.columns.2.z)
            let cameraPosition = SCNVector3(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
            let direction = SCNVector3(cameraOrientation.x + cameraPosition.x, cameraOrientation.y + cameraPosition.y, cameraOrientation.z + cameraPosition.z)
            
            textNode.look(at: direction)
        }

        // 텍스트 노드 정보 추가
        let textNodeInfo = TextNodeInfo(node: textNode, firstVisibleTime: nil)
        self.textNodeInfos.append(textNodeInfo)

        // 텍스트 노드를 ARSCNView의 루트 노드에 추가
        self.arView.scene.rootNode.addChildNode(textNode)
        self.isGoMode = true

        self.monitorDistanceToSection()
    }
    
    // SCNVector3의 연산자 오버로딩을 클래스 내부에 추가
    private func subtract(_ left: SCNVector3, _ right: SCNVector3) -> SCNVector3 {
        return SCNVector3Make(left.x - right.x, left.y - right.y, left.z - right.z)
    }

    // findSection 함수
    func findSection() {
        sectionPredictions.removeAll()
        sectionBest.removeAll()
        guard let currentFrame = ARSessionManager.shared.session.currentFrame else {
            print("현재 프레임을 가져올 수 없습니다.")
            return
        }

        self.hitTestForGrids(in: currentFrame)

        do {
            let classifier = try SectionClassifier(rows: rw, columns: col)
            classifier.classifySections(in: currentFrame) { predictions in
                self.sectionPredictions = predictions
                
                // 예측 결과를 그룹화
                let groupedPredictions = self.groupPredictions(predictions)
                let bestPredict = self.findBestPredictions(in: groupedPredictions)
                
                // 가장 많은 예측 결과를 가진 섹션을 음성으로 출력
                for (index, prediction) in bestPredict.enumerated() {
                    if prediction != "" {
                        TTSManager.shared.play("\(index + 1)번째: \(prediction)")
                    }
                }

                self.sectionBest = bestPredict
                self.sectionSelector()
            }
        } catch {
            print("분류기 초기화 중 오류 발생: \(error)")
        }
    }

    // 4, 5, 6번 그리드의 중심에 대한 hitTest를 수행하고 결과를 저장하는 함수
    private func hitTestForGrids(in frame: ARFrame) {
        let gridIndices = [3, 4, 5] // 4, 5, 6번 그리드 인덱스
        gridWorldCoordinates.removeAll()

        for index in gridIndices {
            let dotView = gridDots[index]
            let screenPoint = CGPoint(x: dotView.center.x, y: dotView.center.y)
            
            if let hitTestResult = arView.hitTest(screenPoint, types: .featurePoint).first {
                let worldPosition = SCNVector3(
                    hitTestResult.worldTransform.columns.3.x,
                    hitTestResult.worldTransform.columns.3.y,
                    hitTestResult.worldTransform.columns.3.z
                )
                gridWorldCoordinates.append(worldPosition)
            }
        }
    }

    // 예측 결과를 그룹화하는 함수
    private func groupPredictions(_ predictions: [String]) -> [[String]] {
        var groups: [[String]] = Array(repeating: [], count: 3) // 3개의 그룹

        for (index, prediction) in predictions.enumerated() {
            let groupIndex = index % 3
            groups[groupIndex].append(prediction)
        }

        return groups
    }

    // 각 그룹에서 가장 많은 예측 결과를 가진 섹션을 찾는 함수
    private func findBestPredictions(in groups: [[String]]) -> [String] {
        var bestPredicts: [String] = []

        for group in groups {
            let grouped = Dictionary(grouping: group, by: { $0 })
            let sorted = grouped.sorted { $0.value.count > $1.value.count }
            
            if let bestPrediction = sorted.first, bestPrediction.value.count == 1 {
                let simplifiedGroup = group.map { $0.components(separatedBy: CharacterSet.decimalDigits).first ?? "" }
                let simpleGrouped = Dictionary(grouping: simplifiedGroup, by: { $0 })
                let simpleSorted = simpleGrouped.sorted { $0.value.count > $1.value.count }

                if let simpleBestPrediction = simpleSorted.first, simpleBestPrediction.value.count == 1 {
                    bestPredicts.append("")
                } else {
                    bestPredicts.append("\(simpleSorted.first?.key ?? "")1")
                }
            } else {
                bestPredicts.append(sorted.first?.key ?? "")
            }
        }

        return bestPredicts
    }

    private func showOverlay(isLeftSide: Bool, color: UIColor) {
        let overlayWidth = self.arView.bounds.width / 2
        let overlayHeight = self.arView.bounds.height

        // 오버레이 뷰가 이미 있다면 제거
        overlayView?.removeFromSuperview()

        // 오버레이 뷰 생성
        overlayView = UIView(frame: CGRect(x: isLeftSide ? 0 : overlayWidth, y: 0, width: overlayWidth, height: overlayHeight))
        overlayView?.backgroundColor = color
        overlayView?.alpha = 0.5 // 반투명
        self.arView.addSubview(overlayView!)

        // 오버레이 뷰를 빠르게 표시했다가 사라지게 함
        UIView.animate(withDuration: 0.5, animations: {
            self.overlayView?.alpha = 0
        }) { _ in
            self.overlayView?.removeFromSuperview()
        }
    }



    // 기존의 monitorDistanceToSection 함수 수정
    func monitorDistanceToSection() {
        guard selectSection != nil else { return }

        // 타이머가 이미 실행 중인 경우 중지
        if monitoringTimer != nil {
            monitoringTimer?.invalidate()
            monitoringTimer = nil
        }

        // 3초마다 반복되는 타이머 설정
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            guard let self = self, let currentFrame = ARSessionManager.shared.session.currentFrame else {
                timer.invalidate()
                return
            }

            let cameraTransform = currentFrame.camera.transform
            let cameraPosition = SCNVector3(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
            let distance = self.calculateDistanceARContents(fromCameraTo: self.selectCoord)
            let angle = self.calculateAngleBetweenCameraAndArText(cameraTransform, self.selectCoord)

            // 각도 계산을 위한 추가적인 로직 필요

            // 거리가 N m 미만이면 완료
            if distance < 1.0 {
                self.selectMode = false
                self.isGoMode = false
                self.willFind = true
                timer.invalidate()
                TTSManager.shared.stop()
                TTSManager.shared.play("목표에 도달했습니다. 몸을 돌리고 화면을 터치하여 다른 매대를 찾거나, 화면을 길게 눌러 매대에서 제품을 찾으십시오")
                self.predictionValue = self.selectSection!
            } else {
                TTSManager.shared.stop()
                TTSManager.shared.play("\(String(format: "%.1f", distance))미터")

                // 경고 표시 로직
                if angle <= -5 {
                    self.showOverlay(isLeftSide: true, color: UIColor.red)
                    TTSManager.shared.play("\(String(format: "왼쪽"))")
                } else if angle >= 5 {
                    self.showOverlay(isLeftSide: false, color: UIColor.blue)
                    TTSManager.shared.play("\(String(format: "오른쪽"))")
                } else {
                    // 해당되지 않는 경우 오버레이 제거
                    self.overlayView?.removeFromSuperview()
                    TTSManager.shared.play("\(String(format: "직진"))")
                }
            }
        }
    }


    func sectionSelector() {
        self.selectMode = true
        var array = self.sectionBest
        if array.isEmpty || self.gridWorldCoordinates.isEmpty {
            TTSManager.shared.play("다시 터치해주십시오")
            self.selectMode = false
        } else {
            if array[0] != "" {
                TTSManager.shared.play("\(array[0])로 가려면 위로 스와이프")
            }
            if array[1] != "" {
                TTSManager.shared.play("\(array[1])로 가려면 터치 ")
            }
            if array[2] != "" {
                TTSManager.shared.play("\(array[2])로 가려면 아래로 스와이프")
            }
        }
    }
}

// selectCoord의 simdTransform 프로퍼티를 생성하는 확장 함수
extension SCNVector3 {
    var simdTransform: matrix_float4x4 {
        return matrix_float4x4(columns: (
            simd_float4(x, 0, 0, 0),
            simd_float4(0, y, 0, 0),
            simd_float4(0, 0, z, 0),
            simd_float4(0, 0, 0, 1)
        ))
    }
    func normalized() -> SCNVector3 {
        let length = sqrt(self.x * self.x + self.y * self.y + self.z * self.z)
        guard length != 0 else {
            return SCNVector3(0, 0, 0)
        }
        return SCNVector3(self.x / length, self.y / length, self.z / length)
    }
}
