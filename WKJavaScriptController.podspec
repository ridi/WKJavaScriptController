Pod::Spec.new do |s|
  s.name         = 'WKJavaScriptController'
  s.version      = '1.1.1'
  s.summary      = 'Calling native code from Javascript in the iOS application likes JavascriptInterface in the Android.'
  s.homepage     = 'https://github.com/ridibooks/WKJavaScriptController'
  s.authors      = { 'Ridibooks Viewer Team' => 'viewer.team@ridi.com' }
  s.license      = 'Apache-2.0'
  s.ios.deployment_target = '8.0'
  s.source       = { :git => 'https://github.com/ridibooks/WKJavaScriptController.git', :tag => s.version }
  s.source_files = 'WKJavaScriptController/WKJavaScriptController.swift'
  s.frameworks   = 'Foundation', 'WebKit'
end
