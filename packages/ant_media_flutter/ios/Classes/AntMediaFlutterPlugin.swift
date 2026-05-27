import Flutter
import UIKit

/// Stub plugin class — ant_media_flutter is a pure-Dart package that delegates
/// all native work to flutter_webrtc, permission_handler, and flutter_background.
/// This class exists only so Flutter's plugin registration tooling can find the
/// class declared in pubspec.yaml.
public class AntMediaFlutterPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        // No platform channels needed — all functionality is pure Dart.
    }
}
