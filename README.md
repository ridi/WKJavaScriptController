# WKJavaScriptController
Calling native code from Javascript in iOS likes JavascriptInterface in Android.

[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/WKJavaScriptController.svg?style=flat)](https://cocoadocs.org/docsets/WKJavaScriptController)
[![Platform](https://img.shields.io/cocoapods/p/WKJavaScriptController.svg?style=flat)](https://cocoadocs.org/docsets/WKJavaScriptController)
[![License](https://img.shields.io/cocoapods/l/WKJavaScriptController.svg?style=flat)](https://cocoadocs.org/docsets/WKJavaScriptController)

## Requirements
- Xcode 9.0+
- Swift 3
- iOS8+

(based on WKJavaScriptController 1.1.7+)

## Installation
This library is distributed by [CocoaPods](https://cocoapods.org).

 CocoaPods is a dependency manager for Cocoa projects. You can install it with the following command:

```
$ gem install cocoapods
```

To integrate WKJavaScriptController into your Xcode project using CocoaPods, specify it in your Podfile:

```ruby
source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '8.0'
use_frameworks!

target '<Target name in your project>' do
    pod 'WKJavaScriptController'
end
```

Then, run the following command:

```
$ pod install
```

## Usage
```swift
import WKJavaScriptController

// Create protocol.
// '@objc' keyword is required. because method call is based on ObjC.
@objc protocol JavaScriptInterface {
    func onSubmit(_ dictonary: [String: AnyObject])
    func onSubmit(_ email: String, firstName: String, lastName: String, address1: String, address2: String, zipCode: JSInt, phoneNumber: String)
    func onCancel()
}

// Implement protocol. 
extension ViewController: JavaScriptInterface {
    func onSubmit(_ dictonary: [String: AnyObject]) {
        NSLog("onSubmit \(dictonary)")
    }
    
    func onSubmit(_ email: String, firstName: String, lastName: String, address1: String, address2: String, zipCode: JSInt, phoneNumber: String) {
        NSLog("onSubmit \(email), \(firstName), \(lastName), \(address1), \(address2), \(zipCode.value), \(phoneNumber)")
    }
    
    func onCancel() {
        NSLog("onCancel")
    }
}

class ViewController: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Create javaScriptController.
        let javaScriptController = WKJavaScriptController(name: "native", target: self, bridgeProtocol: JavaScriptInterface.self)
        
        // [Optional] Add your javascript.
        let jsString = ...
        let userScript = WKUserScript(source: jsString, injectionTime: .AtDocumentEnd, forMainFrameOnly: true)
        javaScriptController.addUserScript(userScript)
        
        let webView = WKWebView(...)
        ...
        
        // Assign javaScriptController.
        webView.javaScriptController = javaScriptController
        
        // Call prepareForJavaScriptController before initializing WKWebView or loading page.
        webView.prepareForJavaScriptController()
        webView.loadRequest(...)
    }
    
    ...
}
```
```js
// In javascript.
native.onSubmit({
    'first_name': 'Davin',
    'last_name': 'Ahn',
    'mail': 'davin.ahn@ridi.com',
});
```

## Limitations
- Can not receive native return in JavaScript.
- Method argument length is up to 10.
- Allowed argument types are NSNumber, NSString, NSDate, NSArray, NSDictionary, and NSNull(when `undefined` passed).
- If Value types of Swift(Bool, Int32, Int, Float, Double, ...) used in argument that are not wrapped in NSArray or NSDictionary, it must be replaced with JSBool, JSInt or JSFloat.
  (Because Value types of Swift in ObjC is replaced by NSNumber.)
- Class methods in protocol are not supported.
