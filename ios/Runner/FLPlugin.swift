import Flutter
import UIKit

@available(iOS 16.0, *)
class FLPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        // FLNativeViewFactory 인스턴스를 <platform-view-type>라는 메세지(ID)와 함께 등록함.
        // Flutter 앱이 Native 앱을 쓸 수 있게 해주는 동작.
        let factory = FLNativeViewFactory(messenger: registrar.messenger())
        registrar.register(factory, withId: "<platform-view-type>")
    }
}

