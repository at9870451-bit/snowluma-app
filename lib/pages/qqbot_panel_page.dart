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

  /// 面板地址：优先用当前服务器同域名的 /qqbot/，否则退回 IP:6199
  String get _panelUrl {
    final base = appState.baseUrl; // 例如 https://www.daykai.asia
    if (base.startsWith('http')) {
      return '${base.replaceAll(RegExp(r'/+$'), '')}/qqbot/';
    }
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