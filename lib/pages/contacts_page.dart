import 'package:flutter/material.dart';

import '../core/app_state.dart';

/// 联系人页 — 当前 QQ 账号已加入的群聊 + 好友列表。
/// 数据来自 GET /ai/contacts（后端调 OneBot get_group_list / get_friend_list）。
/// 「选择」模式：勾选群聊/好友 → 保存为 AI 聊天范围白名单（GET/POST /ai/chat-scope），
/// AI 只和被选中的群/好友聊天；不选任何 = 不限（全部可聊）。
class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  bool _loading = true;
  bool _saving = false;
  String? _err;

  List<Map<String, dynamic>> _groups = const [];
  List<Map<String, dynamic>> _friends = const [];

  // 聊天范围白名单（已选 = AI 可聊天）
  final Set<String> _selGroups = {};
  final Set<String> _selFriends = {};
  bool _editMode = false;

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
      if (api == null) {
        if (mounted) {
          setState(() {
            _loading = false;
            _err = '尚未连接服务器';
          });
        }
        return;
      }
      final contacts = await api.contacts();
      final scope = await api.chatScope();
      if (!mounted) return;
      setState(() {
        _groups = (contacts['groups'] as List? ?? const [])
            .cast<Map<String, dynamic>>();
        _friends = (contacts['friends'] as List? ?? const [])
            .cast<Map<String, dynamic>>();
        _selGroups
          ..clear()
          ..addAll((scope['groups'] as List? ?? const []).map((e) => e.toString()));
        _selFriends
          ..clear()
          ..addAll((scope['friends'] as List? ?? const []).map((e) => e.toString()));
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

  Future<void> _saveScope() async {
    setState(() => _saving = true);
    try {
      final api = appState.client;
      if (api == null) throw StateError('未连接');
      await api.saveChatScope(
        groups: _selGroups.toList(),
        friends: _selFriends.toList(),
      );
      if (!mounted) return;
      setState(() {
        _editMode = false;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_selGroups.isEmpty && _selFriends.isEmpty
            ? '已保存：不限范围，AI 可以和所有群/好友聊天'
            : '已保存：AI 只和选中的 ${_selGroups.length} 个群、${_selFriends.length} 个好友聊天')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('保存失败：$e')));
    }
  }

  void _toggleGroup(String gid) {
    setState(() {
      if (!_selGroups.remove(gid)) _selGroups.add(gid);
    });
  }

  void _toggleFriend(String uid) {
    setState(() {
      if (!_selFriends.remove(uid)) _selFriends.add(uid);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final scopeEmpty = _selGroups.isEmpty && _selFriends.isEmpty;
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的联系人'),
        actions: [
          if (!_loading)
            IconButton(
              tooltip: _editMode ? '完成' : '选择',
              onPressed: _saving
                  ? null
                  : () => setState(() => _editMode = !_editMode),
              icon: _saving
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(_editMode ? Icons.check : Icons.checklist_rounded),
            ),
          if (!_loading)
            IconButton(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(34),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              _editMode
                  ? '勾选后 AI 只和选中的群/好友聊天（不选=不限）'
                  : (scopeEmpty ? '未设限制：AI 可和所有群/好友聊天' : 'AI 聊天范围：${_selGroups.length} 群 · ${_selFriends.length} 好友'),
              style: text.bodySmall?.copyWith(
                  color: scopeEmpty ? Colors.grey : const Color(0xFF007AFF)),
            ),
          ),
        ),
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

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.only(bottom: 110),
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
        ),
        // 底部保存栏（编辑模式）
        if (_editMode)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving
                          ? null
                          : () => setState(() {
                                _selGroups.clear();
                                _selFriends.clear();
                              }),
                      child: const Text('清空选择'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _saving ? null : _saveScope,
                      child: Text(_saving
                          ? '保存中…'
                          : '保存（群 ${_selGroups.length} · 好友 ${_selFriends.length}）'),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
    final selected = _selGroups.contains(id);
    return _tile(
      context,
      text: text,
      avatar: _NetAvatar(
        url: 'https://p.qlogo.cn/gh/$id/$id/100',
        fallbackText: name,
        color: Colors.blue,
      ),
      title: name,
      subtitle: '群号 $id${members.isNotEmpty ? ' · 成员 $members' : ''}'
          '${selected ? ' · AI可聊' : ''}',
      selected: selected,
      editMode: _editMode,
      onTap: _editMode ? () => _toggleGroup(id) : null,
    );
  }

  Widget _friendTile(
      BuildContext context, TextTheme text, Map<String, dynamic> f) {
    final nick = (f['nickname'] ?? f['remark'] ?? f['name'] ?? '未知').toString();
    final id = (f['user_id'] ?? '').toString();
    final selected = _selFriends.contains(id);
    return _tile(
      context,
      text: text,
      avatar: _NetAvatar(
        url: 'https://q1.qlogo.cn/g?b=qq&nk=$id&s=100',
        fallbackText: nick,
        color: Colors.green,
      ),
      title: nick,
      subtitle: 'QQ $id${selected ? ' · AI可聊' : ''}',
      selected: selected,
      editMode: _editMode,
      onTap: _editMode ? () => _toggleFriend(id) : null,
    );
  }

  Widget _tile(
    BuildContext context, {
    required TextTheme text,
    required Widget avatar,
    required String title,
    required String subtitle,
    required bool selected,
    required bool editMode,
    required VoidCallback? onTap,
  }) {
    return ListTile(
      leading: avatar,
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle,
          style: text.bodySmall?.copyWith(
              color: selected ? const Color(0xFF007AFF) : null)),
      dense: true,
      selected: selected,
      selectedTileColor: const Color(0xFF007AFF).withValues(alpha: 0.06),
      trailing: editMode
          ? Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? const Color(0xFF007AFF) : Colors.grey.shade400,
            )
          : (selected
              ? const Icon(Icons.check_circle, size: 18, color: Color(0xFF007AFF))
              : null),
      onTap: onTap,
    );
  }
}

/// 网络头像：加载中显示字母占位，失败回退字母头像
class _NetAvatar extends StatelessWidget {
  const _NetAvatar({
    required this.url,
    required this.fallbackText,
    required this.color,
  });

  final String url;
  final String fallbackText;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: ClipOval(
        child: Image.network(
          url,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : _letter(),
          errorBuilder: (context, error, stack) => _letter(),
        ),
      ),
    );
  }

  Widget _letter() {
    final ch = fallbackText.isNotEmpty ? fallbackText[0] : '?';
    return Container(
      width: 40,
      height: 40,
      color: color.withValues(alpha: 0.15),
      alignment: Alignment.center,
      child: Text(ch,
          style: TextStyle(
              color: color, fontSize: 17, fontWeight: FontWeight.w600)),
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