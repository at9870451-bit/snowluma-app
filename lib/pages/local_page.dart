import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/snow_theme.dart';

/// 本地部署 — 查看服务器连接、面板/网关地址与本地模型说明。
///
/// 数据来源：
///   appState.baseUrl / serverLabel：当前服务器地址
///   GET /api/status（若已连接）：服务器在线状态
///   本地模型（Ollama）为服务器侧能力，App 内仅在 AI 设置中可切换。
class LocalPage extends StatefulWidget {
  const LocalPage({super.key});

  @override
  State<LocalPage> createState() => _LocalPageState();
}

class _LocalPageState extends State<LocalPage> {
  Map<String, dynamic>? _status;
  bool _checking = true;
  String? _err;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _err = null;
    });
    try {
      final api = appState.client;
      if (api == null) {
        if (mounted) {
          setState(() {
            _checking = false;
            _err = '尚未连接服务器';
          });
        }
        return;
      }
      final r = await api.status();
      if (!mounted) return;
      setState(() {
        _status = r;
        _checking = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _err = e.toString();
      });
    }
  }

  String get _host {
    final u = Uri.tryParse(appState.baseUrl);
    return (u != null && u.host.isNotEmpty) ? u.host : 'localhost';
  }

  @override
  Widget build(BuildContext context) {
    final running = _status?['running'] == true;
    final connected = _status?['connected'] == true;
    return Scaffold(
      backgroundColor: SnowStyle.background,
      appBar: AppBar(title: const Text('本地部署')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
              children: [
                const Text('LOCAL DEPLOY',
                    style: TextStyle(fontSize: 11, letterSpacing: 2,
                        color: SnowStyle.muted, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text('本地部署',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800,
                        letterSpacing: -0.8)),
                const SizedBox(height: 18),
                _statusBanner(running, connected),
                const SizedBox(height: 16),
                _section('连接信息'),
                _row('服务器地址', appState.baseUrl.isEmpty ? '未连接' : appState.baseUrl,
                    mono: true),
                _row('控制面板', 'http://$_host:6199', mono: true),
                _row('AI 网关', 'http://$_host:8090', mono: true),
                _row('QQ 接入', 'ws://$_host:3001', mono: true),
                const SizedBox(height: 18),
                _section('本地模型（Ollama）'),
                _card(
                  '本地模型说明',
                  '服务器可选用 Ollama 本地模型（qwen2.5:0.5b）作为兜底，'
                  '不消耗外部 API 额度，1~2 秒返回。',
                ),
                _card(
                  '切换位置',
                  '在底部导航「AI」→ 模型来源中，打开「服务器本地模型」开关即可启用。',
                ),
                const SizedBox(height: 18),
                _section('部署检查'),
                _card(
                  '在线状态',
                  _checking
                      ? '检查中…'
                      : (_err != null
                          ? '服务器不可达：$_err'
                          : (running && connected
                              ? '运行中 · QQ 已连接'
                              : (running ? '运行中 · QQ 未连接' : '未运行'))),
                  leading: Icon(
                    running && connected
                        ? Icons.check_circle_rounded
                        : Icons.info_outline_rounded,
                    color: running && connected
                        ? const Color(0xFF34C759)
                        : SnowStyle.muted,
                  ),
                  trailing: TextButton(
                    onPressed: _checking ? null : _check,
                    child: const Text('重新检测'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusBanner(bool running, bool connected) {
    final ok = running && connected;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: SnowStyle.card(color: SnowStyle.ink, radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: ok ? const Color(0xFF9BD1B1) : const Color(0xFFB9A795),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('SERVER STATUS',
                  style: TextStyle(color: Color(0xFFB5B8C2), fontSize: 10,
                      letterSpacing: 1.4, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 14),
          const Text('部署状态',
              style: TextStyle(color: Colors.white, fontSize: 21,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            _checking
                ? '检查中…'
                : (_err != null
                    ? '连接失败：$_err'
                    : (ok ? '运行中 · QQ 已连接' : (running ? '运行中 · QQ 未连接' : '未运行'))),
            style: const TextStyle(color: Color(0xFFC5C7CF), fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
        child: Text(title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                letterSpacing: 1, color: SnowStyle.muted)),
      );

  Widget _card(String title, String desc,
      {Widget? leading, Widget? trailing}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: SnowStyle.card(),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 10)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(desc,
                    style: const TextStyle(fontSize: 12.5, color: SnowStyle.muted,
                        height: 1.45)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool mono = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: SnowStyle.card(),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(fontSize: 12.5, color: SnowStyle.muted)),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12.5,
                fontFamily: mono ? 'Menlo' : null,
                fontFeatures: SnowStyle.tabular,
              ),
            ),
          ),
        ],
      ),
    );
  }
}