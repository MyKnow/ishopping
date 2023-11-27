//
//  HumanDetectionManager.swift
//  Runner
//
//  Created by 정민호 on 11/24/23.
//

import UIKit
import Vision
import ARKit

@available(iOS 15.0, *)
class HumanDetectionManager {
    // 의존성 주입을 위한 속성 추가
    weak var arView: ARSCNView?
    var indexDistance: [Float]
    var isVibrating: Bool
    var requests: [NSObject]

    let hapticM = HapticFeedbackManager

    init(arView: ARSCNView, indexDistance: [Float], isVibrating: Bool, requests: [NSObject]) {
        self.arView = arView
        self.indexDistance = indexDistance
        self.isVibrating = isVibrating
        self.requests = requests
        setupVision()
    }

    // 사람용 바운딩 박스 저장하는 배열
    private var humanBoundingBoxViews: [UIView] = []

    // 사람용 바운딩 박스와의 거리를 저장하는 배열
    private var distanceMeasurements: [Float] = []

    init() {
        setupVision()
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
                if let arView = self.arView {  // 옵셔널 언랩핑
                    let boundingBoxView = self.processBoundingBox(for: observation.boundingBox, in: arView)
                    arView.addSubview(boundingBoxView)
                    self.humanBoundingBoxViews.append(boundingBoxView)
                }
            }
        }
    }

    func processBoundingBox(for boundingBox: CGRect, in arView: ARSCNView) -> UIView  {
        // 화면 크기
        let screenSize = arView.bounds.size

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
        guard let arView = self.arView, let currentFrame = arView.session.currentFrame else {
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
                if let distance = indexDistance.first(where: { $0 > shortestDistance }) {
                    let timeInterval: TimeInterval = TimeInterval(distance)
                    triggerHapticFeedback(interval: timeInterval)
                }
            }
        }
    }

    func triggerHapticFeedback(interval: TimeInterval) {
        hapticM.notificationFeedback(style: "warning")
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
}
