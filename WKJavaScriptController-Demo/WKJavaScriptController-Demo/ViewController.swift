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
    func onSubmit(_ dictonary: [String: AnyObject])
    func onSubmit(_ dictonary: [String: AnyObject], clear: JSBool)
    func onSubmit(_ email: String, firstName: String, lastName: String, address1: String, address2: String, zipCode: JSInt, phoneNumber: String)
    func onCancel()
}

class ViewController: UIViewController {
    fileprivate var webView: WKWebView!
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if webView == nil {
            let javaScriptController = WKJavaScriptController(name: "native", target: self, bridgeProtocol: JavaScriptInterface.self)
            
            let jsPath = Bundle.main.path(forResource: "index", ofType: "js")!
            let jsString = try! String(contentsOfFile: jsPath, encoding: String.Encoding.utf8)
            let userScript = WKUserScript(source: jsString, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
            javaScriptController.addUserScript(userScript)
            
            webView = WKWebView(frame: view.frame)
            webView.javaScriptController = javaScriptController
            view.addSubview(webView)
            
            let htmlPath = Bundle.main.path(forResource: "index", ofType: "html")!
            let htmlString = try! String(contentsOfFile: htmlPath, encoding: String.Encoding.utf8)
            webView.prepareForJavaScriptController()
            webView.loadHTMLString(htmlString, baseURL: Bundle.main.bundleURL)
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
}

// MARK: - JavaScriptInterface

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
