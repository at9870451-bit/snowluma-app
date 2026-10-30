import 'package:flutter/material.dart';

import '../core/app_state.dart';
import 'qqbot_panel_page.dart';
import '../core/bridge.dart';
import 'actions_page.dart';
import 'login_page.dart';
import 'processes_page.dart';
import 'vnc_page.dart';
import 'ai_settings_page.dart';
import 'contacts_page.dart';
import 'logs_page.dart';
import 'stickers_page.dart';

/// 主页 — 服务状态 + QQ 账号列表 + 动作/日志入口
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _busy = false;
  Map<String, dynamic>? _status;
  List<Map<String, dynamic>> _accounts = const [];
  String? _err;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final api = appState.client;
      if (api == null) return;
      _status = await api.status();
      final r = await api.qqList();
      _accounts = (r['accounts'] as List? ?? const []).cast<Map<String, dynamic>>();
    } catch (e) {
      _err = e.toString();
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _send(int uin, int target, String text) async {
    final api = appState.client;
    if (api == null) return;
    try {
      final r = await api.sendPrivateMsg(uin: uin, target: target, text: text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发送结果: ${r.toString().length > 80 ? r.toString().substring(0, 80) : r}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('发送失败: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('SnowLuma'),
        actions: [
          IconButton(
            onPressed: _busy ? null : _refresh,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              switch (v) {
                case 'processes':
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProcessesPage()),
                  );
                case 'actions':
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ActionsPage()),
                  );
                case 'logs':
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LogsPage()),
                  );
                case 'logout':
                  await appState.disconnect();
                  if (mounted) Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => LoginPage(onConnected: () {})),
                    (_) => false,
                  );
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'processes', child: ListTile(
                  leading: Icon(Icons.dns_outlined),
                  title: Text('接入 QQ'), dense: true, contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(value: 'actions', child: ListTile(
                  leading: Icon(Icons.play_circle_outline),
                  title: Text('动作调试'), dense: true, contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(value: 'logs', child: ListTile(
                  leading: Icon(Icons.article_outlined),
                  title: Text('系统信息'), dense: true, contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(value: 'logout', child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('退出登录', style: TextStyle(color: Colors.red)),
                  dense: true, contentPadding: EdgeInsets.zero)),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _statusCard(context, text),
            // 联系人入口：当前 QQ 账号已加入的群聊 + 好友
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.people_alt_outlined,
                      color: Colors.blue),
                  title: const Text('我的群聊和好友'),
                  subtitle: const Text('查看当前 QQ 账号已添加的群聊与好友'),
                  trailing: const Icon(Icons.chevron_right),
                  dense: true,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ContactsPage()),
                  ),
                ),
              ),
            ),
            // AI 收藏的表情包入口
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.emoji_emotions_outlined,
                      color: Colors.orange),
                  title: const Text('AI 收藏的表情包'),
                  subtitle: const Text('看到就收 · 回复时只发自己收藏的'),
                  trailing: const Icon(Icons.chevron_right),
                  dense: true,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const StickersPage()),
                  ),
                ),
              ),
            ),
            // QQBot 管理面板入口（机器人本体：插件/群管理/日志）
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.smart_toy_outlined,
                      color: Color(0xFF007AFF)),
                  title: const Text('QQBot 管理面板'),
                  subtitle: const Text('插件 / 群管理 / 日志 · 机器人本体'),
                  trailing: const Icon(Icons.chevron_right),
                  dense: true,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const QqbotPanelPage()),
                  ),
                ),
              ),
            ),
            if (_err != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 18, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_err!, style: text.bodySmall)),
                  ],
                ),
              ),
            Expanded(child: _accountsList(context, text)),
          ],
        ),
      ),
    );
  }


  Widget _statusCard(BuildContext context, TextTheme text) {
    final s = _status;
    final running = s?['status'] == 'running';
    final ver = SnowLumaBridge.call('core.version');
    return Card(
      margin: const EdgeInsets.all(12),
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade300)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: running ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(running ? '服务运行中' : '服务未就绪',
                    style: text.titleSmall),
                const Spacer(),
                Text(appState.serverLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(color: Colors.grey.shade600)),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                _kv(text, '账号数', '${_accounts.length}'),
                _kv(text, 'Rust Core', 'v${ver['version']}'),
                _kv(text, '平台', ver['platform'] as String? ?? '-'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(TextTheme text, String k, String v) => Row(
        children: [
          Text(k + '：',
              style: text.bodySmall?.copyWith(color: Colors.grey.shade600)),
          Text(v, style: text.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
        ],
      );

  Widget _accountsList(BuildContext context, TextTheme text) {
    if (_accounts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.perm_contact_calendar_outlined,
                size: 40, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text('暂无 QQ 账号', style: text.titleMedium),
            const SizedBox(height: 4),
            Text('在服务器运行 QQ 或使用 SnowLuma Docker 部署后接入',
                style: text.bodySmall?.copyWith(color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const VncPage()),
                );
              },
              icon: const Icon(Icons.qr_code_scanner, size: 18),
              label: const Text('扫码登录 QQ'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProcessesPage()),
                );
              },
              icon: const Icon(Icons.dns_outlined, size: 18),
              label: const Text('进程 / 账号管理'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AiSettingsPage()),
                );
              },
              icon: const Icon(Icons.smart_toy_outlined, size: 18),
              label: const Text('AI 助手设置'),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: _accounts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final a = _accounts[i];
        final uin = (a['account_id'] as int?) ?? 0;
        final name = (a['nickname'] as String?) ?? '';
        final raw = a['raw'] as Map?;
        final online = a['online'] == true ||
            (raw?['online']?.toString().contains('on') ?? false);
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.grey.shade200)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14),
            leading: Stack(
              children: [
                ClipOval(
                  child: SizedBox(
                    width: 46,
                    height: 46,
                    child: Image.network(
                      // 优先服务器透传的头像，缺省用腾讯官方 QQ 头像
                      ((a['avatar'] as String?)?.isNotEmpty ?? false)
                          ? a['avatar'] as String
                          : 'https://q1.qlogo.cn/g?b=qq&nk=$uin&s=100',
                      width: 46,
                      height: 46,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: online ? Colors.green.shade50 : Colors.grey.shade100,
                        alignment: Alignment.center,
                        child: Text(
                          uin > 0 ? uin.toString()[0] : '?',
                          style: TextStyle(
                              color: online
                                  ? Colors.green
                                  : Colors.grey.shade600,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ),
                // 在线状态角标
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      color: online
                          ? const Color(0xFF34C759)
                          : Colors.grey.shade400,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            title: Text(name.isNotEmpty ? '$name（$uin）' : 'QQ $uin'),
            subtitle: Text(
              online
                  ? '在线'
                  : ((a['status'] as String?)?.isNotEmpty ?? false
                      ? a['status'] as String
                      : '离线'),
              style: text.bodySmall?.copyWith(
                  color: online ? const Color(0xFF34C759) : Colors.grey.shade600),
            ),
            trailing: IconButton(
              onPressed: () => _msgDialog(uin),
              icon: Icon(Icons.send_rounded,
                  color: Colors.indigo.shade700),
            ),
          ),
        );
      },
    );
  }

  void _msgDialog(int uin) {
    final c = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('发消息给 QQ $uin'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(hintText: '消息内容'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _send(uin, uin, c.text.trim());
            },
            child: const Text('发送'),
          ),
        ],
      ),
    );
  }
}
