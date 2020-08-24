# WKJavaScriptController

Calling native code from Javascript in iOS likes JavascriptInterface in Android.

[![Build Status](https://travis-ci.com/ridi/WKJavaScriptController.svg?branch=master)](https://travis-ci.com/ridi/WKJavaScriptController)

## Requirements

- Xcode 11.4+
- Swift 5.2+
- iOS8+

(based on WKJavaScriptController 2.1.0+)

## Installation with Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
  // ...
  .package(url: "https://github.com/ridi/WKJavaScriptController.git"),
]
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
    var isSubmitted: JSBool { get }
    @objc optional func getErrorMessages(codes: [JSInt]) -> [String]
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
    
    var isSubmitted: JSBool {
        return JSBool(true)
    }
    
    func getErrorMessages(codes: [JSInt]) -> [String] {
        return codes.map { "message\($0)" }
    }
}

class ViewController: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Create javaScriptController.
        let javaScriptController = WKJavaScriptController(name: "native", target: self, bridgeProtocol: JavaScriptInterface.self)
        
        // [Optional] Add your javascript.
        let configuration = WKWebViewConfiguration()
        
        let jsCode = ...
        let userScript = WKUserScript(source: jsCode, injectionTime: .AtDocumentEnd, forMainFrameOnly: true)
        userContentController.addUserScript(userScript)

        configuration.userContentController = userContentController
        
        // Create WKWebView instance.
        webView = WKWebView(frame: view.frame, configuration: configuration)
        
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

Can receive native return in JavaScript as [Promise](https://developer.mozilla.org/ko/docs/Web/JavaScript/Reference/Global_Objects/Promise):

```js
// In javascript.
const isSubmitted = await native.isSubmitted;
// or native.isSubmitted.then(isSubmitted => ...);
const messages = await native.getErrorMessages([200, 400, 500]);
// or native.getErrorMessages([200, 400, 500]).then(messages => ...);
```

## Limitations

- Can not receive native return in JavaScript as sync. can only async return.
- Method argument length is up to 10.
- Allowed argument types are String, Date, Array, Dictionary, JSBool, JSInt, JSFloat, NSNumber and NSNull(when `undefined` or `null` passed from JavaScript).
- If Swift value types(Bool, Int32, Int, Float, Double, ...) used in argument, it must be replaced with JSBool, JSInt or JSFloat. (Because Swift value type is replaced by NSNumber in ObjC.)
- Class methods in protocol are not supported.

## License

[MIT](https://github.com/ridi/WKJavaScriptController/blob/master/LICENSE)
