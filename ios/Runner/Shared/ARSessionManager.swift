//
//  ARSessionManager.swift
//  Runner
//
//  Created by 정민호 on 11/24/23.
//

import ARKit

@available(iOS 17.0, *)
class ARSessionManager {
    // 싱글톤 패턴
    static let shared = ARSessionManager()
    
    var session: ARSession
    var configuration: ARWorldTrackingConfiguration

    // 오버레이어 투명 정도
    private final var layerAlpha: CGFloat = 0.9

    // DepthMap View
    private var depthOverlayView: UIImageView?
    
    // Depth map 오버레이 상태를 추적하는 변수
    public var isDepthMapOverlayEnabled = false

    init() {
        session = ARSession()
        configuration = ARWorldTrackingConfiguration()

        // 4K 비디오 포맷 설정
        if let bestVideoFormat = ARWorldTrackingConfiguration.supportedVideoFormats.max(by: { $0.imageResolution.height < $1.imageResolution.height }) {
            configuration.videoFormat = bestVideoFormat
            print("HI-Res video format is supported and set.")
        } else {
            print("HI-Res video format is not supported on this device.")
        }

        // 여기에 AR 관련 추가 설정을 넣을 수 있습니다.
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics = .sceneDepth
        }
    }

    func runSession() {
        // AR 세션의 frame semantics 업데이트
        if isDepthMapOverlayEnabled {
            configuration.frameSemantics.insert(.sceneDepth)
        } else {
            configuration.frameSemantics.remove(.sceneDepth)
            depthOverlayView?.removeFromSuperview()
            depthOverlayView = nil
        }
        session.run(configuration)
        print("ARSession RUN")
    }

    func pauseSession() {
        session.pause()
        print("ARSession PAUSE")
    }

    func toggleDepthMap() {
        // Depth map 오버레이 상태 토글
        self.isDepthMapOverlayEnabled.toggle()
        self.runSession()
    }

    // Depth map 오버레이를 추가하는 메서드
    public func overlayDepthMap(_ arView: ARSCNView) {
        if let depthMap = arView.session.currentFrame?.sceneDepth?.depthMap {
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
}
