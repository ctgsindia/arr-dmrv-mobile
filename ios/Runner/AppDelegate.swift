import UIKit
import Flutter

/// iOS app entry point for ARR DMRV.
/// FlutterAppDelegate handles Flutter engine lifecycle and plugin registration.
/// All platform-specific plugins (geolocator, camera, etc.) are auto-registered
/// by GeneratedPluginRegistrant — no manual registration needed in Phase 1.
@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
