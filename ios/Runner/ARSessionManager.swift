//
//  ARSessionManager.swift
//  Runner
//
//  Created by 정민호 on 11/24/23.
//

import ARKit

@available(iOS 14.0, *)
class ARSessionManager {
    var session: ARSession
    
    init() {
        self.session = ARSession()
        setupSession()
    }
    
    private func setupSession() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.frameSemantics = .sceneDepth
        session.run(configuration)
    }

    // 세션 일시 정지
    func pauseSession() {
        session.pause()
    }

    // 필요에 따라 추가 메서드 구현
}
