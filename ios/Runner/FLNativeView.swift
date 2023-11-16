import Flutter
import UIKit
import ARKit

// Fluter에서 사용자 정의 플랫폼 뷰를 생성하는 데 필요함
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
class FLNativeView: NSObject, FlutterPlatformView {
    // 기본적인 네이티브 iOS 뷰
    private var arView: ARSCNView

    // 뷰의 프레임, 뷰 식별자, 선택적 인자, 그리고 바이너리 메신저를 사용하여 네이티브 뷰를 초기화
    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger?
    ) {
        arView = ARSCNView(frame: frame)
        super.init()
        // setupARView 호출하여 AR뷰를 설정
        setupARView()
    }

    // 기본 UIView 객체를 반환
    func view() -> UIView {
        return arView
    }

    // ARView를 설정
    private func setupARView() {
        // AR 세션 구성 및 시작
        let configuration = ARWorldTrackingConfiguration()
        arView.session.run(configuration)
        
        // ARSCNView의 추가적인 설정 (예: 디버그 옵션, 델리게이트 설정 등)은 여기에서 수행합니다.
    }
}
