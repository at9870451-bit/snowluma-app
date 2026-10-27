import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'actions_page.dart';
import 'ai_settings_page.dart';
import 'home_page.dart';
import 'logs_page.dart';
import 'processes_page.dart';
import 'vnc_page.dart';

/// RootShell — iOS 原生风格毛玻璃底部导航 + 4 个 Tab
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  static const List<_TabSpec> _tabs = [
    _TabSpec(Icons.person_outline_rounded, Icons.person_rounded, '账号'),
    _TabSpec(Icons.qr_code_scanner_rounded, Icons.qr_code_scanner_rounded, '接入'),
    _TabSpec(Icons.auto_awesome_outlined, Icons.auto_awesome, 'AI'),
    _TabSpec(Icons.tune_rounded, Icons.tune_rounded, '工具'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _index,
        children: const [
          HomePage(),
          ProcessesPage(),
          AiSettingsPage(),
          _ToolsTab(),
        ],
      ),
      bottomNavigationBar: _GlassNavBar(
        tabs: _tabs,
        index: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _TabSpec {
  const _TabSpec(this.icon, this.activeIcon, this.label);
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// iOS 原生风格毛玻璃导航栏（模糊 + 半透明白 + 圆角胶囊 + 阴影）
class _GlassNavBar extends StatelessWidget {
  const _GlassNavBar({
    required this.tabs,
    required this.index,
    required this.onTap,
  });

  final List<_TabSpec> tabs;
  final int index;
  final ValueChanged<int> onTap;

  static const Color _iosBlue = Color(0xFF007AFF);

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(14, 0, 14, bottomInset > 0 ? bottomInset : 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.70),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.75),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 26,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: List.generate(tabs.length, (i) {
                final t = tabs[i];
                final selected = i == index;
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          selected ? t.activeIcon : t.icon,
                          size: 23,
                          color: selected
                              ? _iosBlue
                              : const Color(0xFF8E8E93),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          t.label,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.w500,
                            color: selected
                                ? _iosBlue
                                : const Color(0xFF8E8E93),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

/// 工具 Tab — 动作调试 / 系统信息 / 扫码登录入口
class _ToolsTab extends StatelessWidget {
  const _ToolsTab();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('工具')),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 120),
          children: [
            _tile(
              context,
              icon: Icons.play_circle_outline_rounded,
              title: '动作调试',
              subtitle: 'OneBot 动作清单 + 参数构建 + 调用结果',
              page: const ActionsPage(),
            ),
            _tile(
              context,
              icon: Icons.article_outlined,
              title: '系统信息',
              subtitle: '服务状态 / 认证 / 协议 / 核心版本',
              page: const LogsPage(),
            ),
            _tile(
              context,
              icon: Icons.qr_code_2_rounded,
              title: '扫码登录 QQ',
              subtitle: '远程桌面 + 二维码',
              page: const VncPage(),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                '提示：底部导航为 iOS 毛玻璃风格，4 个 Tab 分别为 账号 / 接入 / AI / 工具。',
                style: text.bodySmall?.copyWith(color: Colors.grey.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(BuildContext context,
      {required IconData icon,
      required String title,
      required String subtitle,
      required Widget page}) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF007AFF).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF007AFF)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey.shade600)),
        trailing: const Icon(Icons.chevron_right_rounded,
            size: 20, color: Color(0xFFC7C7CC)),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => page),
        ),
      ),
    );
  }
}
