Pod::Spec.new do |s|
  s.name             = 'EventTrackingSDK'
  s.version          = '1.0.0'
  s.summary          = 'A comprehensive event tracking SDK for iOS'
  s.description      = <<-DESC
                       A complete event tracking SDK with automatic page tracking, exposure tracking, session management, and more.
                       Features include: auto page tracking, exposure tracking, session management, sampling, interceptor chain, and batch upload.
                       DESC
  s.homepage         = 'https://github.com/yourusername/EventTrackingSDK'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Your Name' => 'your@email.com' }
  s.source           = { :git => 'https://github.com/yourusername/EventTrackingSDK.git', :tag => s.version.to_s }
  s.ios.deployment_target = '13.0'
  s.swift_version    = '5.0'
  s.source_files     = 'Sources/EventTrackingSDK/**/*'
  s.framework        = 'UIKit'
end
