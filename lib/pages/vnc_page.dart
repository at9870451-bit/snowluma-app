import 'dart:async';
import 'dart:convert';

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
    // HTTPS 域名（Let's Encrypt 正式证书 + nginx 反代 WebSocket）
    const host = 'www.daykai.asia';
    _vncUrl = 'https://$host/novnc/vnc.html?autoconnect=true';
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

  /// 账号密码登录：弹窗输入 QQ 号+密码 -> POST 到服务器 -> xdotool 模拟鼠标输入
  Future<void> _qqPwdLogin() async {
    final uinCtl = TextEditingController();
    final pwdCtl = TextEditingController();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          bool loading = false;
          String msg = '';
          return AlertDialog(
            backgroundColor: const Color(0xFF1D1E24),
            title: const Text('QQ 账号密码登录',
                style: TextStyle(color: Colors.white, fontSize: 16)),
            content: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: uinCtl,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'QQ 号',
                      labelStyle: TextStyle(color: Colors.white54),
                      hintText: '输入 QQ 号码',
                      hintStyle: TextStyle(color: Colors.white24),
                      filled: true,
                      fillColor: const Color(0xFF2A2C36),
                      border: OutlineInputBorder(
                        borderRadius: const BorderRadius.all(Radius.circular(10)),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: pwdCtl,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: const InputDecoration(
                      labelText: '密码',
                      labelStyle: TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF2A2C36),
                      border: OutlineInputBorder(
                        borderRadius: const BorderRadius.all(Radius.circular(10)),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  if (msg.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(msg,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                          maxLines: 3),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消', style: TextStyle(color: Colors.white54)),
              ),
              FilledButton(
                onPressed: loading
                    ? null
                    : () async {
                        setDlg(() {
                          loading = true;
                          msg = '正在登录…';
                        });
                        try {
                          final r = await http.post(
                            Uri.parse('https://www.daykai.asia/qq/login'),
                            headers: {'Content-Type': 'application/json'},
                            body: jsonEncode({
                              'uin': uinCtl.text.trim(),
                              'password': pwdCtl.text,
                            }),
                          ).timeout(const Duration(seconds: 35));
                          final j = jsonDecode(r.body) as Map;
                          setDlg(() {
                            msg = j['ok'] == true
                                ? '✅ 已输入并点击登录，请看画面状态'
                                : '❌ ${j['msg'] ?? '失败'}';
                            loading = false;
                          });
                        } catch (e) {
                          setDlg(() {
                            msg = '❌ 请求失败: $e';
                            loading = false;
                          });
                        }
                      },
                child: loading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('登录'),
              ),
            ],
          );
        },
      ),
    );
    uinCtl.dispose();
    pwdCtl.dispose();
  }

  /// 强制刷新：通知服务器点击 QQ 的「刷新」重新生成二维码
  Future<void> _forceRefreshQr() async {
    try {
      await http.get(Uri.parse('https://www.daykai.asia/qr.png?refresh=1')).timeout(const Duration(seconds: 60));
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
            // VNC 实时画面说明条（显示 QQ 登录界面动态状态）
            Material(
              color: const Color(0xFF1D1E24),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Row(
                  children: [
                    const Icon(Icons.qr_code_2, size: 16, color: Colors.white70),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'QQ 登录界面实时画面',
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: _qqPwdLogin,
                      icon: const Icon(Icons.lock_open, size: 18, color: Colors.white70),
                      tooltip: '账号密码登录',
                    ),
                    IconButton(
                      onPressed: _forceRefreshQr,
                      icon: const Icon(Icons.refresh, size: 18, color: Colors.white70),
                      tooltip: '强制刷新二维码',
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
                      'VNC 实时画面显示 QQ 登录界面，直接用手机 QQ 扫描画面中的二维码登录；也可点按画面操作 QQ，登录后回主页刷新查看账号',
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