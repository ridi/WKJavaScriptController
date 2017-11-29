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
        if let controller = javaScriptController,
            controller.needsInject,
            configuration.preferences.javaScriptEnabled {
                controller.injectTo(configuration.userContentController)
        }
    }
}

open class JSValueType: NSObject {
    fileprivate var _value: NSNumber
    
    fileprivate init(value: AnyObject) {
        _value = value as! NSNumber
    }
}

open class JSBool: JSValueType {
    open var value: Bool {
        return _value.boolValue
    }
}

open class JSInt: JSValueType {
    open var value: Int {
        return _value.intValue
    }
}

open class JSFloat: JSValueType {
    open var value: Float {
        return _value.floatValue
    }
}

public extension Notification.Name {
    static let WKJavaScriptControllerIgnoredMethodInvocation = Notification.Name("WKJavaScriptControllerIgnoredMethodInvocationNotification")
    static let WKJavaScriptControllerWillMethodInvocation = Notification.Name("WKJavaScriptControllerWillMethodInvocationNotification")
}

open class WKJavaScriptController: NSObject {
    // If true, do not allow NSNull(If passed undefined in JavaScript) for method arguments.
    // That is, if get NSNull as arguments, do not call method.
    open var shouldSafeMethodCall = true
    
    // If true, converts to dictionary when json string is received as an argument.
    open var shouldConvertJSONString = true
    
    private let bridgeProtocol: Protocol
    private let name: String
    fileprivate weak var target: AnyObject?
    
    // User script that will use the bridge.
    private var userScripts = [WKUserScript]()
    
    fileprivate var bridgeList = [MethodBridge]()
    
    fileprivate var needsInject = true
    
    fileprivate class MethodBridge {
        fileprivate var nativeSelector: Selector
        fileprivate var extendJsSelector: Bool // If true, use ObjC style naming.
        
        fileprivate var jsSelector: String {
            let selector = NSStringFromSelector(nativeSelector)
            let components = selector.components(separatedBy: ":")
            if components.isEmpty {
                return selector
            } else if extendJsSelector {
                var selector = ""
                for (index, component) in components.enumerated() {
                    if component.isEmpty {
                        continue
                    } else if index == 0 {
                        selector += component
                    } else if index == 1 {
                        selector += "With\(component.capitalized)"
                    } else {
                        selector += "And\(component.capitalized)"
                    }
                }
                return selector
            } else {
                return components.first!
            }
        }
        
        fileprivate var argumentLength: Int {
            return max(NSStringFromSelector(nativeSelector).components(separatedBy: ":").count - 1, 0)
        }
        
        fileprivate init(nativeSelector selector: Selector) {
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
    
    private func protocolsAdoptedBy(`protocol`: Protocol) -> [Protocol] {
        var protocols = [`protocol`]
        let protocolList = protocol_copyProtocolList(`protocol`, nil)
        if protocolList != nil,
            let list = Optional(protocolList) {
                if let adoptedProtocol = list?.pointee {
                    protocols += protocolsAdoptedBy(protocol: adoptedProtocol)
                }
        }
        return protocols
    }
    
    private func parseBridgeProtocol() {
        for `protocol` in protocolsAdoptedBy(protocol: bridgeProtocol.self).reversed() {
            log("Protocol: \(String(format: "%s", protocol_getName(`protocol`)))")
            
            // Class methods are not supported.
            for (isRequired, isInstance) in [(true, true), (false, true)] {
                let methodList = protocol_copyMethodDescriptionList(`protocol`, isRequired, isInstance, nil)
                if methodList != nil,
                    var list = Optional(methodList) {
                        let limit = argumentLengthLimit
                        while list?.pointee.name != nil {
                            defer { list = list?.successor() }
                            
                            guard let selector = list?.pointee.name,
                                let types = list?.pointee.types,
                                let signature = String(cString: types, encoding: .utf8) else {
                                    log("Method signature not found, so it was excluded. (selector: \(list?.pointee.name ?? Selector(("nil"))))")
                                    continue
                            }
                            
                            // Ref: http://nshipster.com/type-encodings/
                            // c: A char                  v: A void
                            // C: An unsigned char        B: A C++ bool or C99 _bool
                            // i: An int                  @: An object (whether statically typed or typed id)
                            // I: An unsigned int         #: A class object
                            // s: A short                 :: A method selector (SEL)
                            // S: An unsigned short       [array type]: An array
                            // l: A long                  {name=type...}: A structure
                            // L: An unsigned long        (name=type...): A union
                            // q: A long long             bnum: A bit field of num bits
                            // Q: An unsigned long long   ^type: A pointer to type
                            // f: A float                 ?: An unknown type (among other things, this code is used for function pointers)
                            // d: A double
                            if !signature.hasPrefix("v") {
                                log("Can not receive native return in JavaScript, so it was excluded. (selector: \(selector))")
                                continue
                            }
                            
                            if signature.range(of: "[cC#\\[\\{\\(b\\^\\?]", options: .regularExpression) != nil {
                                log("It has an unsupported reference type as arguments, so it was excluded. (selector: \(selector))")
                                log("Allowed reference types are NSNumber, NSString, NSDate, NSArray, NSDictionary, and NSNull.")
                                continue
                            }
                            
                            // Value types of Swift can't be used. because method call is based on ObjC.
                            if signature.range(of: "[iIsSlLqQfdB]", options: .regularExpression) != nil {
                                log("It has an unsupported value type as arguments, so it was excluded. (selector: \(selector))")
                                log("Allowed value types are JSBool, JSInt and JSFloat.")
                                continue
                            }
                            
                            let bridge = MethodBridge(nativeSelector: selector)
                            if bridge.argumentLength > limit {
                                log("Argument length is longer than \(limit), so it was excluded. (selector: \(bridge.nativeSelector))")
                                continue
                            }
                            
                            // Using ObjC style naming if have a method with the same name.
                            let list = bridgeList.filter { $0.jsSelector == bridge.jsSelector }
                            if !list.isEmpty {
                                bridge.extendJsSelector = true
                            }
                            for bridge in list {
                                bridge.extendJsSelector = true
                            }
                            
                            bridgeList.append(bridge)
                            log("Parsed: \(isRequired ? "" : "Optional ")\(bridge.nativeSelector) -> \(bridge.jsSelector)")
                        }
                        free(methodList)
                }
            }
        }
    }
    
    fileprivate func injectTo(_ userContentController: WKUserContentController) {
        userContentController.removeAllUserScripts()
        var forMainFrameOnly = true
        for userScript in userScripts {
            forMainFrameOnly = forMainFrameOnly && userScript.isForMainFrameOnly
            userContentController.addUserScript(userScript)
        }
        userContentController.addUserScript(bridgeScript(forMainFrameOnly))
        for bridge in bridgeList {
            userContentController.removeScriptMessageHandler(forName: bridge.jsSelector)
            userContentController.add(self, name: bridge.jsSelector)
        }
        needsInject = false
    }
    
    private func bridgeScript(_ forMainFrameOnly: Bool) -> WKUserScript {
        var source = "window.\(name) = {"
        for bridge in bridgeList {
            source += "\(bridge.jsSelector): function() { window.webkit.messageHandlers.\((bridge.jsSelector)).postMessage(Array.prototype.slice.call(arguments)); },"
        }
        source += "};"
        return WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: forMainFrameOnly)
    }
    
    fileprivate func log(_ message: String) {
        NSLog("[WKJavaScriptController] \(message)")
    }
    
    open func addUserScript(_ userScript: WKUserScript) {
        userScripts.append(userScript)
        needsInject = true
    }
    
    open func removeAllUserScripts() {
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
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let target = target,
            let args = message.body as? [Arg],
            let bridge = bridgeList.first(where: { $0.jsSelector == message.name }) else {
                return
        }
        
        if args.count != bridge.argumentLength {
            log("Argument length is different. (received: \(args.count), required: \(bridge.argumentLength))")
            return
        }
        
        let method = class_getInstanceMethod(target.classForCoder, bridge.nativeSelector)
        if method == nil {
            log("An unimplemented method has been called. (selector: \(bridge.nativeSelector))")
            return
        }
        
        let imp = method_getImplementation(method)
        if imp == nil { // Always false...?
            return
        }
        
        func cast(_ arg: Arg) -> Arg {
            if let number = arg as? NSNumber,
                let type = String(cString: number.objCType, encoding: .utf8) {
                    switch type {
                    case "c", "C", "B":
                        return JSBool(value: number)
                    default:
                        if number.stringValue.range(of: ".") != nil {
                            return JSFloat(value: number)
                        } else if number.stringValue == "nan" {
                            return JSInt(value: NSNumber(value: 0 as Int))
                        }
                        return JSInt(value: number)
                    }
            } else if shouldConvertJSONString,
                let string = arg as? String,
                let data = string.data(using: .utf8),
                let json = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) {
                    return json as Arg
            }
            return arg
        }
        
        let notificationCenter = NotificationCenter.default
        let userInfo = [
            "nativeSelector": bridge.nativeSelector,
            "jsSelector": bridge.jsSelector,
            "args": args
        ] as [String: Any]
        notificationCenter.post(name: .WKJavaScriptControllerWillMethodInvocation, object: nil, userInfo: userInfo)
        
        if shouldSafeMethodCall {
            for arg in args {
                if arg is NSNull {
                    let userInfo = [
                        "nativeSelector": bridge.nativeSelector,
                        "jsSelector": bridge.jsSelector,
                        "args": args,
                        "reason": "Arguments has NSNull(=undefined)."
                    ] as [String: Any]
                    notificationCenter.post(name: .WKJavaScriptControllerIgnoredMethodInvocation, object: nil, userInfo: userInfo)
                    return
                }
            }
        }
        
        switch bridge.argumentLength {
        case 0:
            let method = unsafeBitCast(imp, to: Invocation0.self)
            method(target, bridge.nativeSelector)
        case 1:
            let method = unsafeBitCast(imp, to: Invocation1.self)
            method(target, bridge.nativeSelector, cast(args[0]))
        case 2:
            let method = unsafeBitCast(imp, to: Invocation2.self)
            method(target, bridge.nativeSelector, cast(args[0]), cast(args[1]))
        case 3:
            let method = unsafeBitCast(imp, to: Invocation3.self)
            method(target, bridge.nativeSelector, cast(args[0]), cast(args[1]), cast(args[2]))
        case 4:
            let method = unsafeBitCast(imp, to: Invocation4.self)
            method(target, bridge.nativeSelector, cast(args[0]), cast(args[1]), cast(args[2]), cast(args[3]))
        case 5:
            let method = unsafeBitCast(imp, to: Invocation5.self)
            method(target, bridge.nativeSelector, cast(args[0]), cast(args[1]), cast(args[2]), cast(args[3]), cast(args[4]))
        case 6:
            let method = unsafeBitCast(imp, to: Invocation6.self)
            method(target, bridge.nativeSelector, cast(args[0]), cast(args[1]), cast(args[2]), cast(args[3]), cast(args[4]), cast(args[5]))
        case 7:
            let method = unsafeBitCast(imp, to: Invocation7.self)
            method(target, bridge.nativeSelector, cast(args[0]), cast(args[1]), cast(args[2]), cast(args[3]), cast(args[4]), cast(args[5]), cast(args[6]))
        case 8:
            let method = unsafeBitCast(imp, to: Invocation8.self)
            method(target, bridge.nativeSelector, cast(args[0]), cast(args[1]), cast(args[2]), cast(args[3]), cast(args[4]), cast(args[5]), cast(args[6]), cast(args[7]))
        case 9:
            let method = unsafeBitCast(imp, to: Invocation9.self)
            method(target, bridge.nativeSelector, cast(args[0]), cast(args[1]), cast(args[2]), cast(args[3]), cast(args[4]), cast(args[5]), cast(args[6]), cast(args[7]), cast(args[8]))
        case argumentLengthLimit:
            let method = unsafeBitCast(imp, to: Invocation10.self)
            method(target, bridge.nativeSelector, cast(args[0]), cast(args[1]), cast(args[2]), cast(args[3]), cast(args[4]), cast(args[5]), cast(args[6]), cast(args[7]), cast(args[8]), cast(args[9]))
        default:
            // Not called.
            break
        }
    }
}
