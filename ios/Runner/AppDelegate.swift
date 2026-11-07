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
        ISHBridge.setOutputCallback(nil)
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
        if let controller = window?.rootViewController as? FlutterViewController {
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
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}