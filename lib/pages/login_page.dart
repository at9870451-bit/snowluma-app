import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/api_client.dart';
import '../core/bridge.dart';

/// 连接页 — 服务器地址 + 密码 → 登录 / 协议同意 / 改初始密码
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onConnected});
  final VoidCallback onConnected;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _urlC = TextEditingController();
  final _pwC = TextEditingController();
  final _npC = TextEditingController();
  bool _busy = false;
  String? _err;
  bool _showPw = false;
  bool _showNp = false;
  List<Map<String, dynamic>> _rules = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _urlC.text = appState.baseUrl;
      _npC.addListener(_refreshRules);
    });
  }

  @override
  void dispose() {
    _urlC.dispose();
    _pwC.dispose();
    _npC.dispose();
    super.dispose();
  }

  void _refreshRules() {
    final r = SnowLumaBridge.call('password.check_strength',
        {'password': _npC.text});
    setState(() => _rules = (r['rules'] as List? ?? const []).cast());
  }

  Future<void> _connect() async {
    final url = _urlC.text.trim();
    final pw = _pwC.text;
    if (url.isEmpty || pw.isEmpty) {
      setState(() => _err = '请填写服务器地址和密码');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    final r = await appState.connect(
      url: url,
      password: pw,
      newPassword: _npC.text,
    );
    if (!mounted) return;
    if (r.ok) {
      widget.onConnected();
    } else {
      setState(() {
        _busy = false;
        _err = r.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('SnowLuma'),
        leading: const SizedBox(width: 8),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.cake_outlined, size: 44, color: Colors.indigo.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('连接 SnowLuma', style: text.titleLarge),
                        const SizedBox(height: 2),
                        Text('QQ 原生会话运行时 · 前端',
                            style: text.bodySmall?.copyWith(color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              _field(
                controller: _urlC,
                label: '服务器地址',
                hint: 'http://154.12.16.204:5099',
                icon: Icons.dns_outlined,
                suffix: _coreInfo(context),
              ),
              const SizedBox(height: 14),
              _field(
                controller: _pwC,
                label: '密码',
                hint: 'WebUI 密码',
                icon: Icons.lock_outline,
                obscure: true,
                secure: _showPw,
                onToggleSecure: () => setState(() => _showPw = !_showPw),
              ),
              const SizedBox(height: 14),
              _field(
                controller: _npC,
                label: '新密码（仅首次连接需修改初始密码）',
                hint: '可选，留空跳过',
                icon: Icons.key_outlined,
                obscure: true,
                secure: _showNp,
                onToggleSecure: () => setState(() => _showNp = !_showNp),
              ),
              if (_rules.isNotEmpty) ...[
                const SizedBox(height: 8),
                ..._rules.map((r) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Icon(
                            (r['valid'] as bool?) == true
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            size: 14,
                            color: (r['valid'] as bool?) == true
                                ? Colors.green
                                : Colors.grey.shade400,
                          ),
                          const SizedBox(width: 6),
                          Text(r['label'] as String,
                              style: text.bodySmall?.copyWith(
                                  color: Colors.grey.shade600, fontSize: 12)),
                        ],
                      ),
                    )),
              ],
              const SizedBox(height: 20),
              if (_err != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, size: 18, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_err!, style: text.bodySmall)),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _busy ? null : _connect,
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.login),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(_busy ? '连接中…' : '连接',
                      style: const TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 12),
              Text('凭据受保护存储于本机，不会上传',
                  textAlign: TextAlign.center,
                  style: text.bodySmall?.copyWith(color: Colors.grey.shade500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscure = false,
    bool secure = false,
    VoidCallback? onToggleSecure,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure ? !secure : false,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18),
        suffixIcon: suffix ??
            (obscure
                ? IconButton(
                    onPressed: onToggleSecure,
                    icon: Icon(
                        secure ? Icons.visibility : Icons.visibility_off,
                        size: 18),
                  )
                : null),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300)),
      ),
    );
  }

  Widget _coreInfo(BuildContext context) {
    try {
      final v = SnowLumaBridge.call('core.version');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('Rust Core ${v['version']}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.green.shade600, fontSize: 11)),
          Text(hostPlatformLabel(),
              style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      );
    } catch (_) {
      return const SizedBox();
    }
  }

}
