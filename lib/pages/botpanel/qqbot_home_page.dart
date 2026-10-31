import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/qqbot_client.dart';
import '../qqbot_panel_page.dart';
import 'ai_config_page.dart';
import 'console_page.dart';
import 'kb_page.dart';
import 'logs_page.dart';
import 'memory_page.dart';
import 'overview_page.dart';
import 'plugins_page.dart';
import 'q_ui.dart';
import 'stickers_lib_page.dart';

/// QQBot 管理中心 — App 内原生管理所有 QQBot 功能（复用 6199 API）
///
/// 模块分组：
///   P0 核心：总览 · 运行日志 · 知识库 · 记忆库
///   P1 管理：置控台 · 表情包库 · 插件管理 · AI/生图配置
///   其它：原版 Web 面板（WebView 兜底）
class QqbotHomePage extends StatefulWidget {
  const QqbotHomePage({super.key});

  @override
  State<QqbotHomePage> createState() => _QqbotHomePageState();
}

class _QqbotHomePageState extends State<QqbotHomePage> {
  QqbotClient get _api => QqbotClient.fromSnowLuma(appState.baseUrl);

  Map<String, dynamic>? _status;
  bool _checking = true;
  String? _checkErr;

  @override
  void initState() {
    super.initState();
    _ping();
  }

  Future<void> _ping() async {
    setState(() {
      _checking = true;
      _checkErr = null;
    });
    try {
      final s = await _api.status();
      if (!mounted) return;
      setState(() {
        _status = s;
        _checking = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _checkErr = e.toString();
      });
    }
  }

  void _open(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final online = _status?['connected'] == true;
    final running = _status?['running'] == true;
    return Scaffold(
      appBar: AppBar(
        title: const Text('QQBot 管理'),
        actions: [
          IconButton(
            tooltip: '刷新状态',
            onPressed: _checking ? null : _ping,
            icon: _checking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _ping,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 120),
          children: [
            _statusBanner(online, running),
            const SectionLabel('核心'),
            _grid([
              _Entry('总览', '运行状态与统计', Icons.dashboard_outlined,
                  const QqbotOverviewPage(), const Color(0xFF007AFF)),
              _Entry('运行日志', '按级别查看', Icons.receipt_long_outlined,
                  const QqbotLogsPage(), const Color(0xFF5856D6)),
              _Entry('知识库', '按群知识文档', Icons.menu_book_outlined,
                  const QqbotKbPage(), const Color(0xFF34C759)),
              _Entry('记忆库', 'AI 记住的事', Icons.psychology_outlined,
                  const QqbotMemoryPage(), const Color(0xFFFF9500)),
            ]),
            const SectionLabel('管理'),
            _grid([
              _Entry('置控台', '群闭嘴/恢复', Icons.tune_rounded,
                  const QqbotConsolePage(), const Color(0xFFFF3B30)),
              _Entry('表情包库', '收藏的图', Icons.emoji_emotions_outlined,
                  const QqbotStickersLibPage(), const Color(0xFFFF2D55)),
              _Entry('插件管理', '开关与重载', Icons.extension_outlined,
                  const QqbotPluginsPage(), const Color(0xFFAF52DE)),
              _Entry('AI/生图', '生效配置', Icons.auto_awesome_outlined,
                  const QqbotAiConfigPage(), const Color(0xFF30B0C7)),
            ]),
            const SectionLabel('其它'),
            QCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.language_rounded, size: 22),
                title: const Text('原版 Web 面板',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: Text('WebView 兜底，含 QQ 登录等原生未覆盖功能',
                    style: TextStyle(
                        fontSize: 11.5, color: Colors.grey.shade600)),
                trailing: const Icon(Icons.chevron_right_rounded,
                    size: 20, color: Color(0xFFC7C7CC)),
                onTap: () => _open(const QqbotPanelPage()),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                'QQBot 地址 ${_api.baseUrl}（由服务器地址自动推导，端口 6199）',
                style:
                    TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBanner(bool online, bool running) {
    final Color c;
    final String title;
    final String sub;
    if (_checking && _status == null) {
      c = kIosBlue;
      title = '正在连接 QQBot…';
      sub = _api.baseUrl;
    } else if (_checkErr != null) {
      c = const Color(0xFFFF3B30);
      title = 'QQBot 面板无法访问';
      sub = '请确认服务器 6199 端口对外可访问\n$_checkErr';
    } else if (online) {
      c = const Color(0xFF34C759);
      title = 'QQBot 在线';
      sub = 'QQ ${_status?['self_id'] ?? '-'} · v${_status?['version'] ?? '-'} · '
          '已运行 ${fmtDuration((_status?['uptime'] as num?) ?? 0)}';
    } else {
      c = const Color(0xFFFF9500);
      title = running ? 'QQBot 运行中，QQ 未连接' : 'QQBot 未运行';
      sub = _api.baseUrl;
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: c.withValues(alpha: 0.14), shape: BoxShape.circle),
            child: Icon(
              _checkErr != null
                  ? Icons.cloud_off_rounded
                  : online
                      ? Icons.check_rounded
                      : Icons.warning_amber_rounded,
              color: c,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w700, color: c)),
                const SizedBox(height: 3),
                Text(sub,
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                        height: 1.35)),
              ],
            ),
          ),
          if (_checkErr != null)
            TextButton(
                onPressed: _ping,
                child: const Text('重试', style: TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Widget _grid(List<_Entry> entries) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.55,
      children: entries.map((e) {
        return GestureDetector(
          onTap: () => _open(e.page),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: e.color.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(e.icon, size: 17, color: e.color),
                ),
                const SizedBox(height: 8),
                Text(e.title,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 1),
                Text(e.subtitle,
                    style: TextStyle(
                        fontSize: 10.5, color: Colors.grey.shade500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _Entry {
  const _Entry(this.title, this.subtitle, this.icon, this.page, this.color);
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget page;
  final Color color;
}