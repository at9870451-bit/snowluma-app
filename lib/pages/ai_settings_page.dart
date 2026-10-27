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
  String _replyStyle = 'human'; // human=简短真人感, ai=AI感
  double _temperature = 0.7;
  int _maxTokens = 500;

  // ---- 自主模式 ----
  bool _selfMode = false;
  bool _triggerPoke = true;
  bool _triggerAt = true;
  bool _triggerRandom = false;
  int _randomRate = 10;
  String _keywords = '';
  bool _skipAtOthers = true;

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
        _replyStyle = (c['replyStyle'] as String?) ?? 'human';
        _temperature = ((c['temperature'] as num?)?.toDouble()) ?? 0.7;
        _maxTokens = (c['maxTokens'] as num?)?.toInt() ?? 500;
        _selfMode = c['selfMode'] == true;
        _triggerPoke = c['triggerPoke'] != false;
        _triggerAt = c['triggerAt'] != false;
        _triggerRandom = c['triggerRandom'] == true;
        _randomRate = (c['randomRate'] as num?)?.toInt() ?? 10;
        _keywords = (c['keywords'] as String?) ?? '';
        _skipAtOthers = c['skipAtOthers'] != false;
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
        'replyStyle': _replyStyle,
        'temperature': _temperature,
        'maxTokens': _maxTokens,
        'selfMode': _selfMode,
        'triggerPoke': _triggerPoke,
        'triggerAt': _triggerAt,
        'triggerRandom': _triggerRandom,
        'randomRate': _randomRate,
        'keywords': _keywords.trim(),
        'skipAtOthers': _skipAtOthers,
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
                _section('回复风格'),
                _styleTile(),
                _section('自主模式'),
                _selfModeTile(),
                _triggerTile(Icons.touch_app_outlined, '被戳一戳时', _triggerPoke, (v) => _triggerPoke = v),
                _triggerTile(Icons.person_pin_outlined, '被@时', _triggerAt, (v) => _triggerAt = v),
                _triggerTile(Icons.shuffle, '随机接话', _triggerRandom, (v) => _triggerRandom = v),
                if (_triggerRandom)
                  _slider('接话概率 %', _randomRate.toDouble(), 0.0, 100.0, (v) => _randomRate = v.toInt()),
                _keywordField(),
                _triggerTile(Icons.block, '@了别人的消息自动跳过', _skipAtOthers, (v) => _skipAtOthers = v),
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 4),
                  child: Text('@了本人必回；未启用自主模式时群消息默认全部回复。',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                ),
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

  Widget _styleTile() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: _styleChip('简短真人感', '像真人在 QQ 发消息：短句、口语、不客套', _replyStyle == 'human',
                  () => setState(() => _replyStyle = 'human')),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _styleChip('AI感', '完整、清晰、有条理，友好周到', _replyStyle == 'ai',
                  () => setState(() => _replyStyle = 'ai')),
            ),
          ],
        ),
      );

  Widget _styleChip(String title, String desc, bool selected, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: selected ? const Color(0x1F007AFF) : const Color(0xFFF5F5F7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? const Color(0xFF007AFF) : Colors.transparent),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      color: selected ? const Color(0xFF007AFF) : const Color(0xFF1D1D1F),
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
              const SizedBox(height: 3),
              Text(desc, style: const TextStyle(color: Color(0xFF86868B), fontSize: 10.5)),
            ],
          ),
        ),
      );

  Widget _selfModeTile() => SwitchListTile(
        value: _selfMode,
        onChanged: (v) => setState(() => _selfMode = v),
        title: const Text('启用自主模式'),
        subtitle: const Text('需先在上方启用 AI；决定哪些消息触发 AI 回复'),
      );

  Widget _triggerTile(IconData icon, String title, bool value, void Function(bool) onchg) => SwitchListTile(
        value: value,
        onChanged: onchg,
        secondary: Icon(icon),
        title: Text(title),
      );

  Widget _keywordField() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: TextField(
          controller: TextEditingController(text: _keywords),
          decoration: const InputDecoration(
            labelText: '触发关键词（逗号分隔）',
            hintText: 'koko, 哈哈, 在吗',
          ),
          onChanged: (v) => _keywords = v,
        ),
      );

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
