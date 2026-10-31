import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/app_state.dart';

/// QQBot 管理面板（内嵌 WebView）
///
/// 三方架构说明：
///   SnowLuma（QQ 客户端，提供 OneBot 服务端）
///     ↕ OneBot 协议
///   QQBot（Python 机器人大脑，自带 WebUI 面板 6199）
///     ↕ AI 网关（8090 /ai/*，同步配置）
///   SnowLuma App（Flutter，本 App）
class QqbotPanelPage extends StatefulWidget {
  const QqbotPanelPage({super.key});

  @override
  State<QqbotPanelPage> createState() => _QqbotPanelPageState();
}

class _QqbotPanelPageState extends State<QqbotPanelPage> {
  late final WebViewController _web;
  bool _loading = true;

  /// 面板地址：直连 QQBot WebUI 端口 6199
  /// （/qqbot/ 子路径与 SnowLuma WebUI 的 /api/* 冲突，无法代理）
  String get _panelUrl {
    // 从当前服务器地址提取主机名 → http://主机:6199
    try {
      final uri = Uri.parse(appState.baseUrl);
      if (uri.host.isNotEmpty) {
        return 'http://${uri.host}:6199/';
      }
    } catch (_) {}
    return 'http://154.12.16.204:6199/';
  }

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _loading = true),
        onPageFinished: (_) => setState(() => _loading = false),
        onWebResourceError: (_) => setState(() => _loading = false),
      ))
      ..loadRequest(Uri.parse(_panelUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QQBot 面板'),
        actions: [
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
            onPressed: () => _web.reload(),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _web),
          if (_loading)
            const LinearProgressIndicator(minHeight: 2),
        ],
      ),
    );
  }
}