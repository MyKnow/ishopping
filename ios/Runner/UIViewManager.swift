//
//  UIViewManager.swift
//  Runner
//
//  Created by 정민호 on 11/24/23.
//

import UIKit
import ARKit

@available(iOS 17.0, *)
class ViewController: UIViewController, ARSessionDelegate {
    // 기존 ViewController 코드 ...

    // 공유 ARSession 인스턴스 추가
    var session: ARSession?

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // 공유 ARSession을 사용하여 실행
        if let configuration = session?.configuration {
            print("!")
            session?.run(configuration)
        }
    } 
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        print("!")
        // 공유 ARSession 일시 정지
        session?.pause()
    }

    // 기타 필요한 메서드 ...
}

class UIViewManager {
    func createDotView() -> UIView {
        // Dot UIView 생성 및 설정
        let dot = UIView()
        // ...
        return dot
    }

    func createLabel() -> UILabel {
        // UILabel 생성 및 설정
        let label = UILabel()
        // ...
        return label
    }

    // 필요에 따라 추가 메서드 구현
}
