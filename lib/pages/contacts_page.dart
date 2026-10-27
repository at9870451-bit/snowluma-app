import 'package:flutter/material.dart';

import '../core/app_state.dart';

/// 联系人页 — 当前 QQ 账号已加入的群聊 + 好友列表。
/// 数据来自 GET /ai/contacts（后端调 OneBot get_group_list / get_friend_list）。
class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  bool _loading = true;
  String? _err;
  List<Map<String, dynamic>> _groups = const [];
  List<Map<String, dynamic>> _friends = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final api = appState.client;
      final r = await api.contacts();
      if (!mounted) return;
      setState(() {
        _groups = (r['groups'] as List? ?? const [])
            .cast<Map<String, dynamic>>();
        _friends = (r['friends'] as List? ?? const [])
            .cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _err = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的联系人'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(context, text),
    );
  }

  Widget _buildBody(BuildContext context, TextTheme text) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_err != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 40, color: Colors.grey),
              const SizedBox(height: 12),
              Text('加载失败', style: text.titleMedium),
              const SizedBox(height: 8),
              Text(_err!, style: text.bodySmall, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('重试')),
            ],
          ),
        ),
      );
    }

    return ListView(
      children: [
        // 统计卡
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: _statCard(context, Icons.groups_outlined,
                    '群聊', _groups.length, Colors.blue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(context, Icons.people_alt_outlined,
                    '好友', _friends.length, Colors.green),
              ),
            ],
          ),
        ),
        // 群聊
        _sectionHeader(context, text, '群聊（${_groups.length}）'),
        if (_groups.isEmpty)
          const _emptyHint('暂无群聊')
        else
          ..._groups.map((g) => _groupTile(context, text, g)),
        // 好友
        _sectionHeader(context, text, '好友（${_friends.length}）'),
        if (_friends.isEmpty)
          const _emptyHint('暂无好友')
        else
          ..._friends.map((f) => _friendTile(context, text, f)),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _statCard(BuildContext context, IconData icon, String label,
      int count, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$count',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(
      BuildContext context, TextTheme text, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Text(title,
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
    );
  }

  Widget _groupTile(
      BuildContext context, TextTheme text, Map<String, dynamic> g) {
    final name = (g['group_name'] ?? g['name'] ?? '未知群').toString();
    final id = (g['group_id'] ?? '').toString();
    final members = (g['member_count'] ?? g['max_member_count'] ?? '')
        .toString();
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.blue.withValues(alpha: 0.15),
        child: Icon(Icons.groups, color: Colors.blue.shade600, size: 20),
      ),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('群号 $id${members.isNotEmpty ? ' · 成员 $members' : ''}',
          style: text.bodySmall),
      dense: true,
    );
  }

  Widget _friendTile(
      BuildContext context, TextTheme text, Map<String, dynamic> f) {
    final nick = (f['nickname'] ?? f['remark'] ?? f['name'] ?? '未知').toString();
    final id = (f['user_id'] ?? '').toString();
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.green.withValues(alpha: 0.15),
        child: Text(nick.isNotEmpty ? nick[0] : '?',
            style: TextStyle(color: Colors.green.shade600)),
      ),
      title: Text(nick, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('QQ $id', style: text.bodySmall),
      dense: true,
    );
  }
}

class _emptyHint extends StatelessWidget {
  const _emptyHint(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Colors.grey)),
    );
  }
}
