import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/snow_theme.dart';

/// 本地 SnowLuma 面板（WebView 直连 127.0.0.1:6199）
class LocalPanelPage extends StatefulWidget {
  const LocalPanelPage({super.key, this.url = 'http://127.0.0.1:6199'});

  final String url;

  @override
  State<LocalPanelPage> createState() => _LocalPanelPageState();
}

class _LocalPanelPageState extends State<LocalPanelPage> {
  late final WebViewController _web;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SnowStyle.canvas,
      appBar: AppBar(
        title: const Text('本地面板'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: () => _web.reload(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        bottom: _progress < 100
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(value: _progress / 100, minHeight: 2),
              )
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: WebViewWidget(controller: _web)),
          ],
        ),
      ),
    );
  }
}
