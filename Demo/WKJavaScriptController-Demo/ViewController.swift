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
    var isSubmitted: JSBool { get }
    @objc optional func getErrorMessages(codes: [JSInt]) -> [String]
}

// Implement protocol.
extension ViewController: JavaScriptInterface {
    func onSubmit(_ dictonary: [String: AnyObject]) {
        NSLog("onSubmit \(dictonary)")
        _isSubmitted = true
    }
    
    func onSubmit(_ dictonary: [String: AnyObject], clear: JSBool) {
        NSLog("onSubmit \(dictonary)")
        if clear.value {
            webView.evaluateJavaScript("clearAll()", completionHandler: nil)
        }
        _isSubmitted = true
    }
    
    func onSubmit(_ email: String, firstName: String, lastName: String, address1: String, address2: String, zipCode: JSInt, phoneNumber: String) {
        NSLog("onSubmit \(email), \(firstName), \(lastName), \(address1), \(address2), \(zipCode.value), \(phoneNumber)")
        _isSubmitted = true
    }
    
    func onCancel() {
        NSLog("onCancel")
        _isSubmitted = false
    }
    
    var isSubmitted: JSBool { JSBool(_isSubmitted) }
    
    func getErrorMessages(codes: [JSInt]) -> [String] {
        codes.map { "message\($0)" }
    }
}

class ViewController: UIViewController {
    fileprivate var webView: WKWebView!

    private var _isSubmitted = false
    
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
            webView.uiDelegate = self
            view.addSubview(webView)
            
            // Assign javaScriptController.
            webView.javaScriptController = javaScriptController
            
            let htmlPath = Bundle.main.path(forResource: "index", ofType: "html")!
            let htmlString = try! String(contentsOfFile: htmlPath, encoding: String.Encoding.utf8)
            webView.prepareForJavaScriptController() // Call prepareForJavaScriptController before initializing WKWebView or loading page.
            webView.loadHTMLString(htmlString, baseURL: Bundle.main.bundleURL)
        }
    }
}

extension ViewController: WKUIDelegate {
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alertController = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
            completionHandler()
        }))
        present(alertController, animated: true, completion: nil)
    }
}
