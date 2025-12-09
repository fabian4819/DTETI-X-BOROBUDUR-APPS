import Flutter
import UIKit
import CoreMotion

/// iOS Altimeter Plugin using Core Motion CMAltimeter
/// Provides high-accuracy relative altitude tracking (~1-3m accuracy)
class AltimeterPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private let altimeter = CMAltimeter()
    private var eventSink: FlutterEventSink?
    private let operationQueue = OperationQueue()
    
    // Plugin registration
    static func register(with registrar: FlutterPluginRegistrar) {
        let methodChannel = FlutterMethodChannel(
            name: "com.borobudur.app/altimeter",
            binaryMessenger: registrar.messenger()
        )
        let eventChannel = FlutterEventChannel(
            name: "com.borobudur.app/altimeter_stream",
            binaryMessenger: registrar.messenger()
        )
        
        let instance = AltimeterPlugin()
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        eventChannel.setStreamHandler(instance)
    }
    
    // Handle method calls
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isAvailable":
            result(CMAltimeter.isRelativeAltitudeAvailable())
            
        case "authorizationStatus":
            if #available(iOS 11.0, *) {
                let status = CMAltimeter.authorizationStatus()
                result(authorizationStatusToString(status))
            } else {
                result("authorized") // Pre-iOS 11 doesn't have authorization
            }
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // Start streaming altitude updates
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        
        // Check if altimeter is available
        guard CMAltimeter.isRelativeAltitudeAvailable() else {
            events(FlutterError(
                code: "UNAVAILABLE",
                message: "CMAltimeter is not available on this device",
                details: "Device must have M-series coprocessor (iPhone 6+)"
            ))
            return nil
        }
        
        // Start altitude updates
        altimeter.startRelativeAltitudeUpdates(to: operationQueue) { [weak self] (altitudeData, error) in
            guard let self = self else { return }
            
            if let error = error {
                events(FlutterError(
                    code: "ALTITUDE_ERROR",
                    message: error.localizedDescription,
                    details: nil
                ))
                return
            }
            
            guard let data = altitudeData else { return }
            
            // Send altitude data to Flutter
            let altitudeInfo: [String: Any] = [
                "relativeAltitude": data.relativeAltitude.doubleValue, // in meters
                "pressure": data.pressure.doubleValue * 10.0, // convert kPa to hPa
                "timestamp": Date().timeIntervalSince1970 * 1000 // milliseconds
            ]
            
            events(altitudeInfo)
        }
        
        return nil
    }
    
    // Stop streaming altitude updates
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        altimeter.stopRelativeAltitudeUpdates()
        eventSink = nil
        return nil
    }
    
    // Helper: Convert authorization status to string
    @available(iOS 11.0, *)
    private func authorizationStatusToString(_ status: CMAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return "notDetermined"
        case .restricted:
            return "restricted"
        case .denied:
            return "denied"
        case .authorized:
            return "authorized"
        @unknown default:
            return "unknown"
        }
    }
}
