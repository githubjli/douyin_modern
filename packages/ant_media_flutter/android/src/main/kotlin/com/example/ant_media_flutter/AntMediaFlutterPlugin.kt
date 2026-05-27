package com.example.ant_media_flutter

import io.flutter.embedding.engine.plugins.FlutterPlugin

/**
 * Stub plugin class — ant_media_flutter is a pure-Dart package that delegates
 * all native work to flutter_webrtc, permission_handler, and flutter_background.
 * This class exists only so Flutter's plugin registration tooling can find the
 * class declared in pubspec.yaml.
 */
class AntMediaFlutterPlugin : FlutterPlugin {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        // No platform channels needed — all functionality is pure Dart.
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        // Nothing to release.
    }
}
