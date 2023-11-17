import Flutter
import UIKit
import ARKit
import Photos
import Metal

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
class FLNativeView: NSObject, FlutterPlatformView, ARSCNViewDelegate {
    // 기본적인 네이티브 iOS 뷰
    private var arView: ARSCNView

    // 거리
    private var distanceLabel: UILabel!

     // 뷰의 프레임, 뷰 식별자, 선택적 인자, 그리고 바이너리 메신저를 사용하여 네이티브 뷰를 초기화
    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger?
    ) {
        // Metal 디바이스 생성
        guard let metalDevice = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }

        // ARSCNView 인스턴스 생성 및 초기화
        arView = ARSCNView(frame: frame, options: [SCNView.Option.preferredDevice.rawValue: metalDevice])

        super.init()

        // setupARView 호출하여 AR뷰를 설정
        setupARView()

        // 거리 표시용 UILabel 설정
        setupDistanceLabel()

        // 화면 터치 감지를 위한 탭 제스처 추가
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        arView.addGestureRecognizer(tapGesture)
    }

    deinit {
        // ARSession을 일시정지시키는 코드
        arView.session.pause()
    }

    // Tap 하면 실행
    @objc func handleTap(_ sender: UITapGestureRecognizer) {
        if sender.state == .ended {
            // 스크린샷 캡처 및 저장
            captureAndSaveImage()
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

    // 거리 표시용 UILabel 설정
    private func setupDistanceLabel() {
        distanceLabel = UILabel(frame: CGRect(x: 20, y: arView.safeAreaInsets.top + 20, width: 200, height: 40))
        distanceLabel.textColor = .white
        distanceLabel.backgroundColor = .black.withAlphaComponent(0.5)
        distanceLabel.text = "거리 측정"
        arView.addSubview(distanceLabel)
    }

     // ARSCNViewDelegate 메서드
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        DispatchQueue.main.async {
            print("rendering")
            self.updateDistanceDisplay()
        }
    }

    private func updateDistanceDisplay() {
        // 화면 중앙 좌표 얻기
        let screenCenter = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)

        // 화면 중앙의 3D 좌표 찾기
        guard let hitTestResults = arView.hitTest(screenCenter, types: .featurePoint).first else { return }
        let hitPoint = hitTestResults.worldTransform


        // 카메라 위치 얻기
        guard let currentFrame = arView.session.currentFrame else { return }
        let cameraPosition = currentFrame.camera.transform

        // 거리 계산
        let distance = calculateDistance(from: cameraPosition, to: hitPoint)

        // 거리 정보를 ARView에 표시
        self.distanceLabel.text = String(format: "%.2f meters", distance)
    }

    private func captureAndSaveImage() {
        // 스크린샷 캡처
        let snapshot = arView.snapshot()

        // 사진 라이브러리에 접근 권한 요청
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                // 사진 갤러리에 이미지 저장
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAsset(from: snapshot)
                }, completionHandler: { success, error in
                    if success {
                        // 저장 성공
                        print("Image saved successfully.")
                    } else {
                        // 저장 실패
                        print("Error saving image: \(String(describing: error))")
                    }
                })
            }
        }
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
        arView.delegate = self
    }
}
