import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/app_state.dart';
import '../core/bridge.dart';

/// 扫码登录页 — 内嵌 noVNC（QQ 远程桌面），自动填入远程桌面密码直接连接
class VncPage extends StatefulWidget {
  const VncPage({super.key});

  @override
  State<VncPage> createState() => _VncPageState();
}

class _VncPageState extends State<VncPage> {
  late final WebViewController _web;
  final _pwCtl = TextEditingController();
  bool _loading = true;
  String _vncUrl = '';
  String _qrUrl = '';
  int _qrTick = 0;
  Timer? _qrTimer;

  @override
  void initState() {
    super.initState();
    // 读取 VNC 密码（Rust 保护存储）
    try {
      final r = SnowLumaBridge.call('session.load_vnc');
      _pwCtl.text = r['password'] as String? ?? '';
    } catch (_) {}
    // 从服务器地址解析 host，拼 noVNC URL 与二维码 URL
    final base = appState.baseUrl;
    final uri = Uri.tryParse(base);
    final host = uri?.host ?? base;
    _vncUrl = 'http://$host:6081/vnc.html?autoconnect=true';
    _qrUrl = 'http://$host:8088/qr.png';
    _qrTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      setState(() => _qrTick++); // 触发二维码图刷新
    });
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF111216))
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          _autoConnect();
          if (mounted) setState(() => _loading = false);
        },
        onWebResourceError: (_) {
          if (mounted) setState(() => _loading = false);
        },
      ))
      ..loadRequest(Uri.parse(_vncUrl));
  }

  /// 页面加载完成：把远程桌面密码填入 noVNC 并点击连接
  void _autoConnect() {
    if (_pwCtl.text.isEmpty) return;
    final js = '''
(function() {
  var tries = 0;
  function fill() {
    var p = document.getElementById('passwordInput');
    var b = document.getElementById('connectButton');
    if (p) { p.value = '${_pwCtl.text}'; }
    if (b) {
      b.click();
      return true;
    }
    return false;
  }
  if (!fill()) {
    var t = setInterval(function() {
      tries++;
      if (fill()) { clearInterval(t); }
      else if (tries > 40) { clearInterval(t); }
    }, 500);
  }
})();
''';
    _web.runJavaScript(js);
  }

  /// 强制刷新：通知服务器点击 QQ 的「刷新」重新生成二维码
  Future<void> _forceRefreshQr() async {
    try {
      await http.get(Uri.parse('$_qrUrl?refresh=1')).timeout(const Duration(seconds: 60));
    } catch (_) {}
    if (mounted) setState(() => _qrTick++);
  }

  Future<void> _savePassword() async {
    try {
      SnowLumaBridge.call('session.save_vnc', {'password': _pwCtl.text});
    } catch (e) {
      debugPrint('保存 VNC 密码失败: $e');
    }
  }

  @override
  void dispose() {
    _qrTimer?.cancel();
    _pwCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: const Color(0xFF111216),
      appBar: AppBar(
        title: const Text('扫码登录 QQ'),
        backgroundColor: const Color(0xFF111216),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 密码输入条
            Material(
              color: const Color(0xFF1D1E24),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.key_rounded, size: 18, color: Colors.white70),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _pwCtl,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: '远程桌面密码（VNC_PASSWD）',
                          hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                          isDense: true,
                          filled: true,
                          fillColor: const Color(0xFF2A2C36),
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _savePassword();
                        if (_pwCtl.text.isNotEmpty) _autoConnect();
                      },
                      icon: const Icon(Icons.smartphone, size: 16),
                      label: const Text('连接', style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ),
            // 二维码卡（直接扫码，30 秒自动刷新）
            Material(
              color: const Color(0xFF1D1E24),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.qr_code_2, size: 16, color: Colors.white70),
                        const SizedBox(width: 6),
                        Text('手机 QQ 扫码登录（二维码每 30 秒自动刷新）',
                            style: TextStyle(fontSize: 12, color: Colors.white70)),
                        const Spacer(),
                        IconButton(
                          onPressed: _forceRefreshQr,
                          icon: const Icon(Icons.refresh, size: 18, color: Colors.white70),
                          tooltip: '强制刷新二维码',
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(6),
                        child: Image.network(
                          '$_qrUrl?t=$_qrTick',
                          width: 200,
                          height: 190,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Container(
                            width: 200,
                            height: 190,
                            color: const Color(0xFF2A2C36),
                            alignment: Alignment.center,
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.error_outline, color: Colors.white54),
                                SizedBox(height: 6),
                                Text('二维码加载失败', style: TextStyle(color: Colors.white54, fontSize: 12)),
                              ],
                            ),
                          ),
                          loadingBuilder: (_, child, progress) => progress == null
                              ? child
                              : Container(
                                  width: 200,
                                  height: 190,
                                  color: const Color(0xFF2A2C36),
                                  alignment: Alignment.center,
                                  child: const CircularProgressIndicator(color: Colors.white54),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // noVNC WebView
            Expanded(
              child: Stack(
                children: [
                  WebViewWidget(controller: _web),
                  if (_loading)
                    Container(
                      color: const Color(0xFF111216),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: Colors.white70),
                          const SizedBox(height: 12),
                          Text('正在连接远程桌面…',
                              style: text.bodySmall
                                  ?.copyWith(color: Colors.white70)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            // 操作提示
            Container(
              color: const Color(0xFF1D1E24),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: Colors.white54),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '直接扫上方二维码即可登录；下方为远程桌面（可操作 QQ），登录后回主页刷新查看账号',
                      style: TextStyle(fontSize: 11, color: Colors.white54),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}