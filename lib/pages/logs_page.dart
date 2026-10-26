import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/bridge.dart';

/// 系统信息页 — 服务状态 / 认证 / 协议 / 会话 / Core 版本
class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  bool _busy = false;
  String? _statusText;
  String? _authText;
  String? _agreementText;
  List<String> _docs = const [];
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = appState.client;
    if (api == null) return;
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      _statusText = (await api.status()).toString();
      _authText = (await api.authState()).toString();
      final ag = await api.agreements();
      _agreementText = '版本 ${ag['version']} · 需同意 ${ag['consentRequired']}';
      _docs = ((ag['documents'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map((d) => '${d['title'] ?? d['id']}（${d['declaredVersion']}）')
          .toList();
    } catch (e) {
      _err = e.toString();
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ver = SnowLumaBridge.call('core.version');
    final stored = SnowLumaBridge.call('session.load');
    return Scaffold(
      appBar: AppBar(
        title: const Text('系统信息'),
        actions: [
          IconButton(
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _card(text, Icons.cloud_outlined, '服务器',
                appState.serverLabel, true),
            _card(text, Icons.fingerprint_outlined, '认证',
                _authText ?? (stored['exists'] == true ? '已保存会话' : '无会话'),
                stored['exists'] == true),
            _card(text, Icons.dns_outlined, '服务状态', _statusText ?? '未查询',
                _statusText == '{"status":"running"}'),
            _card(text, Icons.description_outlined, '协议', _agreementText ?? '-',
                false),
            if (_docs.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _docs
                      .map((d) => Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(d, style: const TextStyle(fontSize: 11)),
                          ))
                      .toList(),
                ),
              ),
            _card(text, Icons.memory_outlined, 'Rust Core',
                'v${ver['version']} · ${ver['platform']} · ${ver['arch']}', true),
            _card(text, Icons.phone_android_outlined, '宿主平台',
                hostPlatformLabel(), true),
            if (_err != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 18, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_err!, style: text.bodySmall)),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '凭据（token）受保护存储于本机 App 沙盒，不会上传或展示。',
                      style: text.bodySmall?.copyWith(color: Colors.grey.shade600),
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

  Widget _card(TextTheme text, IconData icon, String title, String value, bool ok) =>
      Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.grey.shade200)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, size: 20, color: ok ? Colors.green : Colors.grey.shade500),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: text.bodySmall
                            ?.copyWith(color: Colors.grey.shade600)),
                    const SizedBox(height: 2),
                    SelectableText(
                      value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
