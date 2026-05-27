Pod::Spec.new do |s|
  s.name             = 'ant_media_flutter'
  s.version          = '1.5.4'
  s.summary          = 'Flutter plugin for Ant Media Server WebRTC streaming.'
  s.description      = <<-DESC
Stub podspec — ant_media_flutter is a pure-Dart package. All native work is
handled by flutter_webrtc, permission_handler, and flutter_background.
                       DESC
  s.homepage         = 'https://github.com/ant-media/WebRTC-Flutter-SDK'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Ant Media' => 'contact@antmedia.io' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '12.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version    = '5.0'
end
