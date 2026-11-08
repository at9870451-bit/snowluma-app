import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

import '../core/snow_theme.dart';

/// 本地 SnowLuma 面板（WebView 直连 127.0.0.1:6199）
/// 带连通性检测与错误提示：白屏时能看出是「服务未启动」还是「网络不通」。
class LocalPanelPage extends StatefulWidget {
  const LocalPanelPage({super.key, this.url = 'http://127.0.0.1:6199'});

  final String url;

  @override
  State<LocalPanelPage> createState() => _LocalPanelPageState();
}

class _LocalPanelPageState extends State<LocalPanelPage> {
  WebViewController? _web;
  int _progress = 0;
  bool _checking = true;
  bool _reachable = false;
  String _probe = '';
  String? _webError;

  @override
  void initState() {
    super.initState();
    _probeAndLoad();
  }

  /// 先用 HTTP 探测 /api/status，再决定加载 WebView 还是显示错误页。
  Future<void> _probeAndLoad() async {
    setState(() {
      _checking = true;
      _webError = null;
      _probe = '';
    });
    try {
      final r = await http
          .get(Uri.parse('${widget.url}/api/status'))
          .timeout(const Duration(seconds: 5));
      if (!mounted) return;
      setState(() {
        _checking = false;
        _reachable = r.statusCode == 200;
        _probe = 'HTTP ${r.statusCode} · ${r.body.length} 字节';
      });
      if (r.statusCode == 200) {
        _initWebView();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _reachable = false;
        _probe = e.toString();
      });
    }
  }

  void _initWebView() {
    final web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
        onWebResourceError: (e) {
          if (!mounted) return;
          setState(() => _webError =
              '加载失败：${e.description}（${e.errorType} ${e.errorCode}）');
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _progress = 100);
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
    setState(() => _web = web);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SnowStyle.background,
      appBar: AppBar(
        title: const Text('本地面板'),
        actions: [
          IconButton(
            tooltip: '重新检测并加载',
            onPressed: _probeAndLoad,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        bottom: _web != null && _progress < 100
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                    value: _progress / 100, minHeight: 2),
              )
            : null,
      ),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (_checking) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text('正在检测 127.0.0.1:6199 …'),
        ]),
      );
    }
    if (!_reachable) {
      return _errorPanel();
    }
    if (_webError != null) {
      return _errorPanel();
    }
    if (_web == null) {
      return _errorPanel();
    }
    return WebViewWidget(controller: _web!);
  }

  Widget _errorPanel() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.cloud_off_rounded,
                  color: Color(0xFFE0555A), size: 26),
              const SizedBox(width: 8),
              Text(_webError != null ? '页面加载失败' : '面板未连接',
                  style: const TextStyle(fontSize: 17,
                      fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 12),
            Text(
              _webError ??
                  '无法访问 ${widget.url}\n\n'
                  '请确认：\n'
                  '1) 已在「本地部署」完成一键部署（QQBot 已启动）\n'
                  '2) 一键部署的终端日志里出现「QQBot started」\n'
                  '3) 再点下方「重新检测」',
              style: const TextStyle(fontSize: 12.5, color: SnowStyle.muted,
                  height: 1.6),
            ),
            if (_probe.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F2F5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SelectableText('探测结果：$_probe',
                    style: const TextStyle(fontSize: 11,
                        fontFamily: 'Menlo', height: 1.4)),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _probeAndLoad,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('重新检测'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
