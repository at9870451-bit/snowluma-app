import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/qqbot_client.dart';
import '../ai_settings_page.dart';
import 'q_ui.dart';

/// QQBot AI / 生图配置总览（只读）
///
/// 说明：配置写入统一走 AI 网关（8090 /ai/config，见 AI 设置页），
/// 这里通过 6199 /api/config 只读展示 QQBot 侧真实生效的值，
/// 便于核对「App 保存的」与「机器人实际在用的」是否一致。
class QqbotAiConfigPage extends StatefulWidget {
  const QqbotAiConfigPage({super.key});

  @override
  State<QqbotAiConfigPage> createState() => _QqbotAiConfigPageState();
}

class _QqbotAiConfigPageState extends State<QqbotAiConfigPage> {
  QqbotClient get _api => QqbotClient.fromSnowLuma(appState.baseUrl);

  bool _loading = true;
  String? _err;
  Map<String, dynamic> _cfg = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _cfg.isEmpty;
      _err = null;
    });
    try {
      final c = await _api.config();
      if (!mounted) return;
      setState(() {
        _cfg = c;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_cfg.isEmpty) _err = e.toString();
      });
    }
  }

  Map<String, dynamic> _sec(String k) =>
      (_cfg[k] as Map?)?.cast<String, dynamic>() ?? const {};

  String _mask(String key) {
    if (key.isEmpty) return '未设置';
    if (key.length <= 8) return '••••';
    return '${key.substring(0, 4)}••••${key.substring(key.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI / 生图配置'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Builder(builder: (context) {
        if (_loading) return const QLoading(text: '读取 QQBot 配置…');
        if (_err != null) return QError(message: _err!, onRetry: _load);
        final ai = _sec('ai');
        final image = _sec('image');
        final tts = _sec('tts');
        final knowledge = _sec('knowledge');
        final memory = _sec('memory');
        final auto = _sec('auto_mode');

        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 120),
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: kIosBlue.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 17, color: kIosBlue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('这里显示机器人侧实际生效的配置（只读）。修改请到「AI 设置」。',
                          style: TextStyle(fontSize: 11.5, height: 1.4)),
                    ),
                  ],
                ),
              ),
              _card('对话模型', Icons.smart_toy_outlined, [
                _kv('状态', ai['enabled'] == true ? '已启用' : '已关闭',
                    color: ai['enabled'] == true
                        ? const Color(0xFF34C759)
                        : const Color(0xFFFF3B30)),
                _kv('模型', '${ai['model'] ?? '-'}'),
                _kv('接口', '${ai['base_url'] ?? '-'}', mono: true),
                _kv('Key', _mask('${ai['api_key'] ?? ''}'), mono: true),
                _kv('温度', '${ai['temperature'] ?? '-'}'),
                _kv('历史轮数', '${ai['max_history'] ?? '-'}'),
                _kv('回复模式', '${ai['reply_mode'] ?? '-'}'),
                if (ai['active_persona'] != null)
                  _kv('当前人设', '${ai['active_persona']}'),
              ]),
              _card('触发方式', Icons.notifications_active_outlined, [
                _kv('自主聊天', auto['enabled'] == true ? '开' : '关'),
                _kv('被戳', auto['on_poke'] == true ? '开' : '关'),
                _kv('被@', auto['on_at'] == true ? '开' : '关'),
                _kv('群里任意消息概率',
                    '${(((auto['any_probability'] as num?) ?? 0) * 100).toStringAsFixed(0)}%'),
                _kv('关键词',
                    ((auto['keywords'] as List?) ?? const []).join('、').isEmpty
                        ? '未设置'
                        : ((auto['keywords'] as List?) ?? const []).join('、')),
              ]),
              _card('AI 生图', Icons.brush_outlined, [
                _kv('状态', image['enabled'] == true ? '已启用' : '已关闭',
                    color: image['enabled'] == true
                        ? const Color(0xFF34C759)
                        : const Color(0xFFFF3B30)),
                _kv('模型', '${image['model'] ?? '-'}'),
                _kv('接口', '${image['base_url'] ?? '-'}', mono: true),
                _kv('Key', _mask('${image['api_key'] ?? ''}'), mono: true),
                _kv('默认比例', '${image['default_ratio'] ?? '-'}'),
                _kv('分辨率', '${image['default_resolution'] ?? '-'}'),
                _kv('超时', '${image['timeout'] ?? '-'} 秒'),
              ]),
              _card('语音 TTS', Icons.record_voice_over_outlined, [
                _kv('状态', tts['enabled'] == true ? '已启用' : '已关闭'),
                _kv('模型', '${tts['model'] ?? '-'}'),
                _kv('音色', '${tts['voice'] ?? '-'}'),
                _kv('语音概率',
                    '${(((tts['reply_rate'] as num?) ?? 0) * 100).toStringAsFixed(0)}%'),
                _kv('格式', '${tts['response_format'] ?? '-'}'),
              ]),
              _card('知识库 / 记忆', Icons.menu_book_outlined, [
                _kv('知识库', knowledge['enabled'] == true ? '已启用' : '已关闭'),
                _kv('召回条数', '${knowledge['top_k'] ?? '-'}'),
                _kv('记忆', memory['enabled'] == true ? '已启用' : '已关闭'),
                _kv('记忆摘要',
                    memory['summary_enabled'] == true ? '开' : '关'),
              ]),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AiSettingsPage())),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('去 AI 设置里修改'),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _card(String title, IconData icon, List<Widget> rows) {
    return QCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: kIosBlue),
              const SizedBox(width: 7),
              Text(title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          ...rows,
        ],
      ),
    );
  }

  Widget _kv(String k, String v, {bool mono = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            child: Text(k,
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(
              v,
              style: TextStyle(
                fontSize: 12.5,
                fontFamily: mono ? 'Menlo' : null,
                color: color ?? Colors.black87,
                fontWeight: color != null ? FontWeight.w600 : null,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}