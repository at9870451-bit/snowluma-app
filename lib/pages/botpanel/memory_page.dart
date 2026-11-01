import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/qqbot_client.dart';
import '../../core/ui_anim.dart';
import 'q_ui.dart';

/// QQBot 记忆库 — 查看/新增/删除 AI 记住的内容
///
/// 数据：GET /api/memory（全量）· POST /api/memory · DELETE /api/memory/<id>
/// 说明：服务端 scope/group_id 过滤不完全可靠，统一拉全量后客户端筛选。
class QqbotMemoryPage extends StatefulWidget {
  const QqbotMemoryPage({super.key});

  @override
  State<QqbotMemoryPage> createState() => _QqbotMemoryPageState();
}

class _QqbotMemoryPageState extends State<QqbotMemoryPage> {
  QqbotClient get _api => QqbotClient.fromSnowLuma(appState.baseUrl);

  bool _loading = true;
  String? _err;
  List<Map<String, dynamic>> _all = const [];
  Map<String, dynamic> _stats = const {};
  String _scope = 'all'; // all | global | group | user
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _all.isEmpty;
      _err = null;
    });
    try {
      final results = await Future.wait([
        _api.memories(),
        _api.memoryOverview().catchError((_) => <String, dynamic>{}),
      ]);
      if (!mounted) return;
      setState(() {
        _all = results[0] as List<Map<String, dynamic>>;
        _stats =
            ((results[1] as Map)['stats'] as Map?)?.cast<String, dynamic>() ??
                const {};
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_all.isEmpty) _err = e.toString();
      });
    }
  }

  List<Map<String, dynamic>> get _visible {
    final kw = _q.trim();
    return _all.where((m) {
      final scope = '${m['scope'] ?? ''}';
      if (_scope != 'all' && scope != _scope) return false;
      if (kw.isNotEmpty && !'${m['content'] ?? ''}'.contains(kw)) return false;
      return true;
    }).toList()
      ..sort((a, b) => ((b['updated_at'] as num?) ?? 0)
          .compareTo((a['updated_at'] as num?) ?? 0));
  }

  String _scopeLabel(Map<String, dynamic> m) {
    final s = '${m['scope'] ?? ''}';
    switch (s) {
      case 'global':
        return '全局';
      case 'group':
        return '本群';
      case 'user':
        return '对我';
      default:
        return '${m['scope_label'] ?? s}';
    }
  }

  Color _scopeColor(String s) {
    switch (s) {
      case 'global':
        return const Color(0xFF5856D6);
      case 'group':
        return const Color(0xFF34C759);
      case 'user':
        return const Color(0xFFFF9500);
      default:
        return Colors.grey;
    }
  }

  Future<void> _add() async {
    final c = TextEditingController();
    var scope = 'global';
    final gidC = TextEditingController();
    final uidC = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('新增记忆',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('AI 会在之后的对话里记住并遵守这个设定',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(height: 12),
              TextField(
                controller: c,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                    labelText: '记住什么（越具体越好）',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  for (final e in const [
                    ['global', '全局'],
                    ['group', '本群'],
                    ['user', '对某人'],
                  ])
                    ChoiceChip(
                      label: Text(e[1]),
                      selected: scope == e[0],
                      onSelected: (_) => setSheet(() => scope = e[0]),
                    ),
                ],
              ),
              if (scope != 'global') ...[
                const SizedBox(height: 10),
                TextField(
                  controller: scope == 'group' ? gidC : uidC,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: scope == 'group' ? '群号' : 'QQ 号',
                      border: const OutlineInputBorder()),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('保存记忆'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    final content = c.text.trim();
    if (content.isEmpty) {
      qSnack(context, '内容不能为空');
      return;
    }
    final gid = scope == 'group' ? int.tryParse(gidC.text.trim()) : null;
    final uid = scope == 'user' ? int.tryParse(uidC.text.trim()) : null;
    if (scope == 'group' && gid == null) {
      qSnack(context, '请填群号');
      return;
    }
    if (scope == 'user' && uid == null) {
      qSnack(context, '请填 QQ 号');
      return;
    }
    try {
      final r = await _api.memoryAdd(
        content: content,
        scope: scope,
        groupId: gid ?? 0,
        userId: uid ?? 0,
      );
      if (!mounted) return;
      if (r['ok'] == true) {
        qSnack(context, '已记住');
        await _load();
      } else {
        qSnack(context, QqbotClient.errText(r));
      }
    } catch (e) {
      if (mounted) qSnack(context, '保存失败：$e');
    }
  }

  Future<void> _delete(Map<String, dynamic> m) async {
    final ok = await showQConfirm(
      context,
      title: '删除这条记忆？',
      content: '${m['content'] ?? ''}',
      confirmText: '删除',
      danger: true,
    );
    if (ok != true) return;
    try {
      final r = await _api.memoryDelete((m['id'] as num).toInt());
      if (!mounted) return;
      if (r['ok'] == true) {
        setState(() => _all = _all.where((e) => e['id'] != m['id']).toList());
        qSnack(context, '已删除');
      } else {
        qSnack(context, QqbotClient.errText(r));
      }
    } catch (e) {
      if (mounted) qSnack(context, '删除失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('记忆库'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: '新增记忆',
            onPressed: _loading ? null : _add,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Builder(builder: (context) {
        if (_loading) return const QLoading(text: '读取记忆…');
        if (_err != null) return QError(message: _err!, onRetry: _load);
        final visible = _visible;
        return Column(
          children: [
            _header(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: visible.isEmpty
                    ? ListView(children: const [
                        SizedBox(height: 90),
                        QEmpty(
                            icon: Icons.psychology_outlined,
                            text: '没有符合条件的记忆'),
                      ])
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 120),
                        itemCount: visible.length,
                        itemBuilder: (_, i) => _tile(visible[i]),
                      ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _header() {
    final total = (_stats['total'] as num?) ?? _all.length;
    final enabled = (_stats['enabled'] as num?) ??
        _all.where((e) => e['enabled'] != false).length;
    final byScope =
        (_stats['by_scope'] as Map?)?.cast<String, dynamic>() ?? {};
    final chips = [
      ['all', '全部'],
      ['global', '全局 ${byScope['global'] ?? ''}'.trim()],
      ['group', '本群 ${byScope['group'] ?? ''}'.trim()],
      ['user', '对我 ${byScope['user'] ?? ''}'.trim()],
    ];
    return Container(
      color: const Color(0xFFF7F7FA),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        children: [
          Row(
            children: [
              Text('共 $total 条 · 启用 $enabled',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700)),
              const Spacer(),
              SizedBox(
                width: 130,
                height: 30,
                child: TextField(
                  onChanged: (v) => setState(() => _q = v),
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    hintText: '搜索内容',
                    prefixIcon: const Icon(Icons.search, size: 15),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final c in chips)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(c[1], style: const TextStyle(fontSize: 11.5)),
                      selected: _scope == c[0],
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => setState(() => _scope = c[0]),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(Map<String, dynamic> m) {
    final scope = '${m['scope'] ?? ''}';
    final enabled = m['enabled'] != false;
    return QCard(
      padding: const EdgeInsets.fromLTRB(13, 11, 10, 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _scopeColor(scope).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(_scopeLabel(m),
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _scopeColor(scope))),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${m['content'] ?? ''}',
                    style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color:
                            enabled ? Colors.black87 : Colors.grey.shade500)),
                const SizedBox(height: 5),
                Text(
                  '${m['source'] ?? ''} · ${fmtTime((m['updated_at'] as num?) ?? 0)}${enabled ? '' : ' · 已停用'}',
                  style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '删除',
            visualDensity: VisualDensity.compact,
            onPressed: () => _delete(m),
            icon: Icon(Icons.delete_outline,
                size: 18, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}