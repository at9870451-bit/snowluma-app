import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/qqbot_client.dart';
import '../../core/ui_anim.dart';
import 'q_ui.dart';

/// QQBot 置控台 — 群级管控（让 AI 在某个群闭嘴 / 恢复说话 / 群启用）
///
/// 数据：GET /api/console/overview · POST /api/console/group {group_id, silenced, duration, permanent, enabled}
class QqbotConsolePage extends StatefulWidget {
  const QqbotConsolePage({super.key});

  @override
  State<QqbotConsolePage> createState() => _QqbotConsolePageState();
}

class _QqbotConsolePageState extends State<QqbotConsolePage> {
  QqbotClient get _api => QqbotClient.fromSnowLuma(appState.baseUrl);

  bool _loading = true;
  String? _err;
  List<Map<String, dynamic>> _groups = const [];
  String _q = '';
  bool _showOnlySilenced = false;
  final Set<String> _busy = {};
  // 聊天范围白名单（gateway /ai/chat-scope；social_pro 插件强制执行）
  Set<String> _chatGroups = {};
  List<String> _chatFriends = [];
  final Set<String> _chatBusy = {};
  bool _chatLoaded = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadChatScope();
  }

  /// GET /ai/chat-scope（网关存 chatGroups/chatFriends，social_pro 读它做门控）
  Future<void> _loadChatScope() async {
    try {
      final api = appState.client;
      if (api == null) return;
      final r = await api.chatScope();
      if (!mounted) return;
      setState(() {
        _chatGroups = ((r['groups'] as List?) ?? const [])
            .map((e) => '$e').toSet();
        _chatFriends = ((r['friends'] as List?) ?? const [])
            .map((e) => '$e').toList();
        _chatLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _chatLoaded = true);
    }
  }

  Future<void> _toggleChat(Map<String, dynamic> g) async {
    final id = '${g['group_id']}';
    final api = appState.client;
    if (api == null) {
      qSnack(context, '未连接服务器，无法修改聊天范围');
      return;
    }
    if (_chatBusy.contains(id)) return;
    final next = Set<String>.from(_chatGroups);
    final adding = !next.contains(id);
    if (adding) {
      next.add(id);
    } else {
      next.remove(id);
    }
    setState(() => _chatBusy.add(id));
    try {
      final r =
          await api.saveChatScope(groups: next.toList(), friends: _chatFriends);
      if (!mounted) return;
      if (r['ok'] == true) {
        setState(() {
          _chatGroups = ((r['groups'] as List?) ?? const [])
              .map((e) => '$e').toSet();
        });
        qSnack(context, adding
            ? '已加入聊天白名单，AI 会在这个群说话'
            : '已移出白名单，AI 不再在这个群自动聊天');
      } else {
        qSnack(context, '${r['msg'] ?? '保存失败'}');
      }
    } catch (e) {
      if (mounted) qSnack(context, '保存失败：$e');
    } finally {
      if (mounted) setState(() => _chatBusy.remove(id));
    }
  }

  /// 这个群当前是否「可聊」：白名单为空 = 全部可聊
  bool _chatOn(String id) =>
      _chatGroups.isEmpty || _chatGroups.contains(id);

  Future<void> _load() async {
    setState(() {
      _loading = _groups.isEmpty;
      _err = null;
    });
    try {
      final groups = await _api.consoleGroups();
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_groups.isEmpty) _err = e.toString();
      });
    }
  }

  List<Map<String, dynamic>> get _visible {
    final kw = _q.trim();
    return _groups.where((g) {
      if (_showOnlySilenced && g['silenced'] != true) return false;
      if (kw.isNotEmpty) {
        final name = '${g['group_name'] ?? ''}';
        final id = '${g['group_id'] ?? ''}';
        if (!name.contains(kw) && !id.contains(kw)) return false;
      }
      return true;
    }).toList();
  }

  Future<void> _apply(Map<String, dynamic> g,
      {bool? silenced, int? duration, bool? permanent, bool? enabled}) async {
    final id = '${g['group_id']}';
    setState(() => _busy.add(id));
    try {
      final r = await _api.consoleSetGroup(id,
          silenced: silenced,
          duration: duration,
          permanent: permanent,
          enabled: enabled);
      if (!mounted) return;
      if (r['ok'] == true) {
        final state = (r['state'] as Map?)?.cast<String, dynamic>();
        if (state != null) {
          setState(() {
            _groups = _groups.map((e) {
              if ('${e['group_id']}' != id) return e;
              return {...e, ...state};
            }).toList();
          });
        } else {
          await _load();
        }
        qSnack(context, silenced == true
            ? '已让 AI 在这个群闭嘴'
            : silenced == false
                ? '已恢复 AI 在这个群说话'
                : '已更新');
      } else {
        qSnack(context, QqbotClient.errText(r));
      }
    } catch (e) {
      if (mounted) qSnack(context, '操作失败：$e');
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _silenceFlow(Map<String, dynamic> g,
      {BuildContext? anchor}) async {
    final cur = g['silenced'] == true;
    if (cur) {
      await _apply(g, silenced: false, duration: 0, permanent: false);
      return;
    }
    // 以「闭嘴」按钮为原点展开时长菜单，点外部原路收回
    final anchorCtx = anchor ?? context;
    final pick = await showAnchorMenu(
      context,
      anchor: anchorCtx,
      items: const [
        QMenuItem('10 分钟', icon: Icons.schedule_rounded),
        QMenuItem('1 小时', icon: Icons.schedule_rounded),
        QMenuItem('6 小时', icon: Icons.schedule_rounded),
        QMenuItem('1 天', icon: Icons.event_repeat_rounded),
        QMenuItem('永久闭嘴（手动恢复）', icon: Icons.block_rounded),
      ],
    );
    if (pick == null) return;
    if (pick.startsWith('永久')) {
      await _apply(g, silenced: true, permanent: true, duration: 0);
      return;
    }
    const minutesMap = {
      '10 分钟': 10,
      '1 小时': 60,
      '6 小时': 360,
      '1 天': 1440,
    };
    final minutes = minutesMap[pick] ?? 60;
    await _apply(g,
        silenced: true, duration: minutes * 60, permanent: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('置控台'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Builder(builder: (context) {
        if (_loading) return const QLoading(text: '读取群列表…');
        if (_err != null) return QError(message: _err!, onRetry: _load);
        final visible = _visible;
        final silencedCount = _groups.where((g) => g['silenced'] == true).length;
        return Column(
          children: [
            Container(
              color: const Color(0xFFF7F7FA),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                          '共 ${_groups.length} 群 · 闭嘴 $silencedCount · '
                          '${_chatGroups.isEmpty ? "全部可聊" : "白名单 ${_chatGroups.length} 群"}',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700)),
                      const Spacer(),
                      FilterChip(
                        label: const Text('只看闭嘴中',
                            style: TextStyle(fontSize: 11.5)),
                        selected: _showOnlySilenced,
                        visualDensity: VisualDensity.compact,
                        onSelected: (v) =>
                            setState(() => _showOnlySilenced = v),
                      ),
                      const SizedBox(width: 4),
                      // 「可聊」开关说明 → 气泡提示（带指向箭头，数秒自动收回）
                      Builder(
                        builder: (helpCtx) => IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: '什么是「可聊」',
                          onPressed: () => showBubble(
                            context,
                            anchor: helpCtx,
                            text: '「可聊」开关：打开 = AI 在这个群说话（加入白名单），'
                                '关闭 = 沉默。名单为空时所有群都可聊。',
                            visible: const Duration(seconds: 5),
                          ),
                          icon: Icon(Icons.help_outline_rounded,
                              size: 18, color: Colors.grey.shade500),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    onChanged: (v) => setState(() => _q = v),
                    style: const TextStyle(fontSize: 12.5),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      hintText: '搜索群名 / 群号',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(9)),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await _load();
                  await _loadChatScope();
                },
                child: visible.isEmpty
                    ? ListView(children: const [
                        SizedBox(height: 90),
                        QEmpty(text: '没有符合条件的群'),
                      ])
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 120),
                        itemCount: visible.length,
                        itemBuilder: (_, i) => _groupTile(visible[i]),
                      ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _groupTile(Map<String, dynamic> g) {
    final id = '${g['group_id']}';
    final silenced = g['silenced'] == true;
    final permanent = g['permanent'] == true;
    final enabled = g['enabled'] != false;
    final remaining = (g['remaining'] as num?) ?? 0;
    final busy = _busy.contains(id);
    return QCard(
      padding: const EdgeInsets.fromLTRB(13, 12, 8, 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (silenced ? const Color(0xFFFF9500) : kIosBlue)
                  .withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              silenced ? Icons.volume_off_rounded : Icons.groups_rounded,
              size: 19,
              color: silenced ? const Color(0xFFFF9500) : kIosBlue,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${g['group_name'] ?? ''}'.trim().isEmpty
                      ? id
                      : '${g['group_name']}'.trim(),
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    id,
                    if (!enabled) '群已禁用',
                    if (silenced)
                      permanent
                          ? '闭嘴中 · 永久'
                          : '闭嘴中 · 剩 ${fmtDuration(remaining)}',
                    if (g['source'] != null && '${g['source']}'.isNotEmpty)
                      '来源 ${g['source']}',
                  ].join(' · '),
                  style: TextStyle(
                      fontSize: 11,
                      color: silenced
                          ? const Color(0xFFFF9500)
                          : Colors.grey.shade600),
                ),
              ],
            ),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            Builder(
              builder: (btnCtx) => TextButton(
                onPressed: () => _silenceFlow(g, anchor: btnCtx),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: silenced
                      ? const Color(0xFF34C759)
                      : const Color(0xFFFF9500),
                ),
                child: Text(silenced ? '恢复' : '闭嘴',
                    style: const TextStyle(fontSize: 12.5)),
              ),
            ),
          const SizedBox(width: 2),
          // 可聊天开关（聊天白名单）
          Column(
            children: [
              Text('可聊',
                  style:
                      TextStyle(fontSize: 9.5, color: Colors.grey.shade500)),
              SizedBox(
                width: 42,
                height: 26,
                child: Transform.scale(
                  scale: 0.72,
                  child: Switch.adaptive(
                    value: _chatOn(id),
                    activeColor: kIosBlue,
                    onChanged: _chatBusy.contains(id)
                        ? null
                        : (_) => _toggleChat(g),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}