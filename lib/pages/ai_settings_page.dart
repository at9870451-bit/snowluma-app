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

  // ---- 语音接口 ----
  bool _voiceEnabled = false;
  String _voiceBaseUrl = '';
  String _voiceApiKey = '';
  String _voiceModel = '';
  String _voiceResponseFormat = 'url';

  // ---- 照片（视觉）接口 ----
  bool _visionEnabled = false;
  String _visionBaseUrl = '';
  String _visionApiKey = '';
  String _visionModel = '';
  String _visionResponseFormat = 'url';

  bool _fetchingModels = false;
  List<String> _models = const [];

  // ---- 角色语音（role_tts）：音色/语速/音调/概率 ----
  bool _rtEnabled = true;
  String _rtVoice = 'zh-CN-XiaoyiNeural';
  double _rtSpeed = 1.0;
  double _rtPitch = 0;
  double _rtVolume = 0;
  double _rtRate = 0.3;
  String _rtMode = 'voice';
  bool _rtHumanize = true;
  List<Map<String, dynamic>> _rtVoices = const [];
  bool _rtSaving = false;

  // ---- 接口方案 ----
  List<Map<String, dynamic>> _profiles = const [];
  String _activeProfile = '';

  // ---- 本地模型 / 外部接口 互斥开关 ----
  bool _useLocal = false;
  static const _localBase = 'http://127.0.0.1:11434/v1';
  static const _localModel = 'qwen2.5:0.5b';

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
    _voiceEnabled = c['voiceEnabled'] == true;
    _voiceBaseUrl = (c['voiceBaseUrl'] as String?) ?? '';
    _voiceApiKey = (c['voiceApiKey'] as String?) ?? '';
    _voiceModel = (c['voiceModel'] as String?) ?? '';
    _voiceResponseFormat = (c['voiceResponseFormat'] as String?) ?? 'url';
    _visionEnabled = c['visionEnabled'] == true;
    _visionBaseUrl = (c['visionBaseUrl'] as String?) ?? '';
    _visionApiKey = (c['visionApiKey'] as String?) ?? '';
    _visionModel = (c['visionModel'] as String?) ?? '';
    _visionResponseFormat = (c['visionResponseFormat'] as String?) ?? 'url';
    _chatCount = chatCount;
    _useLocal = _baseUrl.contains('127.0.0.1:11434');
    _profiles = ((c['profiles'] as List?) ?? const [])
        .whereType<Map>()
        .map((m) => m.cast<String, dynamic>())
        .toList();
    _activeProfile = (c['activeProfile'] as String?) ?? '';
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
      // 角色语音（音色）配置
      try {
        final vr = await api.voiceConfig();
        final vc = (vr['config'] as Map?)?.cast<String, dynamic>() ?? {};
        final vs = ((vr['voices'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => m.cast<String, dynamic>())
            .toList();
        if (mounted) {
          setState(() {
            _rtEnabled = vc['enabled'] != false;
            _rtVoice = (vc['voice'] as String?) ?? _rtVoice;
            _rtSpeed = (vc['speed'] as num?)?.toDouble() ?? 1.0;
            _rtPitch = (vc['pitch'] as num?)?.toDouble() ?? 0;
            _rtVolume = (vc['volume'] as num?)?.toDouble() ?? 0;
            _rtRate = (vc['reply_rate'] as num?)?.toDouble() ?? 0.3;
            _rtMode = (vc['send_mode'] as String?) ?? 'voice';
            _rtHumanize = vc['humanize_enabled'] != false;
            _rtVoices = vs;
          });
        }
      } catch (_) {}
    } catch (e) {
      setState(() => _message = '加载失败：$e');
    } finally {
      setState(() => _loading = false);
    }
  }

  /// 保存角色语音（音色/语速/音调/概率）→ /ai/voice-config（QQBot 自动重启生效）
  Future<void> _saveVoice() async {
    setState(() {
      _rtSaving = true;
      _message = '';
    });
    try {
      final api = _api();
      if (api == null) {
        setState(() => _message = '未登录，无法保存');
        return;
      }
      final r = await api.saveVoiceConfig({
        'enabled': _rtEnabled,
        'voice': _rtVoice,
        'speed': _rtSpeed,
        'pitch': _rtPitch,
        'volume': _rtVolume,
        'reply_rate': _rtRate,
        'send_mode': _rtMode,
        'humanize_enabled': _rtHumanize,
      });
      setState(() => _message = r['ok'] == true
          ? '音色已保存，QQBot 已重启生效'
          : '${r['msg'] ?? '保存失败'}');
    } catch (e) {
      setState(() => _message = '保存失败：$e');
    } finally {
      setState(() => _rtSaving = false);
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
      if (_useLocal) {
        _baseUrl = _localBase;
        _apiKey = 'ollama';
        _model = _localModel; // 本地模型固定 qwen2.5:0.5b（ollama 只有这一个）
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
        'voiceEnabled': _voiceEnabled,
        'voiceBaseUrl': _voiceBaseUrl.trim(),
        'voiceApiKey': _voiceApiKey.trim(),
        'voiceModel': _voiceModel.trim(),
        'voiceResponseFormat': _voiceResponseFormat,
        'visionEnabled': _visionEnabled,
        'visionBaseUrl': _visionBaseUrl.trim(),
        'visionApiKey': _visionApiKey.trim(),
        'visionModel': _visionModel.trim(),
        'visionResponseFormat': _visionResponseFormat,
        'profiles': _profiles,
        'activeProfile': _activeProfile,
      });
      if (r['ok'] == true && r['config'] is Map) {
        _cachedConfig = (r['config'] as Map).cast<String, dynamic>();
      }
      final ok = r['ok'] == true;
      final msg = ok
          ? '已保存，AI 助手${_enabled ? '已启用' : '已关闭'}'
          : (r['msg'] ?? '保存失败');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
      setState(() => _message = msg);
    } catch (e) {
      setState(() => _message = '保存失败：$e');
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('AI 助手设置'),
          actions: [
            IconButton(
              tooltip: '保存设置',
              onPressed: (_saving || _loading) ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(40),
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: const Color(0xFF007AFF),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFF007AFF),
              indicatorSize: TabBarIndicatorSize.label,
              tabs: const [
                Tab(text: '模型'),
                Tab(text: '人设'),
                Tab(text: '触发'),
                Tab(text: '语音·照片'),
              ],
            ),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _baseTab(),
                  _personaTab(),
                  _triggerTab(),
                  _mediaTab(),
                ],
              ),
      ),
    );
  }

  Widget _messageBar() {
    if (_message.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(_message,
          style: TextStyle(
              color: _message.contains('失败') ? Colors.red : Colors.green,
              fontSize: 12)),
    );
  }

  Widget _saveButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: FilledButton(
        onPressed: _saving ? null : _save,
        child: _saving
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('保存设置'),
      ),
    );
  }

  // ---------- Tab 1：模型 ----------
  Widget _baseTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _messageBar(),
        _section('模型来源（二选一，互斥）'),
        SwitchListTile(
          value: _useLocal,
          onChanged: (v) => setState(() {
            _useLocal = v;
            if (v && (_model.trim().isEmpty || _model.trim() == 'deepseek-chat')) {
              _model = _localModel;
            }
          }),
          title: const Text('服务器本地模型'),
          subtitle: const Text('ollama · qwen2.5:0.5b · 免额度 · 1~2秒（质量一般，兜底用）'),
          contentPadding: EdgeInsets.zero,
        ),
        SwitchListTile(
          value: !_useLocal,
          onChanged: (v) => setState(() {
            if (!v) return;
            // 切外部：恢复最近保存的外部方案（任意名称，排除本地方案）
            final extList = _profiles
                .where((p) =>
                    !(p['baseUrl'] ?? '').toString().contains('127.0.0.1:11434'))
                .toList();
            Map<String, dynamic> ext = const {};
            for (final p in extList) {
              if (p['name'] == _activeProfile) {
                ext = p;
                break;
              }
            }
            if (ext.isEmpty && extList.isNotEmpty) ext = extList.last;
            _useLocal = false;
            if (ext.isNotEmpty) {
              _baseUrl = (ext['baseUrl'] ?? '').toString();
              _apiKey = (ext['apiKey'] ?? '').toString();
              final m = (ext['model'] ?? '').toString();
              if (m.isNotEmpty) _model = m;
            }
          }),
          title: const Text('外部接口'),
          subtitle: const Text('在线 API（更聪明，需额度）· 凭据自动存入接口方案'),
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 4),
        _section('开关'),
        SwitchListTile(
          value: _enabled,
          onChanged: (v) => setState(() => _enabled = v),
          title: const Text('启用 AI 自动回复'),
          subtitle: const Text('QQ 收到消息后由 AI 按人设自动回复'),
        ),
        _section('模型接口（OpenAI 兼容）'),
        _field('API 地址', _baseUrl, (v) => _baseUrl = v),
        Row(
          children: [
            Expanded(
              child: _field('模型名', _model, (v) => _model = v,
                  hint: 'deepseek-chat / gpt-4o-mini …'),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: OutlinedButton.icon(
                onPressed: _fetchingModels ? null : _pickModel,
                icon: _fetchingModels
                    ? const SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.list_rounded, size: 16),
                label: const Text('读取'),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Text(
            '点「读取」从接口在线拉取全部可用模型（GET /v1/models），下拉选一个',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey.shade600),
          ),
        ),
        _field('API Key', _apiKey, (v) => _apiKey = v, obscure: true, hint: 'sk-…'),
        _section('参数'),
        _slider('回复随机度', _temperature, 0.0, 1.5, (v) => _temperature = v),
        _slider('最大长度', _maxTokens.toDouble(), 100, 2000, (v) => _maxTokens = v.toInt()),
        _saveButton(),
        const SizedBox(height: 24),
      ],
    );
  }

  // ---------- 在线拉取模型列表并选择 ----------
  Future<void> _pickModel() async {
    final base = _baseUrl.trim();
    if (base.isEmpty || !base.startsWith('http')) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先填写 API 地址')));
      return;
    }
    setState(() => _fetchingModels = true);
    try {
      final r = await _api()?.listModels(base, _apiKey.trim());
      final models = (r?['models'] as List? ?? const [])
          .map((e) => e.toString())
          .toList();
      if (!mounted) return;
      if (models.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(r?['msg'] ?? '接口未返回模型列表（可手动填模型名）')));
        return;
      }
      setState(() => _models = models);
      await showModalBottomSheet<void>(
        context: context,
        builder: (ctx) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text('选择模型（${models.length} 个）',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              ...models.map((m) => ListTile(
                    dense: true,
                    title: Text(m, style: const TextStyle(fontSize: 13)),
                    trailing: m == _model
                        ? const Icon(Icons.check,
                            color: Color(0xFF007AFF), size: 18)
                        : null,
                    onTap: () {
                      setState(() => _model = m);
                      Navigator.pop(ctx);
                    },
                  )),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('读取失败：$e')));
      }
    } finally {
      setState(() => _fetchingModels = false);
    }
  }

  // ---------- Tab 2：人设 ----------
  Widget _personaTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _messageBar(),
        _section('人设（Persona）'),
        _personaField(),
        _ageGenderRow(),
        _section('回复风格'),
        _styleTile(),
        _section('主人权限'),
        _masterField(),
        _saveButton(),
        const SizedBox(height: 24),
      ],
    );
  }

  // ---------- Tab 3：触发 ----------
  Widget _triggerTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _messageBar(),
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
        _saveButton(),
        const SizedBox(height: 24),
      ],
    );
  }

  // ---------- Tab 4：语音·照片 ----------
  Widget _mediaTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _messageBar(),
        _section('角色语音 · 音色（人设自动匹配，可手动覆盖）'),
        SwitchListTile(
          value: _rtEnabled,
          onChanged: (v) => setState(() => _rtEnabled = v),
          title: const Text('启用角色语音'),
          subtitle: const Text('按角色卡音色 + 情绪语气合成（edge-tts，免费）'),
          contentPadding: EdgeInsets.zero,
        ),
        if (_rtEnabled) ...[
          if (_rtVoices.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: DropdownButtonFormField<String>(
                initialValue: _rtVoices.any((v) => v['id'] == _rtVoice)
                    ? _rtVoice
                    : _rtVoices.first['id'] as String,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: '音色', isDense: true),
                items: _rtVoices
                    .map((v) => DropdownMenuItem(
                          value: v['id'] as String,
                          child: Text('${v['name']}',
                              style: const TextStyle(fontSize: 13)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _rtVoice = v ?? _rtVoice),
              ),
            ),
          _slider('语速（1.0=正常）', _rtSpeed, 0.7, 1.4,
              (v) => setState(() => _rtSpeed = v)),
          _slider('音调（半音，正=高）', _rtPitch, -4, 4,
              (v) => setState(() => _rtPitch = v)),
          _slider('音量（dB）', _rtVolume, -6, 6,
              (v) => setState(() => _rtVolume = v)),
          _slider('语音概率 %', _rtRate * 100, 0, 100,
              (v) => setState(() => _rtRate = v / 100)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Text('发送模式：', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _rtMode,
                    isDense: true,
                    items: const [
                      DropdownMenuItem(value: 'voice', child: Text('只发语音')),
                      DropdownMenuItem(value: 'both', child: Text('文字 + 语音')),
                      DropdownMenuItem(value: 'text', child: Text('只发文字')),
                    ],
                    onChanged: (v) => setState(() => _rtMode = v ?? 'voice'),
                  ),
                ),
              ],
            ),
          ),
          SwitchListTile(
            value: _rtHumanize,
            onChanged: (v) => setState(() => _rtHumanize = v),
            title: const Text('文本润色（更像活人）'),
            subtitle: const Text('自动加语气词、停顿、句尾助词'),
            contentPadding: EdgeInsets.zero,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: OutlinedButton.icon(
              onPressed: _rtSaving ? null : _saveVoice,
              icon: _rtSaving
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.record_voice_over_outlined, size: 18),
              label: const Text('保存音色设置（QQBot 自动重启生效）'),
            ),
          ),
        ],
        const SizedBox(height: 4),
        _section('语音接口（TTS / 语音输出）'),
        SwitchListTile(
          value: _voiceEnabled,
          onChanged: (v) => setState(() => _voiceEnabled = v),
          title: const Text('启用语音能力'),
          subtitle: const Text('AI 可将回复转语音 / 处理语音消息'),
          contentPadding: EdgeInsets.zero,
        ),
        if (_voiceEnabled) ...[
          _field('语音 API 地址（留空=复用模型接口）', _voiceBaseUrl, (v) => _voiceBaseUrl = v),
          Row(
            children: [
              Expanded(
                child: _field('语音模型', _voiceModel, (v) => _voiceModel = v,
                    hint: 'tts-1 / fish-speech / cosyvoice …'),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: OutlinedButton.icon(
                  onPressed: _fetchingModels ? null : () => _pickModelFor('voice'),
                  icon: const Icon(Icons.list_rounded, size: 16),
                  label: const Text('读取'),
                ),
              ),
            ],
          ),
          _field('语音 API Key（留空=复用）', _voiceApiKey, (v) => _voiceApiKey = v,
              obscure: true),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                const Text('响应格式：', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _voiceResponseFormat,
                    isDense: true,
                    items: const [
                      DropdownMenuItem(value: 'url', child: Text('url（返回音频链接）')),
                      DropdownMenuItem(value: 'base64', child: Text('base64（返回音频数据）')),
                    ],
                    onChanged: (v) => setState(() => _voiceResponseFormat = v ?? 'url'),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        _section('照片接口（视觉理解）'),
        SwitchListTile(
          value: _visionEnabled,
          onChanged: (v) => setState(() => _visionEnabled = v),
          title: const Text('启用照片理解'),
          subtitle: const Text('AI 可看懂别人发的图片/表情包'),
          contentPadding: EdgeInsets.zero,
        ),
        if (_visionEnabled) ...[
          _field('视觉 API 地址（留空=复用模型接口）', _visionBaseUrl, (v) => _visionBaseUrl = v),
          Row(
            children: [
              Expanded(
                child: _field('视觉模型', _visionModel, (v) => _visionModel = v,
                    hint: 'gpt-4o / glm-4v / qwen-vl …'),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: OutlinedButton.icon(
                  onPressed: _fetchingModels ? null : () => _pickModelFor('vision'),
                  icon: const Icon(Icons.list_rounded, size: 16),
                  label: const Text('读取'),
                ),
              ),
            ],
          ),
          _field('视觉 API Key（留空=复用）', _visionApiKey, (v) => _visionApiKey = v,
              obscure: true),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                const Text('响应格式：', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _visionResponseFormat,
                    isDense: true,
                    items: const [
                      DropdownMenuItem(value: 'url', child: Text('url（图片以链接传入）')),
                      DropdownMenuItem(value: 'base64', child: Text('base64（图片以数据传入）')),
                    ],
                    onChanged: (v) => setState(() => _visionResponseFormat = v ?? 'url'),
                  ),
                ),
              ],
            ),
          ),
        ],
        _saveButton(),
        const SizedBox(height: 24),
      ],
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

  /// 按来源读取模型列表（voice/vision 地址留空时复用主接口）
  Future<void> _pickModelFor(String kind) async {
    final base = (kind == 'voice' ? _voiceBaseUrl : _visionBaseUrl).trim();
    final key = (kind == 'voice' ? _voiceApiKey : _visionApiKey).trim();
    final useBase = base.isNotEmpty ? base : _baseUrl.trim();
    final useKey = key.isNotEmpty ? key : _apiKey.trim();
    if (!useBase.startsWith('http')) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请先填写 API 地址')));
      return;
    }
    setState(() => _fetchingModels = true);
    try {
      final r = await _api()?.listModels(useBase, useKey);
      final models =
          (r?['models'] as List? ?? const []).map((e) => e.toString()).toList();
      if (!mounted) return;
      if (models.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(r?['msg'] ?? '接口未返回模型列表（可手动填模型名）')));
        return;
      }
      await showModalBottomSheet<void>(
        context: context,
        builder: (ctx) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                    '选择${kind == 'voice' ? '语音' : '视觉'}模型（${models.length} 个）',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              ...models.map((m) => ListTile(
                    dense: true,
                    title: Text(m, style: const TextStyle(fontSize: 13)),
                    onTap: () {
                      setState(() {
                        if (kind == 'voice') {
                          _voiceModel = m;
                          _voiceBaseUrl = useBase;
                          if (key.isEmpty) _voiceApiKey = useKey;
                        } else {
                          _visionModel = m;
                          _visionBaseUrl = useBase;
                          if (key.isEmpty) _visionApiKey = useKey;
                        }
                      });
                      Navigator.pop(ctx);
                    },
                  )),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('读取失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _fetchingModels = false);
    }
  }
}
