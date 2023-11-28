//
//  ARSessionManager.swift
//  Runner
//
//  Created by 정민호 on 11/24/23.
//

import ARKit

@available(iOS 17.0, *)
class ARSessionManager {
    var session: ARSession
    var configuration: ARWorldTrackingConfiguration

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
        session.run(configuration)
        print("ARSession RUN")
    }

    func pauseSession() {
        session.pause()
        print("ARSession PAUSE")
    }
}
