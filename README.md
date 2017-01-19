# WKJavaScriptController
Calling native code from Javascript in iOS likes JavascriptInterface in Android.

## Requirements
- Xcode 8.0+
- Swift 3
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
```

Then, run the following command:

```
$ pod install
```

## Usage
```swift
import WKJavaScriptController

// Create protocol.
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