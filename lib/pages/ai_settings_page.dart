import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/api_client.dart';

import '../core/api_client.dart';

/// AI 助手设置页
///
/// 配置 SnowLuma AI 网关：启用开关、OpenAI 兼容接口、模型、人设（persona）。
/// 人设内容会注入到每次 AI 回复的 system prompt，让 QQ 自动回复符合人设。
class AiSettingsPage extends StatefulWidget {
  const AiSettingsPage({super.key});

  @override
  State<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends State<AiSettingsPage> {
  bool _loading = true;
  bool _saving = false;
  String _message = '';

  bool _enabled = false;
  String _apiKey = '';
  String _baseUrl = 'https://api.deepseek.com/v1';
  String _model = 'deepseek-chat';
  String _persona = '';
  double _temperature = 0.7;
  int _maxTokens = 500;

  @override
  void initState() {
    super.initState();
    _load();
  }

  SnowLumaApiClient? _api() => appState.client;

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = _api();
      if (api == null) {
        setState(() => _message = '未登录，无法读取 AI 配置');
        return;
      }
      final r = await api.aiConfig();
      final c = (r['config'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
      setState(() {
        _enabled = c['enabled'] == true;
        _apiKey = (c['apiKey'] as String?) ?? '';
        _baseUrl = (c['baseUrl'] as String?) ?? _baseUrl;
        _model = (c['model'] as String?) ?? _model;
        _persona = (c['persona'] as String?) ?? '';
        _temperature = ((c['temperature'] as num?)?.toDouble()) ?? 0.7;
        _maxTokens = (c['maxTokens'] as num?)?.toInt() ?? 500;
      });
    } catch (e) {
      setState(() => _message = '加载失败：$e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _message = '';
    });
    try {
      final api = _api();
      if (api == null) {
        setState(() => _message = '未登录，无法保存');
        return;
      }
      final r = await api.aiSaveConfig({
        'enabled': _enabled,
        'apiKey': _apiKey,
        'baseUrl': _baseUrl.trim(),
        'model': _model.trim(),
        'persona': _persona.trim(),
        'temperature': _temperature,
        'maxTokens': _maxTokens,
      });
      setState(() =>
          _message = r['ok'] == true ? '已保存，AI 助手${_enabled ? '已启用' : '已关闭'}' : '${r['msg'] ?? '保存失败'}');
    } catch (e) {
      setState(() => _message = '保存失败：$e');
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 助手设置')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _section('开关'),
                SwitchListTile(
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                  title: const Text('启用 AI 自动回复'),
                  subtitle: const Text('QQ 收到消息后由 AI 按人设自动回复'),
                ),
                _section('模型接口（OpenAI 兼容）'),
                _field('API 地址', _baseUrl, (v) => _baseUrl = v),
                _field('模型名', _model, (v) => _model = v, hint: 'deepseek-chat / gpt-4o-mini …'),
                _field('API Key', _apiKey, (v) => _apiKey = v, obscure: true, hint: 'sk-…'),
                _section('人设（Persona）'),
                _personaField(),
                _section('参数'),
                _slider('回复随机度', _temperature, 0.0, 1.5, (v) => _temperature = v),
                _slider('最大长度', _maxTokens.toDouble(), 100, 2000, (v) => _maxTokens = v.toInt()),
                const SizedBox(height: 12),
                if (_message.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(_message, style: TextStyle(color: _message.contains('失败') ? Colors.red : Colors.green)),
                  ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('保存设置'),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8, left: 4),
        child: Text(title.toUpperCase(),
            style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1)),
      );

  Widget _field(String label, String value, void Function(String) onchg,
      {String? hint, bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: TextEditingController(text: value),
        obscureText: obscure,
        decoration: InputDecoration(labelText: label, hintText: hint),
        onChanged: onchg,
      ),
    );
  }

  Widget _personaField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            maxLines: 5,
            controller: TextEditingController(text: _persona),
            decoration: const InputDecoration(
              labelText: '人设描述',
              alignLabelWithHint: true,
              hintText: '例如：你是一个温柔耐心的姐姐，喜欢用 emoji，说话简短俏皮。',
            ),
            onChanged: (v) => _persona = v,
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () {
              final c = TextEditingController(text: _persona);
              setState(() => _persona = c.text);
            },
            child: const Text('加载已保存的人设'),
          ),
          const Text('提示：人设内容会在每次 AI 回复时作为系统指令注入，决定 QQ 自动回复的语气与行为。',
              style: TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _slider(String label, double value, double min, double max, void Function(double) onchg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${label}：${value.toStringAsFixed(label.contains('长度') ? 0 : 2)}'),
        Slider(value: value, min: min, max: max, onChanged: onchg),
      ],
    );
  }
}
