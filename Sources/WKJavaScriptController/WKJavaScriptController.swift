import WebKit

private var javaScriptControllerKey: UInt8 = 0

public extension WKWebView {
    var javaScriptController: WKJavaScriptController? {
        set {
            newValue?.webView = self
            objc_setAssociatedObject(self, &javaScriptControllerKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        get {
            objc_getAssociatedObject(self, &javaScriptControllerKey) as? WKJavaScriptController
        }
    }

    // You must call it before initializing WKWebView or loading page.
    // ex) override func loadHTMLString(string: String, baseURL: NSURL?) -> WKNavigation? {
    //         prepareForJavaScriptController()
    //         return super.loadHTMLString(string, baseURL: baseURL)
    //     }
    func prepareForJavaScriptController() {
        if let controller = javaScriptController,
            controller.isInjectRequired,
            configuration.preferences.javaScriptEnabled {
                controller.injectTo(configuration.userContentController)
        }
    }
}

open class JSValueType: NSObject {
    fileprivate var _value: NSNumber

    fileprivate init(_ number: NSNumber) {
        _value = number
    }

    override open var description: String { _value.stringValue }
}

open class JSBool: JSValueType {
    open var value: Bool { _value.boolValue }

    public convenience init(_ value: Bool) {
        self.init(value as NSNumber)
    }
}

open class JSInt: JSValueType {
    open var value: Int { _value.intValue }

    public convenience init(_ value: Int) {
        self.init(value as NSNumber)
    }
}

open class JSFloat: JSValueType {
    open var value: Float { _value.floatValue }

    public convenience init(_ value: Float) {
        self.init(value as NSNumber)
    }
}

public extension Notification.Name {
    static let WKJavaScriptControllerIgnoredMethodInvocation = Notification.Name("WKJavaScriptControllerIgnoredMethodInvocationNotification")
    static let WKJavaScriptControllerWillMethodInvocation = Notification.Name("WKJavaScriptControllerWillMethodInvocationNotification")
}

private let identifier = "/* WKJavaScriptController */"

open class WKJavaScriptController: NSObject {
    // If true, do not allow NSNull(when `undefined` or `null` passed from JavaScript) for method arguments.
    // That is, if receive NSNull as an argument, method call ignored.
    open var ignoreMethodCallWhenReceivedNull = true

    @available(*, deprecated, renamed: "ignoreMethodCallWhenReceivedNull")
    open var shouldSafeMethodCall = true {
        willSet {
            ignoreMethodCallWhenReceivedNull = newValue
        }
    }

    open var convertsToDictionaryWhenReceivedJsonString = true

    @available(*, deprecated, renamed: "convertsToDictionaryWhenReceivedJsonString")
    open var shouldConvertJSONString = true {
        willSet {
            convertsToDictionaryWhenReceivedJsonString = newValue
        }
    }

    open var callbackTimeout: TimeInterval = 10 {
        didSet {
            isInjectRequired = true
        }
    }

    open var logEnabled = true

    private let bridgeProtocol: Protocol
    private let name: String
    private weak var target: AnyObject?

    fileprivate weak var webView: WKWebView?

    open var bridges = [MethodBridge]()

    fileprivate var isInjectRequired = true

    open class MethodBridge {
        open private(set) var nativeSelector: Selector
        open fileprivate(set) var isExtendJsSelector: Bool // If true, use ObjC style naming.
        open fileprivate(set) var isReturnRequired: Bool

        open var jsSelector: String {
            let selector = NSStringFromSelector(nativeSelector)
            let components = selector.components(separatedBy: ":")
            if components.isEmpty {
                return selector
            } else if isExtendJsSelector {
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

        open var argumentCount: Int {
            max(NSStringFromSelector(nativeSelector).components(separatedBy: ":").count - 1, 0)
        }

        init(nativeSelector selector: Selector) {
            nativeSelector = selector
            isExtendJsSelector = false
            isReturnRequired = false
        }
    }

    private enum ReserveKeyword: String {
        case createUUID = "_createUUID"
        case callbackList = "_callbackList"
        case addCallback = "_addCallback"
        case cancel = "_cancel"
        case cancelAll = "_cancelAll"

        static var all: [ReserveKeyword] {
            [
                .createUUID,
                .callbackList,
                .addCallback,
                .cancel,
                .cancelAll
            ]
        }
    }

    public init(name: String, target: AnyObject, bridgeProtocol: Protocol) {
        self.name = name
        self.target = target
        self.bridgeProtocol = bridgeProtocol
        super.init()
        parseBridgeProtocol()
    }

    private func protocolsAdoptedBy(protocol: Protocol) -> [Protocol] {
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
                        let limit = argumentCountLimit
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
                            if signature.range(of: "^[v@]", options: .regularExpression) == nil {
                                log("It has an unsupported return type, so it was excluded. (selector: \(selector))")
                                log("Allowed return types are Void, String, Array, Dictionary, JSBool, JSInt, JSFloat and NSNull.")
                                continue
                            }

                            if signature.range(of: "[cC#\\[\\{\\(b\\^\\?]", options: .regularExpression) != nil {
                                log("It has an unsupported reference type as arguments, so it was excluded. (selector: \(selector))")
                                log("Allowed reference types are String, Date, Array, Dictionary, NSNumber and NSNull.")
                                continue
                            }

                            // Swift value types can't be used. because method call is based on ObjC.
                            if signature.range(of: "[iIsSlLqQfdB]", options: .regularExpression) != nil {
                                log("It has an unsupported value type as arguments, so it was excluded. (selector: \(selector))")
                                log("Allowed value types are JSBool, JSInt and JSFloat.")
                                continue
                            }

                            let bridge = MethodBridge(nativeSelector: selector)
                            if bridge.argumentCount > limit {
                                log("Argument length is longer than \(limit), so it was excluded. (selector: \(bridge.nativeSelector))")
                                continue
                            }

                            // Using ObjC style naming if have a method with the same name.
                            let list = bridges.filter { $0.jsSelector == bridge.jsSelector }
                            if !list.isEmpty {
                                bridge.isExtendJsSelector = true
                            }
                            for bridge in list {
                                bridge.isExtendJsSelector = true
                            }

                            if signature.hasPrefix("@") {
                                bridge.isReturnRequired = true
                            }

                            if let keyword = ReserveKeyword.all.first(where: { bridge.jsSelector == $0.rawValue }) {
                                log("Cannot use the keyword '\(keyword)' as a method name, so it was excluded. (selector: \(bridge.nativeSelector))")
                                continue
                            }

                            bridges.append(bridge)
                            log("Parsed: \(isRequired ? "" : "Optional ")\(bridge.nativeSelector) -> \(bridge.jsSelector)")
                        }
                        free(methodList)
                }
            }
        }
    }

    fileprivate func injectTo(_ userContentController: WKUserContentController) {
        let userScripts = userContentController.userScripts.filter {
            !$0.source.hasPrefix(identifier)
        }
        userContentController.removeAllUserScripts()

        userContentController.addUserScript(bridgeScript())
        for bridge in bridges {
            userContentController.removeScriptMessageHandler(forName: bridge.jsSelector)
            userContentController.add(self, name: bridge.jsSelector)
        }

        userScripts.forEach { userContentController.addUserScript($0) }

        isInjectRequired = false
    }

    private func bridgeScript() -> WKUserScript {
        var source = """
            window.\(name) = {
                \(ReserveKeyword.createUUID): function() {
                    const s4 = () => ((1 + Math.random()) * 0x10000 | 0).toString(16).substring(1);
                    return s4() + s4() + s4() + s4() + s4() + s4() + s4() + s4();
                },
                \(ReserveKeyword.cancel): function(id, resaon) {
                    const callback = \(name).\(ReserveKeyword.callbackList)[id];
                    resaon = resaon || new Error(`Callback cancelled. (id: ${id})`);
                    callback.cancel = new Date();
                    callback.reject(resaon);
                    clearTimeout(callback.timer);
                },
                \(ReserveKeyword.cancelAll): function() {
                    Object.getOwnPropertyNames(\(name).\(ReserveKeyword.callbackList)).forEach((key) => {
                        \(name).\(ReserveKeyword.cancel)(key);
                    });
                },
                \(ReserveKeyword.addCallback): function(id, name, resolve, reject) {
                    const timer = setTimeout(() => {
                        \(name).\(ReserveKeyword.cancel)(id, new Error(`Callback timeout. (id: ${id})`));
                    }, \(callbackTimeout * 1000));
                    \(name).\(ReserveKeyword.callbackList)[id] = { name, resolve, reject, timer, start: new Date() };
                },
                \(ReserveKeyword.callbackList): {},
            """
        var readOnlyProperties = [MethodBridge]()
        for bridge in bridges {
            if bridge.argumentCount == 0, bridge.isReturnRequired {
                readOnlyProperties.append(bridge)
                continue
            }
            source += """
                \(bridge.jsSelector): function() {
                    const id = \(name).\(ReserveKeyword.createUUID)();
                    const args = Array.from(arguments).concat(id);
                    return new Promise((resolve, reject) => {
                        \(name).\(ReserveKeyword.addCallback)(id, '\(bridge.jsSelector)', resolve, reject);
                        webkit.messageHandlers.\((bridge.jsSelector)).postMessage(args);
                    });
                },
                """
        }
        source += "};"
        for bridge in readOnlyProperties {
            source += """
                Object.defineProperty(\(name), '\(bridge.jsSelector)', {
                    key: '\(bridge.jsSelector)',
                    get: function get() {
                        const id = \(name).\(ReserveKeyword.createUUID)();
                        return new Promise((resolve, reject) => {
                            \(name).\(ReserveKeyword.addCallback)(id, '\(bridge.jsSelector)', resolve, reject);
                            webkit.messageHandlers.\((bridge.jsSelector)).postMessage([id]);
                        });
                    },
                });
                """
        }
        return WKUserScript(
            source: "\(identifier)\n\(source)",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
    }

    private func log(_ message: String) {
        if logEnabled {
            NSLog("[WKJavaScriptController] \(message)")
        }
    }
}

// MARK: - WKScriptMessageHandler

private let argumentCountLimit = 10

private typealias Target = AnyObject
private typealias Arg = AnyObject
private typealias Result = AnyObject
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
private typealias XInvocation0 = @convention(c) (Target, Selector) -> Result
private typealias XInvocation1 = @convention(c) (Target, Selector, Arg) -> Result
private typealias XInvocation2 = @convention(c) (Target, Selector, Arg, Arg) -> Result
private typealias XInvocation3 = @convention(c) (Target, Selector, Arg, Arg, Arg) -> Result
private typealias XInvocation4 = @convention(c) (Target, Selector, Arg, Arg, Arg, Arg) -> Result
private typealias XInvocation5 = @convention(c) (Target, Selector, Arg, Arg, Arg, Arg, Arg) -> Result
private typealias XInvocation6 = @convention(c) (Target, Selector, Arg, Arg, Arg, Arg, Arg, Arg) -> Result
private typealias XInvocation7 = @convention(c) (Target, Selector, Arg, Arg, Arg, Arg, Arg, Arg, Arg) -> Result
private typealias XInvocation8 = @convention(c) (Target, Selector, Arg, Arg, Arg, Arg, Arg, Arg, Arg, Arg) -> Result
private typealias XInvocation9 = @convention(c) (Target, Selector, Arg, Arg, Arg, Arg, Arg, Arg, Arg, Arg, Arg) -> Result
private typealias XInvocation10 = @convention(c) (Target, Selector, Arg, Arg, Arg, Arg, Arg, Arg, Arg, Arg, Arg, Arg) -> Result

extension WKJavaScriptController: WKScriptMessageHandler {
    private func cast(_ arg: Arg) -> Arg {
        if let number = arg as? NSNumber,
            let type = String(cString: number.objCType, encoding: .utf8) {
                switch type {
                case "c", "C", "B":
                    return JSBool(number)
                default:
                    if number.stringValue.contains(".") {
                        return JSFloat(number)
                    } else if number.stringValue == "nan" {
                        return JSInt(NSNumber(value: 0 as Int))
                    }
                    return JSInt(number)
                }
        } else if convertsToDictionaryWhenReceivedJsonString,
            let string = arg as? String,
            let data = string.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data, options: []) {
                return cast(json as Arg)
        } else if let array = arg as? [AnyObject] {
            return array.map({ value -> Arg in cast(value) }) as Arg
        } else if let dictionary = arg as? [String: AnyObject] {
            return dictionary.mapValues({ value -> Arg in cast(value) }) as Arg
        }
        return arg
    }

    private func stringFrom(_ result: Result!) -> String {
        if result != nil {
            if let jsBool = result as? JSBool {
                return stringFrom(jsBool.value as Result)
            } else if let bool = result as? Bool {
                return bool ? "true" : "false"
            } else if let jsValueType = result as? JSValueType {
                return "\(jsValueType)"
            } else if let string = result as? String {
                return "'\(string)'"
            } else if let array = result as? [AnyObject] {
                return "[\(array.map({ stringFrom($0 as Result) }).joined(separator: ","))]"
            } else if let dictionary = result as? [String: AnyObject] {
                return "{\(dictionary.map { "\(stringFrom($0 as Result)):\(stringFrom($1 as Result))" }.joined(separator: ","))}"
            } else if let date = result as? Date {
                return "new Date(\(date.timeIntervalSince1970 * 1000))"
            } else if result is NSNull {
                return "undefined"
            }
            return String(describing: result)
        }
        return "undefined"
    }

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let target = target,
            var args = message.body as? [Arg],
            let bridge = bridges.first(where: { $0.jsSelector == message.name }) else {
                return
        }

        let callbackId = args.last as! String
        args = Array(args.dropLast())

        if args.count != bridge.argumentCount {
            log("Argument length is different. (selector: \(bridge.jsSelector), received: \(args.count), required: \(bridge.argumentCount))")
            return
        }

        guard let method = class_getInstanceMethod(target.classForCoder, bridge.nativeSelector) else {
            log("An unimplemented method has been called. (selector: \(bridge.nativeSelector))")
            return
        }

        let notificationCenter = NotificationCenter.default
        let userInfo = [
            "nativeSelector": bridge.nativeSelector,
            "jsSelector": bridge.jsSelector,
            "args": args
        ] as [String: Any]
        notificationCenter.post(name: .WKJavaScriptControllerWillMethodInvocation, object: nil, userInfo: userInfo)

        if ignoreMethodCallWhenReceivedNull {
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

        let imp = method_getImplementation(method)
        DispatchQueue.global().async {
            var result: Result!
            switch bridge.argumentCount {
            case 0:
                if bridge.isReturnRequired {
                    result = unsafeBitCast(imp, to: XInvocation0.self)(target, bridge.nativeSelector)
                } else {
                    unsafeBitCast(imp, to: Invocation0.self)(target, bridge.nativeSelector)
                }
            case 1:
                if bridge.isReturnRequired {
                    result = unsafeBitCast(imp, to: XInvocation1.self)(target, bridge.nativeSelector, self.cast(args[0]))
                } else {
                    unsafeBitCast(imp, to: Invocation1.self)(target, bridge.nativeSelector, self.cast(args[0]))
                }
            case 2:
                if bridge.isReturnRequired {
                    result = unsafeBitCast(imp, to: XInvocation2.self)(target, bridge.nativeSelector, self.cast(args[0]), self.cast(args[1]))
                } else {
                    unsafeBitCast(imp, to: Invocation2.self)(target, bridge.nativeSelector, self.cast(args[0]), self.cast(args[1]))
                }
            case 3:
                if bridge.isReturnRequired {
                    result = unsafeBitCast(imp, to: XInvocation3.self)(target, bridge.nativeSelector, self.cast(args[0]), self.cast(args[1]), self.cast(args[2]))
                } else {
                    unsafeBitCast(imp, to: Invocation3.self)(target, bridge.nativeSelector, self.cast(args[0]), self.cast(args[1]), self.cast(args[2]))
                }
            case 4:
                if bridge.isReturnRequired {
                    result = unsafeBitCast(imp, to: XInvocation4.self)(target, bridge.nativeSelector, self.cast(args[0]), self.cast(args[1]), self.cast(args[2]), self.cast(args[3]))
                } else {
                    unsafeBitCast(imp, to: Invocation4.self)(target, bridge.nativeSelector, self.cast(args[0]), self.cast(args[1]), self.cast(args[2]), self.cast(args[3]))
                }
            case 5:
                if bridge.isReturnRequired {
                    result = unsafeBitCast(imp, to: XInvocation5.self)(target, bridge.nativeSelector, self.cast(args[0]), self.cast(args[1]), self.cast(args[2]), self.cast(args[3]), self.cast(args[4]))
                } else {
                    unsafeBitCast(imp, to: Invocation5.self)(target, bridge.nativeSelector, self.cast(args[0]), self.cast(args[1]), self.cast(args[2]), self.cast(args[3]), self.cast(args[4]))
                }
            case 6:
                if bridge.isReturnRequired {
                    result = unsafeBitCast(imp, to: XInvocation6.self)(target, bridge.nativeSelector, self.cast(args[0]), self.cast(args[1]), self.cast(args[2]), self.cast(args[3]), self.cast(args[4]), self.cast(args[5]))
                } else {
                    unsafeBitCast(imp, to: Invocation6.self)(target, bridge.nativeSelector, self.cast(args[0]), self.cast(args[1]), self.cast(args[2]), self.cast(args[3]), self.cast(args[4]), self.cast(args[5]))
                }
            case 7:
                if bridge.isReturnRequired {
                    result = unsafeBitCast(imp, to: XInvocation7.self)(target, bridge.nativeSelector, self.cast(args[0]), self.cast(args[1]), self.cast(args[2]), self.cast(args[3]), self.cast(args[4]), self.cast(args[5]), self.cast(args[6]))
                } else {
                    unsafeBitCast(imp, to: Invocation7.self)(target, bridge.nativeSelector, self.cast(args[0]), self.cast(args[1]), self.cast(args[2]), self.cast(args[3]), self.cast(args[4]), self.cast(args[5]), self.cast(args[6]))
                }
            case 8:
                if bridge.isReturnRequired {
                    result = unsafeBitCast(imp, to: XInvocation8.self)(target, bridge.nativeSelector, self.cast(args[0]), self.cast(args[1]), self.cast(args[2]), self.cast(args[3]), self.cast(args[4]), self.cast(args[5]), self.cast(args[6]), self.cast(args[7]))
                } else {
                    unsafeBitCast(imp, to: Invocation8.self)(target, bridge.nativeSelector, self.cast(args[0]), self.cast(args[1]), self.cast(args[2]), self.cast(args[3]), self.cast(args[4]), self.cast(args[5]), self.cast(args[6]), self.cast(args[7]))
                }
            case 9:
                if bridge.isReturnRequired {
                    result = unsafeBitCast(imp, to: XInvocation9.self)(target, bridge.nativeSelector, self.cast(args[0]), self.cast(args[1]), self.cast(args[2]), self.cast(args[3]), self.cast(args[4]), self.cast(args[5]), self.cast(args[6]), self.cast(args[7]), self.cast(args[8]))
                } else {
                    unsafeBitCast(imp, to: Invocation9.self)(target, bridge.nativeSelector, self.cast(args[0]), self.cast(args[1]), self.cast(args[2]), self.cast(args[3]), self.cast(args[4]), self.cast(args[5]), self.cast(args[6]), self.cast(args[7]), self.cast(args[8]))
                }
            case argumentCountLimit:
                if bridge.isReturnRequired {
                    result = unsafeBitCast(imp, to: XInvocation10.self)(target, bridge.nativeSelector, self.cast(args[0]), self.cast(args[1]), self.cast(args[2]), self.cast(args[3]), self.cast(args[4]), self.cast(args[5]), self.cast(args[6]), self.cast(args[7]), self.cast(args[8]), self.cast(args[9]))
                } else {
                    unsafeBitCast(imp, to: Invocation10.self)(target, bridge.nativeSelector, self.cast(args[0]), self.cast(args[1]), self.cast(args[2]), self.cast(args[3]), self.cast(args[4]), self.cast(args[5]), self.cast(args[6]), self.cast(args[7]), self.cast(args[8]), self.cast(args[9]))
                }
            default:
                // Not called.
                break
            }

            DispatchQueue.main.async {
                let script = """
                    (() => {
                        const callback = \(self.name).\(ReserveKeyword.callbackList)['\(callbackId)'];
                        callback.end = new Date();
                        callback.resolve(\(bridge.isReturnRequired ? self.stringFrom(result) : ""));
                        clearTimeout(callback.timer);
                    })();
                    """
                self.webView?.evaluateJavaScript(script, completionHandler: nil)
            }
        }
    }
}
