import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/bridge.dart';
import 'vnc_page.dart';

/// 进程接入页 — QQ 进程列表 + 加载/卸载/刷新 + QQ 账号状态
class ProcessesPage extends StatefulWidget {
  const ProcessesPage({super.key});

  @override
  State<ProcessesPage> createState() => _ProcessesPageState();
}

class _ProcessesPageState extends State<ProcessesPage> {
  bool _busy = false;
  List<Map<String, dynamic>> _processes = const [];
  List<Map<String, dynamic>> _accounts = const [];
  String? _err;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final api = appState.client;
    if (api == null) return;
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      _processes = await api.processes();
      final r = await api.qqList();
      _accounts = (r['accounts'] as List? ?? const []).cast<Map<String, dynamic>>();
    } catch (e) {
      _err = e.toString();
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _act(Map<String, dynamic> p, String action) async {
    final api = appState.client;
    if (api == null) return;
    final id = (p['id'] ?? p['pid'] ?? '').toString();
    if (id.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('进程缺少 id，无法操作')));
      return;
    }
    try {
      final Map<String, dynamic> r;
      switch (action) {
        case 'load':
          r = await api.processLoad(id);
        case 'unload':
          r = await api.processUnload(id);
        default:
          r = await api.processRefresh(id);
      }
      if (!mounted) return;
      // 中文友好提示（原来直接把 API 的 success=true 原始字段显示出来，看不懂）
      final ok = r['success'] == true || r['status'] == 'ok' || r['ok'] == true;
      final label = action == 'load' ? '载入' : (action == 'unload' ? '卸载' : '刷新');
      final detail = (r['message'] ?? r['msg'] ?? '').toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? '$label成功${detail.isNotEmpty ? '：$detail' : ''}'
              : '$label失败${detail.isNotEmpty ? '：$detail' : ''}'),
          backgroundColor: ok ? null : Colors.red.shade600,
        ),
      );
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('操作失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('接入 QQ'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const VncPage())),
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: '扫码登录 QQ',
          ),
          IconButton(
            onPressed: _busy ? null : _refresh,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _serverSpacer(context, text),
            const SizedBox(height: 6),
            if (_err != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_err!,
                    style: text.bodySmall?.copyWith(color: Colors.red)),
              ),
            _sectionCard(context, text, 'QQ 进程', Icons.memory_outlined,
                _processes.isEmpty ? _noProcess(context, text) : _processRows(context, text)),
            const SizedBox(height: 10),
            _sectionCard(context, text, 'QQ 账号', Icons.people_outline,
                _accounts.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('暂无已接入账号',
                            style: text.bodyMedium
                                ?.copyWith(color: Colors.grey.shade600)))
                    : _accountRows(context, text)),
          ],
        ),
      ),
    );
  }

  Widget _serverSpacer(BuildContext context, TextTheme text) => Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
          leading: const Icon(Icons.dns_outlined, color: Colors.indigo),
          title: const Text('SnowLuma 服务器'),
          subtitle: SelectableText(appState.serverLabel,
              style: text.bodySmall?.copyWith(color: Colors.grey.shade600)),
        ),
      );

  Widget _noProcess(BuildContext context, TextTheme text) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, size: 18, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('服务器未检测到 QQ 进程',
                      style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'SnowLuma 通过检测并注入 QQ 进程来接入账号。当前服务器没有可接入的 QQ 进程。',
              style: text.bodySmall?.copyWith(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 6),
            Text(
              '• 服务器已部署 Docker 版（自带 QQ），点下方「扫码登录」打开远程桌面扫码\n• 或：服务器新增 QQ 进程后点右上角刷新',
              style: text.bodySmall?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const VncPage())),
              icon: const Icon(Icons.qr_code_scanner, size: 18),
              label: const Text('扫码登录 QQ'),
            ),
          ],
        ),
      );

  Widget _sectionCard(BuildContext context, TextTheme text, String title,
          IconData icon, Widget body) =>
      Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.grey.shade200)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: Colors.indigo.shade700),
                  const SizedBox(width: 8),
                  Text(title,
                      style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            body,
          ],
        ),
      );

  Widget _processRows(BuildContext context, TextTheme text) => Column(
        children: [
          for (final p in _processes)
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              leading: Icon(
                (p['online'] == true || p['status'] == 'online')
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                size: 18,
                color: (p['online'] == true || p['status'] == 'online')
                    ? Colors.green
                    : Colors.grey.shade400,
              ),
              title: Text(
                (p['name'] ?? p['platform'] ?? p['id'] ?? 'QQ 进程').toString(),
                style: const TextStyle(fontSize: 14),
              ),
              subtitle: Text(
                'id=${p['id'] ?? p['pid'] ?? '-'} · ${p['status'] ?? p['state'] ?? 'idle'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall?.copyWith(color: Colors.grey.shade600),
              ),
              trailing: Wrap(
                spacing: 2,
                children: [
                  _opBtn('载入', () => _act(p, 'load')),
                  _opBtn('刷新', () => _act(p, 'refresh')),
                  _opBtn('卸载', () => _act(p, 'unload')),
                ],
              ),
            ),
        ],
      );

  Widget _accountRows(BuildContext context, TextTheme text) => Column(
        children: [
          for (final a in _accounts)
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              leading: const CircleAvatar(
                radius: 16,
                backgroundColor: Color(0xFF5FA8D3),
                child: Icon(Icons.person, size: 18, color: Colors.white),
              ),
              title: Text(
                (a['nickname']?.toString().isNotEmpty == true
                        ? '${a['nickname']}（${a['account_id'] ?? a['uin'] ?? '-'}）'
                        : 'QQ ${a['account_id'] ?? a['uin'] ?? '-'}'),
                style: const TextStyle(fontSize: 14),
              ),
              subtitle: Text(
                a['online'] == true ? '在线' : (a['status']?.toString() ?? '离线'),
                style: text.bodySmall?.copyWith(
                    color: a['online'] == true
                        ? Colors.green.shade600
                        : Colors.grey.shade600),
              ),
            ),
        ],
      );

  Widget _opBtn(String label, VoidCallback onTap) => TextButton(
        onPressed: _busy ? null : onTap,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          visualDensity: VisualDensity.compact,
          textStyle: const TextStyle(fontSize: 12),
        ),
        child: Text(label),
      );
}