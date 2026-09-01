import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
    
    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
        
        let channel = FlutterMethodChannel(
            name: "devicelab/device_info",
            binaryMessenger: engineBridge.applicationRegistrar.messenger()
        )
        
        channel.setMethodCallHandler {call, result in
            switch call.method {
            case "ping":
              result("pong from native iOS")
            default:
              result(FlutterMethodNotImplemented)
            }
            
        }
    }
    
}
