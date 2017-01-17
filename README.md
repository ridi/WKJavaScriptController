# WKJavaScriptController
Calling native code from Javascript in iOS likes JavascriptInterface in Android.

## Requirements
- Xcode 7.3+
- Swift 2.3
- iOS8+

## Installation
This library is distributed by [CocoaPods](https://cocoapods.org).

 CocoaPods is a dependency manager for Cocoa projects. You can install it with the following command:
 
```
$ gem install cocoapods
```

To integrate WKJavaScriptController into your Xcode project using CocoaPods, specify it in your Podfile:

```
source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '8.0'
use_frameworks!

target '<Target name in your project>' do
    pod 'WKJavaScriptController'
end

// If using Xcode 8.
post_install do |installer|
   	installer.pods_project.targets.each do |target|
       	target.build_configurations.each do |configuration|
           	configuration.build_settings['SWIFT_VERSION'] = "2.3"
       	end
   	end
end

```

Then, run the following command:

```
$ pod install
```
