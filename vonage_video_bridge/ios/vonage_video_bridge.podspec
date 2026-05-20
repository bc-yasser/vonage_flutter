Pod::Spec.new do |s|
  s.name             = 'vonage_video_bridge'
  s.version          = '0.1.0'
  s.summary          = 'Flutter bridge for the official native Vonage/OpenTok Video SDKs.'
  s.description      = 'Flutter platform-channel bridge using the official iOS Vonage/OpenTok Video SDK.'
  s.homepage         = 'https://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Team' => 'dev@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency 'OpenTok', '2.32.1'
  s.platform = :ios, '13.0'
  s.swift_version = '5.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
