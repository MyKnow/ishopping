import Flutter
import UIKit

// Fluter에서 사용자 정의 플랫폼 뷰를 생성하는 데 필요함
@available(iOS 17.0, *)
class FLNativeViewFactory: NSObject, FlutterPlatformViewFactory {
    private var messenger: FlutterBinaryMessenger
    private var viewType: String

    init(messenger: FlutterBinaryMessenger, viewType: String) {
        self.messenger = messenger
        self.viewType = viewType
        super.init()
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        return viewType == "product_view" ? ProductFLNativeView(frame: frame, viewIdentifier: viewId, arguments: args, binaryMessenger: messenger) : SectionFLNativeView(frame: frame, viewIdentifier: viewId, arguments: args, binaryMessenger: messenger)
    }

    public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}
