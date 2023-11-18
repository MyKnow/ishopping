import Flutter
import UIKit

@available(iOS 16.0, *)
@UIApplicationMain // 어노테이션으로 이 클래스가 iOS 애플리케이션의 진입점임을 나타냄.
@objc class AppDelegate: FlutterAppDelegate {
    // 애플리케이션이 시작된 후 추가 설정을 수행하기 위해 이 메소드를 오버라이드

    // 현재 실행 중인 앱
    // 앱이 시작될 때 전달되는 옵션을 포함하는 딕셔너리.
    // 앱이 시작된 이유와 관련된 다양한 키-값 쌍 포함 (알림을 통해 시작, URL을 통해 시작... etc)
    override func application(
      _ application: UIApplication,
      didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]?
    ) -> Bool {
      // Flutter 플러그인을 등록
      GeneratedPluginRegistrant.register(with: self)

      // "plugin-name"이라는 플러그인의 레지스트라(registrar)에 대한 약한 참조를 얻음. (plugin-name은 플레이스홀더 이름)
      weak var registrar = self.registrar(forPlugin: "plugin-name")

      // 인스턴스를 생성하고, 레지스트라로부터 얻은 메신저와 함께 초기화
      let factory = FLNativeViewFactory(messenger: registrar!.messenger())

      // 이 팩토리를 플러그인 레지스트라에 특정 플러그인 이름과 뷰 타입 식별자와 함께 등록
      self.registrar(forPlugin: "<plugin-name>")!.register(
        factory,
        withId: "<platform-view-type>")
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
