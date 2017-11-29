import UIKit
import WebKit
import WKJavaScriptController

// Create protocol.
// '@objc' keyword is required. because method call is based on ObjC.
@objc protocol JavaScriptInterface {
    func onSubmit(_ dictonary: [String: AnyObject])
    func onSubmit(_ dictonary: [String: AnyObject], clear: JSBool)
    func onSubmit(_ email: String, firstName: String, lastName: String, address1: String, address2: String, zipCode: JSInt, phoneNumber: String)
    func onCancel()
}

// Implement protocol.
extension ViewController: JavaScriptInterface {
    func onSubmit(_ dictonary: [String: AnyObject]) {
        NSLog("onSubmit \(dictonary)")
    }
    
    func onSubmit(_ dictonary: [String: AnyObject], clear: JSBool) {
        NSLog("onSubmit \(dictonary)")
        if clear.value {
            webView.evaluateJavaScript("clearAll()", completionHandler: nil)
        }
    }
    
    func onSubmit(_ email: String, firstName: String, lastName: String, address1: String, address2: String, zipCode: JSInt, phoneNumber: String) {
        NSLog("onSubmit \(email), \(firstName), \(lastName), \(address1), \(address2), \(zipCode.value), \(phoneNumber)")
    }
    
    func onCancel() {
        NSLog("onCancel")
    }
}

class ViewController: UIViewController {
    fileprivate var webView: WKWebView!
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if webView == nil {
            // Create javaScriptController.
            let javaScriptController = WKJavaScriptController(name: "native", target: self, bridgeProtocol: JavaScriptInterface.self)
            
            // [Optional] Add your javascript.
            let jsPath = Bundle.main.path(forResource: "index", ofType: "js")!
            let jsString = try! String(contentsOfFile: jsPath, encoding: String.Encoding.utf8)
            let userScript = WKUserScript(source: jsString, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
            javaScriptController.addUserScript(userScript)
            
            webView = WKWebView(frame: view.frame)
            view.addSubview(webView)
            
            // Assign javaScriptController.
            webView.javaScriptController = javaScriptController
            
            let htmlPath = Bundle.main.path(forResource: "index", ofType: "html")!
            let htmlString = try! String(contentsOfFile: htmlPath, encoding: String.Encoding.utf8)
            webView.prepareForJavaScriptController() // Call prepareForJavaScriptController before initializing WKWebView or loading page.
            webView.loadHTMLString(htmlString, baseURL: Bundle.main.bundleURL)
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
}
