//
//  HumanDetectionManager.swift
//  Runner
//
//  Created by 정민호 on 11/24/23.
//

import UIKit
import Vision
import ARKit

@available(iOS 13.0, *)
class HumanDetectionManager {
    var requests = [VNRequest]()

    init() {
        setupVision()
    }
    
    private func setupVision() {
        let request = VNDetectHumanRectanglesRequest { [weak self] request, error in
            self?.handleDetection(request: request, error: error)
        }
        requests = [request]
    }

    private func handleDetection(request: VNRequest, error: Error?) {
        // 결과 처리 코드
    }

    // 필요에 따라 추가 메서드 구현
}
