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
        
        channel.setMethodCallHandler { [weak self] call, result in
            switch call.method {
            case "getBatteryLevel":
                self?.getBatteryLevel(result: result)
            default:
              result(FlutterMethodNotImplemented)
            }
            
        }
    }
    
    func getBatteryLevel(result: FlutterResult) {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        
        guard device.batteryState != .unknown else {
            result(FlutterError(code: "UNAVAILABLE", message: "Battery level not available", details: nil))
            return
        }
        
        result(Int(device.batteryLevel * 100))
        
    }
    
}
