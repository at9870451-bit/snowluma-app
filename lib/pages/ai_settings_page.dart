import 'package:flutter/material.dart';

import '../core/app_state.dart';
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
  /// 上次成功的配置缓存：进入页面先秒显，再后台刷新（降低感知延迟）
  static Map<String, dynamic>? _cachedConfig;
  static int _cachedChatCount = 0;

  bool _loading = true;
  bool _saving = false;
  String _message = '';

  bool _enabled = false;
  String _apiKey = '';
  String _baseUrl = 'https://api.deepseek.com/v1';
  String _model = 'deepseek-chat';
  String _persona = '';
  String _replyStyle = 'human'; // human=简短真人感, ai=AI感
  String _age = '';       // 人设年龄
  String _gender = '';    // 人设性别
  String _masterUin = '';   // 主人 QQ 号（逗号分隔可多个）
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
  bool _learnFromChat = true;  // 学习真人聊天（防 AI 感）
  bool _memoryMode = true;     // 群聊记忆
  int _memoryTurns = 8;        // 记忆轮数
  int _chatCount = 0;          // 已学习条数

  // ---- 话痨连发 / 随机@ / 主动发言 ----
  int _multiRate = 0;          // 话痨连发概率 %
  int _multiMax = 3;           // 连发最多条数
  int _chattyAtRate = 0;       // 连发时随机 @ 他人概率 %
  int _idleActiveRate = 0;     // 主动发言概率 %（5分钟每群最多1次）

  // ---- 主动开话题（冷场检查）----
  int _idleInterval = 30;      // 冷场检查间隔（分钟）
  int _idleProb = 60;          // 开口概率 %
  int _idleActiveWindow = 90;  // 群活跃判定窗口（分钟）
  int _idleMaxChars = 60;      // 话题长度上限
  bool _idleSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  SnowLumaApiClient? _api() => appState.client;

  void _applyConfig(Map<String, dynamic> c, int chatCount) {
    _enabled = c['enabled'] == true;
    _apiKey = (c['apiKey'] as String?) ?? '';
    _baseUrl = (c['baseUrl'] as String?) ?? _baseUrl;
    _model = (c['model'] as String?) ?? _model;
    _persona = (c['persona'] as String?) ?? '';
    _replyStyle = (c['replyStyle'] as String?) ?? 'human';
    _age = (c['age'] as String?) ?? '';
    _gender = (c['gender'] as String?) ?? '';
    _masterUin = (c['masterUin'] as String?) ?? '';
    _temperature = ((c['temperature'] as num?)?.toDouble()) ?? 0.7;
    _maxTokens = (c['maxTokens'] as num?)?.toInt() ?? 500;
    _selfMode = c['selfMode'] == true;
    _triggerPoke = c['triggerPoke'] != false;
    _triggerAt = c['triggerAt'] != false;
    _triggerRandom = c['triggerRandom'] == true;
    _randomRate = (c['randomRate'] as num?)?.toInt() ?? 10;
    _keywords = (c['keywords'] as String?) ?? '';
    _skipAtOthers = c['skipAtOthers'] != false;
    _learnFromChat = c['learnFromChat'] != false;
    _memoryMode = c['memoryMode'] != false;
    _memoryTurns = (c['memoryTurns'] as num?)?.toInt() ?? 8;
    _multiRate = (c['multiRate'] as num?)?.toInt() ?? 0;
    _multiMax = (c['multiMax'] as num?)?.toInt() ?? 3;
    _chattyAtRate = (c['chattyAtRate'] as num?)?.toInt() ?? 0;
    _idleActiveRate = (c['idleActiveRate'] as num?)?.toInt() ?? 0;
    _chatCount = chatCount;
  }

  Future<void> _load() async {
    // 命中缓存：立即渲染，不阻塞界面
    if (_cachedConfig != null) {
      _applyConfig(_cachedConfig!, _cachedChatCount);
      setState(() => _loading = false);
    } else {
      setState(() => _loading = true);
    }
    try {
      final api = _api();
      if (api == null) {
        setState(() => _message = '未登录，无法读取 AI 配置');
        return;
      }
      final r = await api.aiConfig();
      final c = (r['config'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
      final chatCount = (r['chatCount'] as num?)?.toInt() ?? 0;
      _cachedConfig = c;
      _cachedChatCount = chatCount;
      setState(() => _applyConfig(c, chatCount));
      // 主动开话题（冷场检查）配置（QQBot idle_talk）
      try {
        final ir = await api.idleTalk();
        final ic = (ir['config'] as Map?)?.cast<String, dynamic>() ?? {};
        if (mounted) {
          setState(() {
            _idleInterval = (ic['interval_minutes'] as num?)?.toInt() ?? 30;
            _idleProb = ((ic['speak_probability'] as num?)?.toDouble() ?? 0.6 * 100).round();
            _idleActiveWindow = (ic['active_within_minutes'] as num?)?.toInt() ?? 90;
            _idleMaxChars = (ic['max_chars'] as num?)?.toInt() ?? 60;
          });
        }
      } catch (_) {}
    } catch (e) {
      setState(() => _message = '加载失败：$e');
    } finally {
      setState(() => _loading = false);
    }
  }

  /// 保存主动开话题（冷场检查）设置 → /ai/idle-talk（保存后 QQBot 自动重启生效）
  Future<void> _saveIdle() async {
    setState(() {
      _idleSaving = true;
      _message = '';
    });
    try {
      final api = _api();
      if (api == null) {
        setState(() => _message = '未登录，无法保存');
        return;
      }
      final r = await api.saveIdleTalk({
        'interval_minutes': _idleInterval,
        'speak_probability': _idleProb / 100.0,
        'active_within_minutes': _idleActiveWindow,
        'max_chars': _idleMaxChars,
      });
      setState(() => _message = r['ok'] == true
          ? '开话题设置已保存，QQBot 已重启生效'
          : '${r['msg'] ?? '保存失败'}');
    } catch (e) {
      setState(() => _message = '保存失败：$e');
    } finally {
      setState(() => _idleSaving = false);
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
        'age': _age.trim(),
        'gender': _gender,
        'masterUin': _masterUin.trim(),
        'temperature': _temperature,
        'maxTokens': _maxTokens,
        'selfMode': _selfMode,
        'triggerPoke': _triggerPoke,
        'triggerAt': _triggerAt,
        'triggerRandom': _triggerRandom,
        'randomRate': _randomRate,
        'keywords': _keywords.trim(),
        'skipAtOthers': _skipAtOthers,
        'learnFromChat': _learnFromChat,
        'memoryMode': _memoryMode,
        'memoryTurns': _memoryTurns,
        'multiRate': _multiRate,
        'multiMax': _multiMax,
        'chattyAtRate': _chattyAtRate,
        'idleActiveRate': _idleActiveRate,
      });
      if (r['ok'] == true && r['config'] is Map) {
        _cachedConfig = (r['config'] as Map).cast<String, dynamic>();
      }
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
                _ageGenderRow(),
                _section('回复风格'),
                _styleTile(),
                _section('主人权限'),
                _masterField(),
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
                _section('学习与防 AI 感'),
                _triggerTile(Icons.school_outlined, '学习真人聊天（越聊越像真人）', _learnFromChat,
                    (v) => setState(() => _learnFromChat = v)),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text('已学习语料：$_chatCount 条真实聊天（自动记录他人消息）',
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ),
                _triggerTile(Icons.psychology_outlined, '群聊记忆（记得刚才聊了什么）', _memoryMode,
                    (v) => setState(() => _memoryMode = v)),
                if (_memoryMode)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: '$_memoryTurns',
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '记忆轮数（1 轮 = 一问一答）',
                              isDense: true,
                            ),
                            onChanged: (v) => _memoryTurns = int.tryParse(v.trim()) ?? 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                _section('话痨连发 · 随机@ · 主动发言'),
                _numField('连发概率 %（0=关，命中后回复拆成多条单行连发）', _multiRate, 0, 100, (v) => _multiRate = v),
                _numField('连发最多条数', _multiMax, 2, 5, (v) => _multiMax = v),
                _numField('连发时随机 @ 群里其他人概率 %', _chattyAtRate, 0, 100, (v) => _chattyAtRate = v),
                _numField('主动发言概率 %（收到群消息时按概率插话，5分钟每群最多1次）', _idleActiveRate, 0, 100, (v) => _idleActiveRate = v),
                const SizedBox(height: 4),
                _section('主动开话题 · 冷场检查'),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, left: 4),
                  child: Text(
                    '群里冷场时 AI 主动开话题：每隔「检查间隔」分钟看一次，群在「活跃窗口」内有人说话才开口（避免打扰安静群），按「开口概率」抽签命中就主动发一条。',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey.shade600),
                  ),
                ),
                _numField('冷场检查间隔（分钟）', _idleInterval, 5, 720, (v) => _idleInterval = v),
                _numField('开口概率（%）', _idleProb, 0, 100, (v) => _idleProb = v),
                _numField('群活跃判定窗口（分钟）', _idleActiveWindow, 5, 1440, (v) => _idleActiveWindow = v),
                _numField('话题长度上限（字）', _idleMaxChars, 10, 200, (v) => _idleMaxChars = v),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: OutlinedButton.icon(
                    onPressed: _idleSaving ? null : _saveIdle,
                    icon: _idleSaving
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.timer_outlined, size: 18),
                    label: const Text('保存开话题设置（QQBot 自动重启生效）'),
                  ),
                ),
                const SizedBox(height: 4),
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
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _styleChip('简短真人感', '短句、口语、不客套', _replyStyle == 'human',
                      () => setState(() => _replyStyle = 'human')),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _styleChip('话痨真人感', '话多、爱展开、跑题吐槽', _replyStyle == 'chatty',
                      () => setState(() => _replyStyle = 'chatty')),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _styleChip('AI感', '完整、清晰、有条理', _replyStyle == 'ai',
                      () => setState(() => _replyStyle = 'ai')),
                ),
                const SizedBox(width: 8),
                const Expanded(child: SizedBox()),
              ],
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

  Widget _masterField() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              initialValue: _masterUin,
              decoration: const InputDecoration(
                labelText: '主人 QQ 号（逗号分隔可多个）',
                hintText: '如 123456789',
                prefixIcon: Icon(Icons.admin_panel_settings_outlined),
              ),
              onChanged: (v) => _masterUin = v,
            ),
            const Padding(
              padding: EdgeInsets.only(left: 4, top: 4),
              child: Text('主人发的消息必回；主人可发管理指令（/status /ai on /ai off /style human|ai /help）；非主人不能发指令。',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
            ),
          ],
        ),
      );

  Widget _keywordField() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: TextFormField(
          initialValue: _keywords,
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
      child: TextFormField(
        initialValue: value,
        obscureText: obscure,
        decoration: InputDecoration(labelText: label, hintText: hint),
        onChanged: onchg,
      ),
    );
  }

  Widget _numField(String label, int value, int min, int max,
      void Function(int) onchg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        initialValue: '$value',
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label, isDense: true),
        onChanged: (v) {
          final n = int.tryParse(v.trim());
          if (n != null) {
            onchg(n < min ? min : (n > max ? max : n));
          }
        },
      ),
    );
  }

  Widget _personaField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            initialValue: _persona,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: '人设描述',
              alignLabelWithHint: true,
              hintText: '例如：你是一个温柔耐心的姐姐，喜欢用 emoji，说话简短俏皮。',
            ),
            onChanged: (v) => _persona = v,
          ),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.cloud_download_outlined, size: 16),
            label: const Text('从服务器重新读取配置'),
          ),
          const Text('提示：人设内容会在每次 AI 回复时作为系统指令注入，决定 QQ 自动回复的语气与行为。',
              style: TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _ageGenderRow() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: _age,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '年龄',
                  hintText: '如 22',
                  prefixIcon: Icon(Icons.cake_outlined),
                ),
                onChanged: (v) => _age = v,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _gender.isEmpty ? '' : _gender,
                decoration: const InputDecoration(
                  labelText: '性别',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                items: const [
                  DropdownMenuItem(value: '', child: Text('未指定')),
                  DropdownMenuItem(value: '男', child: Text('男')),
                  DropdownMenuItem(value: '女', child: Text('女')),
                ],
                onChanged: (v) => setState(() => _gender = v ?? ''),
              ),
            ),
          ],
        ),
      );

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
