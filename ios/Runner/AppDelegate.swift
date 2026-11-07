// SnowLuma — AppDelegate（标准 Flutter 模板 + iSH 桥接 Method/EventChannel）
import UIKit
import Flutter

class IshOutputHandler: NSObject, FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink) -> FlutterError? {
        ISHBridge.setOutputCallback { text in
            eventSink(text)
        }
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        ISHBridge.setOutputCallback { _ in }
        return nil
    }
}

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        _ = super.application(application, didFinishLaunchingWithOptions: launchOptions)
        // 延迟到首帧后注册通道，避免 window.rootViewController 尚未就绪
        DispatchQueue.main.async { [weak self] in
            self?.setupIshChannels()
        }
        return true
    }

    private func setupIshChannels() {
        guard let controller = findFlutterViewController() else {
            return
        }
        let methodChannel = FlutterMethodChannel(
            name: "snowluma/ish",
            binaryMessenger: controller.binaryMessenger)
        methodChannel.setMethodCallHandler { call, result in
            switch call.method {
            case "start":
                guard let args = call.arguments as? [String: Any],
                      let rootfs = args["rootfs"] as? String,
                      let exe = args["exe"] as? String else {
                    result(FlutterError(
                        code: "bad_args",
                        message: "缺少 rootfs/exe 参数",
                        details: nil))
                    return
                }
                let envp = (args["envp"] as? String) ?? ""
                let err = ISHBridge.startLinux(
                    withRootfs: rootfs, exe: exe, envp: envp)
                if err == 0 {
                    result(nil)
                } else {
                    result(FlutterError(
                        code: "start_failed",
                        message: "iSH 启动失败 code=\(err)",
                        details: nil))
                }
            case "write":
                guard let args = call.arguments as? [String: Any],
                      let text = args["text"] as? String else {
                    result(FlutterError(
                        code: "bad_args",
                        message: "缺少 text 参数",
                        details: nil))
                    return
                }
                let err = ISHBridge.writeInput(text)
                if err == 0 {
                    result(nil)
                } else {
                    result(FlutterError(
                        code: "write_failed",
                        message: "写入失败 code=\(err)",
                        details: nil))
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        let eventChannel = FlutterEventChannel(
            name: "snowluma/ish/output",
            binaryMessenger: controller.binaryMessenger)
        eventChannel.setStreamHandler(IshOutputHandler())
    }

    private func findFlutterViewController() -> FlutterViewController? {
        if let vc = window?.rootViewController as? FlutterViewController {
            return vc
        }
        for w in UIApplication.shared.windows {
            if let vc = w.rootViewController as? FlutterViewController {
                return vc
            }
        }
        // 递归查找被导航/容器包裹的 FlutterViewController
        if let root = window?.rootViewController {
            return findIn(root)
        }
        return nil
    }

    private func findIn(_ vc: UIViewController) -> FlutterViewController? {
        if let fvc = vc as? FlutterViewController {
            return fvc
        }
        for child in vc.children {
            if let found = findIn(child) {
                return found
            }
        }
        if let nav = vc as? UINavigationController,
           let top = nav.topViewController,
           let found = findIn(top) {
            return found
        }
        if let presented = vc.presentedViewController,
           let found = findIn(presented) {
            return found
        }
        return nil
    }
}