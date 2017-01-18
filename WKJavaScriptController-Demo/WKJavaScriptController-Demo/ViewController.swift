//
//  ViewController.swift
//  WKJavaScriptController-Demo
//
//  Created by Da Vin Ahn on 2017. 1. 16..
//  Copyright © 2017년 Davin Ahn. All rights reserved.
//

import UIKit
import WebKit
import WKJavaScriptController

@objc protocol JavaScriptInterface {
    func onSubmit(dictonary: [String: AnyObject])
    func onSubmit(dictonary: [String: AnyObject], clear: JSBool)
    func onSubmit(email: String, firstName: String, lastName: String, address1: String, address2: String, zipCode: JSInt, phoneNumber: String)
    func onCancel()
}

class ViewController: UIViewController {
    private var webView: WKWebView!
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        if webView == nil {
            let javaScriptController = WKJavaScriptController(name: "native", target: self, bridgeProtocol: JavaScriptInterface.self)
            
            let jsPath = NSBundle.mainBundle().pathForResource("index", ofType: "js")!
            let jsString = try! String(contentsOfFile: jsPath, encoding: NSUTF8StringEncoding)
            let userScript = WKUserScript(source: jsString, injectionTime: .AtDocumentEnd, forMainFrameOnly: true)
            javaScriptController.addUserScript(userScript)
            
            webView = WKWebView(frame: view.frame)
            webView.javaScriptController = javaScriptController
            view.addSubview(webView)
            
            let htmlPath = NSBundle.mainBundle().pathForResource("index", ofType: "html")!
            let htmlString = try! String(contentsOfFile: htmlPath, encoding: NSUTF8StringEncoding)
            webView.prepareForJavaScriptController()
            webView.loadHTMLString(htmlString, baseURL: NSBundle.mainBundle().bundleURL)
        }
    }
    
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
}

// MARK: - JavaScriptInterface

extension ViewController: JavaScriptInterface {
    func onSubmit(dictonary: [String: AnyObject]) {
        NSLog("onSubmit \(dictonary)")
    }
    
    func onSubmit(dictonary: [String: AnyObject], clear: JSBool) {
        NSLog("onSubmit \(dictonary)")
        if clear.value {
            webView.evaluateJavaScript("clearAll()", completionHandler: nil)
        }
    }
    
    func onSubmit(email: String, firstName: String, lastName: String, address1: String, address2: String, zipCode: JSInt, phoneNumber: String) {
        NSLog("onSubmit \(email), \(firstName), \(lastName), \(address1), \(address2), \(zipCode.value), \(phoneNumber)")
    }
    
    func onCancel() {
        NSLog("onCancel")
    }
}
