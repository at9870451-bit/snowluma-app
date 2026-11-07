// SnowLuma — AppDelegate（标准 Flutter 模板 + iSH 桥接 MethodChannel）
import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        if let controller = window?.rootViewController as? FlutterViewController {
            let channel = FlutterMethodChannel(
                name: "snowluma/ish",
                binaryMessenger: controller.binaryMessenger)
            channel.setMethodCallHandler { call, result in
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
                default:
                    result(FlutterMethodNotImplemented)
                }
            }
        }
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}