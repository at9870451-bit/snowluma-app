import "dart:ui" as ui show ImageFilter, FontFeature;

import 'package:flutter/material.dart';

import 'actions_page.dart';
import 'ai_settings_page.dart';
import 'home_page.dart';
import 'logs_page.dart';
import 'processes_page.dart';
import 'vnc_page.dart';

/// RootShell — 现代简约风底部导航 + 4 个 Tab
/// 细节：等宽数字 / 同心圆角 / 多层柔和阴影（无边框）/ 低饱和配色
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
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.apply(
              fontFamily: 'SF Mono',
              fontFamilyFallback: const ['Menlo', 'monospace'],
            ),
      ),
      child: Scaffold(
        extendBody: true,
        backgroundColor: const Color(0xFFF4F5F7), // 全页浅灰底
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

/// 底部导航：多层柔和阴影（无边框），选中黑底胶囊，同心圆角
class _GlassNavBar extends StatelessWidget {
  const _GlassNavBar({
    required this.tabs,
    required this.index,
    required this.onTap,
  });

  final List<_TabSpec> tabs;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(14, 0, 14, bottomInset > 0 ? bottomInset : 12),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(26), // 同心：外层26 = 内层胶囊20 + padding 6
          boxShadow: [
            // 多层柔和阴影代替实线边框
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
            BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 20, offset: const Offset(0, 8)),
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 40, offset: const Offset(0, 18)),
          ],
        ),
        child: Row(
          children: List.generate(tabs.length, (i) {
            final on = i == index;
            final t = tabs[i];
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.symmetric(horizontal: on ? 18 : 8, vertical: 8),
                    decoration: BoxDecoration(
                      // 选中标签变黑（黑白两档主次）
                      color: on ? const Color(0xFF17181C) : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(on ? t.activeIcon : t.icon,
                            size: 20, color: on ? Colors.white : const Color(0xFF9AA1AD)),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOutCubic,
                          child: on
                              ? Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: Text(t.label,
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// 工具 Tab：大字标题 + 搜索栏 + 黑圆筛选钮 + 通栏大图列表（错开入场）
class _ToolsTab extends StatelessWidget {
  const _ToolsTab();

  @override
  Widget build(BuildContext context) {
    final entries = [
      ('动作调试', 'OneBot 动作清单 · 参数构建', 'OPS', const ActionsPage()),
      ('系统信息', '服务状态 · 认证 · 协议版本', 'SYS', const LogsPage()),
      ('扫码登录', '远程桌面 + 二维码', 'QR', const VncPage()),
    ];
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'SnowLuma\n工具',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            height: 1.12,
            color: Color(0xFF17181C),
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 120),
          children: [
            // 搜索栏 + 黑圆筛选钮
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.centerLeft,
                    child: const Text('搜索功能…', style: TextStyle(color: Color(0xFF9AA1AD), fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFF17181C), // 黑圆筛选钮
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // 通栏大图列表（错开入场）
            for (var i = 0; i < entries.length; i++) ...[
              _StaggerIn(
                delay: Duration(milliseconds: 90 * i),
                child: _BigCard(
                  title: entries[i].$1,
                  subtitle: entries[i].$2,
                  badge: entries[i].$3,
                  page: entries[i].$4,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

/// 错开延迟入场
class _StaggerIn extends StatefulWidget {
  const _StaggerIn({required this.delay, required this.child});
  final Duration delay;
  final Widget child;

  @override
  State<_StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<_StaggerIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 520))
        ..forward();
  late final Animation<double> _a = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (_, child) => Opacity(
        opacity: _a.value,
        child: Transform.translate(offset: Offset(0, 16 * (1 - _a.value)), child: child),
      ),
      child: widget.child,
    );
  }
}

/// 通栏大图卡片：黑底头部块叠信息 + 底部信息条（等宽数字徽标）
class _BigCard extends StatelessWidget {
  const _BigCard({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.page,
  });

  final String title;
  final String subtitle;
  final String badge;
  final Widget page;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => page),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3)),
            BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 26, offset: const Offset(0, 12)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 黑底头部块叠信息
            Container(
              height: 96,
              decoration: const BoxDecoration(
                color: Color(0xFF17181C),
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(subtitle,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.55), fontSize: 12)),
                      ],
                    ),
                  ),
                  // 等宽数字徽标
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(badge,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12,
                            fontFeatures: [FontFeature.tabularFigures()])),
                  ),
                ],
              ),
            ),
            // 底部信息条
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  const Text('进入',
                      style: TextStyle(fontSize: 12, color: Color(0xFF9AA1AD))),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF17181C)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
