import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/qqbot_client.dart';
import '../../core/snow_theme.dart';
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
    final bottom = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      appBar: AppBar(
        title: const Text('QQBot 管理'),
        actions: [
          IconButton(
            tooltip: '刷新状态',
            onPressed: _checking ? null : _ping,
            icon: _checking
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _ping,
        child: LayoutBuilder(builder: (context, constraints) {
          final inset = constraints.maxWidth > 720 ? 32.0 : 20.0;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(inset, 12, inset, bottom + 32),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('CONTROL CENTER',
                          style: TextStyle(fontSize: 11, letterSpacing: 2,
                              color: SnowStyle.muted, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 9),
                      const Text('QQBot\n管理中心',
                          style: TextStyle(fontSize: 34, height: 1.1,
                              letterSpacing: -1.1, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 22),
                      _entryFade(0, _statusBanner(online, running)),
                      const SectionLabel('核心'),
                      _entryFade(1, _grid([
                        _Entry('总览', '运行状态与统计', Icons.dashboard_outlined,
                            const QqbotOverviewPage(), const Color(0xFF007AFF)),
                        _Entry('运行日志', '按级别查看', Icons.receipt_long_outlined,
                            const QqbotLogsPage(), const Color(0xFF5856D6)),
                        _Entry('知识库', '按群知识文档', Icons.menu_book_outlined,
                            const QqbotKbPage(), const Color(0xFF34C759)),
                        _Entry('记忆库', 'AI 记住的事', Icons.psychology_outlined,
                            const QqbotMemoryPage(), const Color(0xFFFF9500)),
                      ])),
                      const SectionLabel('管理'),
                      _entryFade(2, _grid([
                        _Entry('置控台', '群闭嘴/恢复', Icons.tune_rounded,
                            const QqbotConsolePage(), const Color(0xFFFF3B30)),
                        _Entry('表情包库', '收藏的图', Icons.emoji_emotions_outlined,
                            const QqbotStickersLibPage(), const Color(0xFFFF2D55)),
                        _Entry('插件管理', '开关与重载', Icons.extension_outlined,
                            const QqbotPluginsPage(), const Color(0xFFAF52DE)),
                        _Entry('AI/生图', '生效配置', Icons.auto_awesome_outlined,
                            const QqbotAiConfigPage(), const Color(0xFF30B0C7)),
                      ])),
                      const SectionLabel('其它'),
                      _entryFade(3, QCard(
                        padding: EdgeInsets.zero,
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(SnowStyle.radius),
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(SnowStyle.radius)),
                            leading: const Icon(Icons.language_rounded, size: 22),
                            title: const Text('原版 Web 面板',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: const Text('包含 QQ 登录等原生未覆盖功能'),
                            trailing: const Icon(Icons.arrow_forward_rounded, size: 20),
                            onTap: () => _open(const QqbotPanelPage()),
                          ),
                        ),
                      )),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                        child: Text('QQBot 地址 ${_api.baseUrl}（由服务器地址自动推导，端口 6199）',
                            style: const TextStyle(fontSize: 11,
                                color: SnowStyle.muted, height: 1.4)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _entryFade(int index, Widget child) {
    if (MediaQuery.of(context).disableAnimations) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 360 + index * 100),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(offset: Offset(0, 12 * (1 - value)), child: child),
      ),
      child: child,
    );
  }

  Widget _statusBanner(bool online, bool running) {
    final String title;
    final String sub;
    if (_checking && _status == null) {
      title = '正在连接 QQBot…';
      sub = _api.baseUrl;
    } else if (_checkErr != null) {
      title = 'QQBot 面板无法访问';
      sub = '请确认服务器 6199 端口对外可访问\n$_checkErr';
    } else if (online) {
      title = 'QQBot 在线';
      sub = 'QQ ${_status?['self_id'] ?? '-'} · v${_status?['version'] ?? '-'} · '
          '已运行 ${fmtDuration((_status?['uptime'] as num?) ?? 0)}';
    } else {
      title = running ? 'QQBot 运行中，QQ 未连接' : 'QQBot 未运行';
      sub = _api.baseUrl;
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: SnowStyle.card(color: SnowStyle.ink, radius: 26),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 9, height: 9, decoration: BoxDecoration(
            color: online ? const Color(0xFF9BD1B1) : const Color(0xFFB9A795),
            shape: BoxShape.circle)),
          const SizedBox(width: 8),
          const Expanded(child: Text('CONNECTION STATUS',
              style: TextStyle(color: Color(0xFFB5B8C2), fontSize: 10,
                  letterSpacing: 1.4, fontWeight: FontWeight.w700))),
          if (_checkErr != null)
            TextButton(onPressed: _checking ? null : _ping,
                child: const Text('重试', style: TextStyle(color: Colors.white))),
        ]),
        const SizedBox(height: 16),
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 22,
            fontWeight: FontWeight.w800, height: 1.2)),
        const SizedBox(height: 8),
        Text(sub, style: const TextStyle(color: Color(0xFFC5C7CF), fontSize: 12,
            height: 1.5, fontFeatures: SnowStyle.tabular)),
      ]),
    );
  }

  Widget _grid(List<_Entry> entries) {
    return LayoutBuilder(builder: (context, constraints) {
      const gap = 12.0;
      final cols = constraints.maxWidth >= 900 ? 4 :
          (constraints.maxWidth >= 580 ? 3 : (constraints.maxWidth < 310 ? 1 : 2));
      final width = (constraints.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: entries.map((entry) => SizedBox(
          width: width,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(SnowStyle.radius),
              onTap: () => _open(entry.page),
              child: Ink(
                decoration: SnowStyle.card(),
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 126),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(color: SnowStyle.softAccent,
                              borderRadius: BorderRadius.circular(14)),
                          child: Icon(entry.icon, size: 21, color: SnowStyle.accent),
                        ),
                        const Spacer(),
                        const Icon(Icons.north_east_rounded, size: 17,
                            color: SnowStyle.muted),
                      ]),
                      const SizedBox(height: 16),
                      Text(entry.title, style: const TextStyle(fontSize: 15,
                          fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(entry.subtitle, style: const TextStyle(fontSize: 12,
                          color: SnowStyle.muted, height: 1.35)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        )).toList(),
      );
    });
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