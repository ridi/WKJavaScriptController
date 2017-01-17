//
//  WKJavaScriptController.swift
//  Ridibooks
//
//  Created by Da Vin Ahn on 2017. 1. 12..
//  Copyright © 2017년 Ridibooks. All rights reserved.
//

import WebKit

private var javaScriptControllerKey: UInt8 = 0

public extension WKWebView {
    public var javaScriptController: WKJavaScriptController? {
        set {
            objc_setAssociatedObject(self, &javaScriptControllerKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        get {
            return objc_getAssociatedObject(self, &javaScriptControllerKey) as? WKJavaScriptController
        }
    }
    
    // You must call it before initializing WKWebView or loading page.
    // ex) override func loadHTMLString(string: String, baseURL: NSURL?) -> WKNavigation? {
    //         prepareForJavaScriptController()
    //         return super.loadHTMLString(string, baseURL: baseURL)
    //     }
    public func prepareForJavaScriptController() {
        if let controller = javaScriptController where controller.needsInject && configuration.preferences.javaScriptEnabled {
            controller.injectTo(configuration.userContentController)
        }
    }
}

public class WKJavaScriptController: NSObject {
    private let name: String
    private weak var target: AnyObject?
    private let bridgeProtocol: Protocol
    
    // User script that will use the bridge.
    private var userScripts = [WKUserScript]()
    
    private var bridgeList = [MethodBridge]()
    
    private var needsInject = true
    
    private class MethodBridge {
        private var nativeSelector: Selector
        private var extendJsSelector: Bool // If true, use ObjC style naming.
        
        private var jsSelector: String {
            let selector = NSStringFromSelector(nativeSelector)
            let components = selector.componentsSeparatedByString(":")
            if components.isEmpty {
                return selector
            } else if extendJsSelector {
                var selector = ""
                for (index, component) in components.enumerate() {
                    if component.isEmpty {
                        continue
                    } else if index == 0 {
                        selector += component
                    } else if index == 1 {
                        selector += "With\(component.capitalizedString)"
                    } else {
                        selector += "And\(component.capitalizedString)"
                    }
                }
                return selector
            } else {
                return components.first!
            }
        }
        
        private var numberOfArguments: Int {
            return max(NSStringFromSelector(nativeSelector).componentsSeparatedByString(":").count - 1, 0)
        }
        
        private init(nativeSelector selector: Selector) {
            nativeSelector = selector
            extendJsSelector = false
        }
    }
    
    public init(name: String, target: AnyObject, bridgeProtocol: Protocol) {
        self.name = name
        self.target = target
        self.bridgeProtocol = bridgeProtocol
        super.init()
        parseBridgeProtocol()
    }
    
    private func parseBridgeProtocol() {
        // Class methods are not supported.
        for (isRequired, isInstance) in [(true, true), (false, true)] {
            let methodList = protocol_copyMethodDescriptionList(bridgeProtocol.self, isRequired, isInstance, nil)
            if methodList != nil, var list = Optional(methodList) {
                let limit = argumentLengthLimit
                while list.memory.name != nil {
                    var bridge = MethodBridge(nativeSelector: list.memory.name)
                    if bridge.numberOfArguments > limit {
                        NSLog("[WKJavaScriptController:Warning] The length of argument was longer than \(limit), so it was excluded. (selector: \(bridge.nativeSelector))")
                    } else {
                        // Using ObjC style naming if have a method with the same name.
                        var list = bridgeList.filter({ $0.jsSelector == bridge.jsSelector })
                        if !list.isEmpty {
                            bridge.extendJsSelector = true
                        }
                        for bridge in list {
                            bridge.extendJsSelector = true
                        }
                        bridgeList.append(bridge)
                    }
                    list = list.successor()
                }
                free(methodList)
            }
        }
    }
    
    private func injectTo(userContentController: WKUserContentController) {
        userContentController.removeAllUserScripts()
        var forMainFrameOnly = true
        for userScript in userScripts {
            forMainFrameOnly = forMainFrameOnly && userScript.forMainFrameOnly
            userContentController.addUserScript(userScript)
        }
        userContentController.addUserScript(bridgeScript(forMainFrameOnly))
        for bridge in bridgeList {
            userContentController.removeScriptMessageHandlerForName(bridge.jsSelector)
            userContentController.addScriptMessageHandler(self, name: bridge.jsSelector)
        }
        needsInject = false
    }
    
    private func bridgeScript(forMainFrameOnly: Bool) -> WKUserScript {
        var source = "window.\(name) = {"
        for bridge in bridgeList {
            source += "\(bridge.jsSelector): function() { window.webkit.messageHandlers.\((bridge.jsSelector)).postMessage(Array.prototype.slice.call(arguments)); },"
        }
        source += "};"
        return WKUserScript(source: source, injectionTime: .AtDocumentStart, forMainFrameOnly: forMainFrameOnly)
    }
    
    public func addUserScript(userScript: WKUserScript) {
        userScripts.append(userScript)
        needsInject = true
    }
    
    public func removeAllUserScripts() {
        userScripts.removeAll()
        needsInject = true
    }
}

// MARK: - WKScriptMessageHandler

private let argumentLengthLimit = 10

private typealias Target = AnyObject
private typealias Arg = AnyObject
private typealias Invocation0 = @convention(c) (Target, Selector) -> Void
private typealias Invocation1 = @convention(c) (Target, Selector, Arg) -> Void
private typealias Invocation2 = @convention(c) (Target, Selector, Arg, Arg) -> Void
private typealias Invocation3 = @convention(c) (Target, Selector, Arg, Arg, Arg) -> Void
private typealias Invocation4 = @convention(c) (Target, Selector, Arg, Arg, Arg, Arg) -> Void
private typealias Invocation5 = @convention(c) (Target, Selector, Arg, Arg, Arg, Arg, Arg) -> Void
private typealias Invocation6 = @convention(c) (Target, Selector, Arg, Arg, Arg, Arg, Arg, Arg) -> Void
private typealias Invocation7 = @convention(c) (Target, Selector, Arg, Arg, Arg, Arg, Arg, Arg, Arg) -> Void
private typealias Invocation8 = @convention(c) (Target, Selector, Arg, Arg, Arg, Arg, Arg, Arg, Arg, Arg) -> Void
private typealias Invocation9 = @convention(c) (Target, Selector, Arg, Arg, Arg, Arg, Arg, Arg, Arg, Arg, Arg) -> Void
private typealias Invocation10 = @convention(c) (Target, Selector, Arg, Arg, Arg, Arg, Arg, Arg, Arg, Arg, Arg, Arg) -> Void

extension WKJavaScriptController: WKScriptMessageHandler {
    public func userContentController(userContentController: WKUserContentController, didReceiveScriptMessage message: WKScriptMessage) {
        guard let target = target,
            let args = message.body as? [Arg],
            let bridge = bridgeList.filter({ $0.jsSelector == message.name }).first else {
                return
        }
        
        if args.count != bridge.numberOfArguments {
            NSLog("[WKJavaScriptController:Error] Argument length is invalid. (received: \(args.count), required: \(bridge.numberOfArguments))")
            return
        }
        
        let method = class_getInstanceMethod(target.classForCoder, bridge.nativeSelector)
        if method == nil {
            NSLog("[WKJavaScriptController:Warning] You are calling an unimplementation method.")
            return
        }
        
        let imp = method_getImplementation(method)
        if imp == nil { // Always true...?
            return
        }
        
        switch bridge.numberOfArguments {
        case 0:
            let method = unsafeBitCast(imp, Invocation0.self)
            method(target, bridge.nativeSelector)
        case 1:
            let method = unsafeBitCast(imp, Invocation1.self)
            method(target, bridge.nativeSelector, args[0])
        case 2:
            let method = unsafeBitCast(imp, Invocation2.self)
            method(target, bridge.nativeSelector, args[0], args[1])
        case 3:
            let method = unsafeBitCast(imp, Invocation3.self)
            method(target, bridge.nativeSelector, args[0], args[1], args[2])
        case 4:
            let method = unsafeBitCast(imp, Invocation4.self)
            method(target, bridge.nativeSelector, args[0], args[1], args[2], args[3])
        case 5:
            let method = unsafeBitCast(imp, Invocation5.self)
            method(target, bridge.nativeSelector, args[0], args[1], args[2], args[3], args[4])
        case 6:
            let method = unsafeBitCast(imp, Invocation6.self)
            method(target, bridge.nativeSelector, args[0], args[1], args[2], args[3], args[4], args[5])
        case 7:
            let method = unsafeBitCast(imp, Invocation7.self)
            method(target, bridge.nativeSelector, args[0], args[1], args[2], args[3], args[4], args[5], args[6])
        case 8:
            let method = unsafeBitCast(imp, Invocation8.self)
            method(target, bridge.nativeSelector, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7])
        case 9:
            let method = unsafeBitCast(imp, Invocation9.self)
            method(target, bridge.nativeSelector, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8])
        case argumentLengthLimit:
            let method = unsafeBitCast(imp, Invocation10.self)
            method(target, bridge.nativeSelector, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9])
        default:
            // Not called.
            break
        }
    }
}
