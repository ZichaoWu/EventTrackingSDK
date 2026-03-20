Pod::Spec.new do |s|
  s.name             = 'EventTrackingSDK'
  s.version          = '0.0.1'
  s.summary          = 'A lightweight event tracking SDK for iOS.'
  
  s.description      = <<-DESC
A lightweight and flexible event tracking SDK, supporting custom event logging,
batch upload, and analytics integration.
                       DESC

  s.homepage         = 'https://github.com/ZichaoWu/EventTrackingSDK'
  
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  
  s.author           = { 'ZichaoWu' => 'your_email@example.com' }
  
  s.source           = { 
    :git => 'https://github.com/ZichaoWu/EventTrackingSDK.git', 
    :tag => s.version.to_s 
  }

  s.ios.deployment_target = '11.0'
  
  s.source_files = 'EventTrackingSDK/Classes/**/*'
  
  s.swift_version = '5.0'
end