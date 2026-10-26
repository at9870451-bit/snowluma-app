import 'package:flutter/material.dart';

import '../core/app_state.dart';

/// 动作调试页 — OneBot v11 动作清单 + 参数构建 + 调用
class ActionsPage extends StatefulWidget {
  const ActionsPage({super.key});

  @override
  State<ActionsPage> createState() => _ActionsPageState();
}

class _ActionsPageState extends State<ActionsPage> {
  bool _busy = false;
  List<Map<String, dynamic>> _actions = const [];
  int _uin = 0;
  String? _result;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = appState.client;
    if (api == null) return;
    setState(() => _busy = true);
    try {
      final r = await api.actions();
      _actions = (r['actions'] as List? ?? const []).cast<Map<String, dynamic>>();
    } catch (e) {
      _err = e.toString();
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _run(
      int uin, String action, Map<String, dynamic> params) async {
    final api = appState.client;
    if (api == null) return;
    setState(() => _busy = true);
    try {
      final r = await api.invoke(uin: uin, action: action, params: params);
      if (!mounted) return;
      setState(() => _result = r.toString());
    } catch (e) {
      if (!mounted) return;
      setState(() => _result = '错误：$e');
    }
  }

  Future<void> _pickAccount() async {
    final api = appState.client;
    if (api == null) return;
    final r = await api.qqList();
    final accounts =
        (r['accounts'] as List? ?? const []).cast<Map<String, dynamic>>();
    if (accounts.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('没有可用账号')));
      return;
    }
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('选择账号'),
        children: accounts.map((a) => SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, (a['account_id'] as int?) ?? 0),
          child: Text(
            '${a['nickname'] ?? ''}（${a['account_id'] ?? 0}）'),
        )).toList(),
      ),
    );
    if (picked != null && picked > 0) setState(() => _uin = picked);
  }

  void _paramsDialog(
      Map<String, dynamic> action, String label, Future<void> Function(Map<String, dynamic>) onRun) {
    final keys = (action['example'] as Map? ?? const {}).keys.toList();
    final controllers =
        {for (final k in keys) k: TextEditingController()};
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$label ${action['name']}'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final k in keys) Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: TextField(
                  controller: controllers[k],
                  decoration: InputDecoration(
                      labelText: k,
                      hintText: '${action['example']?['$k'] ?? ''}',
                      border: const OutlineInputBorder()),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              final params = controllers.map(
                (k, c) => MapEntry(k, c.text.trim()),
              );
              Navigator.pop(ctx);
              onRun(params);
            },
            child: const Text('执行'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final byCat = <String, List<Map<String, dynamic>>>{};
    for (final a in _actions) {
      byCat.putIfAbsent(
          (a['category'] as String?) ?? '其他', () => []).add(a);
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('动作调试'),
        actions: [
          IconButton(
            onPressed: _pickAccount,
            icon: const Icon(Icons.person_outline),
            tooltip: '选择账号：$_uin',
          ),
          IconButton(
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _quick(context, '获取登录信息', () => _run(_uin, 'get_login_info', {})),
                  const SizedBox(width: 8),
                  _quick(context, '发送私聊', () {
                    final c = TextEditingController();
                    showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('发送私聊消息'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                                controller: TextEditingController(text: '123456'),
                                decoration:
                                    const InputDecoration(labelText: '目标 QQ')),
                            const SizedBox(height: 8),
                            TextField(
                                controller: c,
                                decoration: const InputDecoration(labelText: '内容')),
                          ],
                        ),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('取消')),
                          FilledButton(
                            onPressed: () {
                              final t = int.tryParse(c.text.trim());
                              Navigator.pop(ctx);
                              if (t != null) _run(_uin, 'send_private_msg', {'message': [{'type': 'text', 'data': {'text': t == 0 ? '你好' : '你好'}}]});
                            },
                            child: const Text('发送'),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            if (_err != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_err!,
                    style: text.bodySmall?.copyWith(color: Colors.red)),
              ),
            Expanded(
              child: _busy
                  ? const Center(child: CircularProgressIndicator())
                  : _actions.isEmpty
                      ? const Center(child: Text('无动作数据'))
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          children: [
                            for (final cat in byCat.keys)
                              Padding(
                                padding: const EdgeInsets.only(top: 10, bottom: 6),
                                child: Text(cat,
                                    style: text.titleSmall
                                        ?.copyWith(color: Colors.indigo.shade700)),
                              ),
                            for (final a in byCat[cat]!)
                              _actionTile(context, a),
                          ],
                        ),
            ),
            if (_result != null)
              Material(
                color: Colors.grey.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.code, size: 16),
                          SizedBox(width: 6),
                          Text('调用结果', style: TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SelectableText(
                        _result!.length > 2000
                            ? _result!.substring(0, 2000) + '…'
                            : _result!,
                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _quick(BuildContext context, String label, VoidCallback onTap) =>
      OutlinedButton.icon(
        onPressed: _busy || _uin == 0 ? null : onTap,
        icon: const Icon(Icons.bolt_outlined, size: 16),
        label: Text(label),
      );

  Widget _actionTile(BuildContext context, Map<String, dynamic> a) {
    final summary = (a['summary'] as String?) ?? a['name'] as String? ?? '';
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        leading: const Icon(Icons.play_circle_outline,
            size: 20, color: Colors.indigo.shade700),
        title: Text(a['name'] as String? ?? '',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(summary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey.shade600)),
        onTap: () {
          final example =
              (a['example'] as Map?)?.cast<String, dynamic>() ?? {};
          _paramsDialog(
            a,
            summary,
            (params) async {
              final filled = <String, dynamic>{};
              for (final e in example.entries) {
                final v = params[e.key];
                filled[e.key] =
                    (v != null && v.isNotEmpty) ? _num(v) : _num(e.value);
              }
              await _run(_uin, a['name'] as String, filled);
            },
          );
        },
      ),
    );
  }

  dynamic _num(Object? v) {
    final n = int.tryParse('$v');
    return n ?? v;
  }
}
