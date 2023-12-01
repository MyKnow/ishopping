import UIKit
import Flutter

@available(iOS 17.0, *)
@UIApplicationMain
class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        guard let registrar = self.registrar(forPlugin: "plugin-name") else { return false }

        let productViewFactory = FLNativeViewFactory(messenger: registrar.messenger(), viewType: "product_view")
        registrar.register(productViewFactory, withId: "product_view")

        let sectionViewFactory = FLNativeViewFactory(messenger: registrar.messenger(), viewType: "section_view")
        registrar.register(sectionViewFactory, withId: "section_view")

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
