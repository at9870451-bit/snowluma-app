import 'dart:math' as math;
import 'dart:ui' as ui show ImageFilter;

import 'package:flutter/material.dart';

import '../core/snow_theme.dart';
import 'actions_page.dart';
import 'ai_settings_page.dart';
import 'home_page.dart';
import 'logs_page.dart';
import 'processes_page.dart';
import 'vnc_page.dart';

const _canvas = Color(0xFFF4F5F7);
const _ink = Color(0xFF17181C);
const _muted = Color(0xFF5E6572);
const _indigo = Color(0xFF3949AB);

/// 多层柔和阴影，替代实线边框。
const _softShadows = <BoxShadow>[
  BoxShadow(color: Color(0x070E1726), blurRadius: 8, offset: Offset(0, 3)),
  BoxShadow(color: Color(0x0D0E1726), blurRadius: 26, offset: Offset(0, 12)),
];

/// Four persistent destinations. The IndexedStack intentionally keeps each
/// tab's state and lifecycle unchanged when another tab is selected.
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

  void _selectTab(int index) {
    if (_index == index) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    // The bar must not cover a focused field or ride on top of the keyboard.
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: true,
      backgroundColor: _canvas,
      body: IndexedStack(
        index: _index,
        children: [
          const HomePage(),
          const ProcessesPage(),
          const AiSettingsPage(),
          _ToolsTab(isActive: _index == 3),
        ],
      ),
      bottomNavigationBar: keyboardOpen
          ? null
          : _GlassNavBar(tabs: _tabs, index: _index, onTap: _selectTab),
    );
  }
}

class _TabSpec {
  const _TabSpec(this.icon, this.activeIcon, this.label);
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// A genuinely blurred surface; its shadow sits outside the clipped blur.
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
    final media = MediaQuery.of(context);
    final reduceMotion = media.disableAnimations || media.accessibleNavigation;
    final bottomSpace = math.max(12.0, media.viewPadding.bottom + 6.0);
    final labelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ) ??
        const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        );
    final painter = TextPainter(
      text: TextSpan(text: tabs[index].label, style: labelStyle),
      textDirection: Directionality.of(context),
      textScaler: media.textScaler,
      maxLines: 1,
    )..layout();
    final labelWidth = painter.width;
    final labelHeight = painter.height;
    painter.dispose();

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, bottomSpace),
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const gap = 4.0;
              const innerPadding = 6.0;
              // Container's one-pixel border also consumes inner width.
              final available = math.max(0.0, constraints.maxWidth -
                  innerPadding * 2 - 2 - gap * (tabs.length - 1));
              final wantedSelectedWidth = math.max(82.0, 20 + 6 + labelWidth + 28);
              // Stack the active icon/label if large type or a narrow window
              // cannot also leave at least 48 logical pixels for other tabs.
              final compact = wantedSelectedWidth > available - 48 * (tabs.length - 1);
              final selectedWidth = compact
                  ? math.min(
                      math.max(available / tabs.length, available - 48 * (tabs.length - 1)),
                      math.max(available / tabs.length, labelWidth + 12),
                    )
                  : wantedSelectedWidth;
              final otherWidth = (available - selectedWidth) / (tabs.length - 1);
              var displayedLabelHeight = labelHeight;
              if (compact) {
                final wrapped = TextPainter(
                  text: TextSpan(text: tabs[index].label, style: labelStyle),
                  textDirection: Directionality.of(context),
                  textScaler: media.textScaler,
                )..layout(maxWidth: math.max(1.0, selectedWidth - 8));
                displayedLabelHeight = wrapped.height;
                wrapped.dispose();
              }
              final height = compact
                  ? math.max(64.0, 20 + 2 + displayedLabelHeight + 24)
                  : math.max(64.0, displayedLabelHeight + 24);
              final radius = BorderRadius.circular(30);

              return Container(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 44,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: radius,
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                    child: Container(
                      height: height,
                      padding: const EdgeInsets.all(innerPadding),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.76),
                        borderRadius: radius,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.65)),
                      ),
                      child: Row(
                        children: [
                          for (var i = 0; i < tabs.length; i++) ...[
                            if (i > 0) const SizedBox(width: gap),
                            _NavItem(
                              tab: tabs[i],
                              selected: i == index,
                              width: i == index ? selectedWidth : otherWidth,
                              compact: compact,
                              labelStyle: labelStyle,
                              duration: reduceMotion
                                  ? Duration.zero
                                  : const Duration(milliseconds: 220),
                              onTap: () => onTap(i),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.selected,
    required this.width,
    required this.compact,
    required this.labelStyle,
    required this.duration,
    required this.onTap,
  });

  final _TabSpec tab;
  final bool selected;
  final double width;
  final bool compact;
  final TextStyle labelStyle;
  final Duration duration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      selected ? tab.activeIcon : tab.icon,
      size: 20,
      color: selected ? Colors.white : const Color(0xFF626B7A),
    );
    final label = Text(
      tab.label,
      style: labelStyle,
      maxLines: compact ? null : 1,
      softWrap: compact,
      textAlign: TextAlign.center,
    );
    return Semantics(
      label: tab.label,
      button: true,
      selected: selected,
      onTap: onTap,
      onTapHint: '切换到${tab.label}',
      child: ExcludeSemantics(
        child: SizedBox(
          width: width,
          height: double.infinity,
          child: AnimatedContainer(
            duration: duration,
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: selected ? _ink : Colors.transparent,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Center(
                    child: compact && selected
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [icon, const SizedBox(height: 2), label],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              icon,
                              if (selected) ...[
                                const SizedBox(width: 6),
                                Flexible(child: label),
                              ],
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _ToolCategory {
  all('全部功能'),
  debug('动作调试'),
  system('系统信息'),
  account('账号接入');

  const _ToolCategory(this.label);
  final String label;
}

class _ToolEntry {
  const _ToolEntry({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.index,
    required this.icon,
    required this.category,
    required this.keywords,
    required this.page,
  });

  final String title;
  final String subtitle;
  final String badge;
  final String index;
  final IconData icon;
  final _ToolCategory category;
  final String keywords;
  final Widget page;

  bool matches(String query, _ToolCategory selected) {
    if (selected != _ToolCategory.all && category != selected) return false;
    final haystack = '$title $subtitle $badge ${category.label} $keywords'.toLowerCase();
    final terms = query.trim().toLowerCase().split(RegExp(r'\s+'));
    return terms.every((term) => term.isEmpty || haystack.contains(term));
  }
}

class _ToolsTab extends StatefulWidget {
  const _ToolsTab({required this.isActive});
  final bool isActive;

  @override
  State<_ToolsTab> createState() => _ToolsTabState();
}

class _ToolsTabState extends State<_ToolsTab> {
  static const _entries = <_ToolEntry>[
    _ToolEntry(
      title: '动作调试',
      subtitle: 'OneBot 动作清单、参数构建与调用结果',
      badge: 'ONEBOT',
      index: '01',
      icon: Icons.play_circle_outline_rounded,
      category: _ToolCategory.debug,
      keywords: '动作 调试 接口 测试 参数 调用 action api',
      page: ActionsPage(),
    ),
    _ToolEntry(
      title: '系统信息',
      subtitle: '查看服务状态、认证、协议与核心版本',
      badge: 'SYSTEM',
      index: '02',
      icon: Icons.article_outlined,
      category: _ToolCategory.system,
      keywords: '系统 信息 服务 状态 认证 协议 版本 日志 log status',
      page: LogsPage(),
    ),
    _ToolEntry(
      title: '扫码登录 QQ',
      subtitle: '打开远程桌面，使用二维码登录 QQ',
      badge: 'CONNECT',
      index: '03',
      icon: Icons.qr_code_2_rounded,
      category: _ToolCategory.account,
      keywords: '扫码 登录 二维码 账号 接入 远程桌面 vnc qr qq',
      page: VncPage(),
    ),
  ];

  final _search = TextEditingController();
  _ToolCategory _category = _ToolCategory.all;
  bool _hasEntered = false;

  @override
  void initState() {
    super.initState();
    _hasEntered = widget.isActive;
  }

  @override
  void didUpdateWidget(covariant _ToolsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) _hasEntered = true;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _showFilters() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final result = await showModalBottomSheet<_ToolCategory>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _FilterSheet(selected: _category),
    );
    if (!mounted || result == null || result == _category) return;
    setState(() => _category = result);
  }

  void _resetFilters() {
    _search.clear();
    setState(() => _category = _ToolCategory.all);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final reduceMotion = media.disableAnimations || media.accessibleNavigation;
    final visible = _entries
        .where((entry) => entry.matches(_search.text, _category))
        .toList(growable: false);
    final filtered = _search.text.trim().isNotEmpty || _category != _ToolCategory.all;
    // With extendBody, Scaffold inserts its actual bar height into the body's
    // bottom MediaQuery padding. Do not hard-code a second bar/safe-area inset.
    final bottomPadding = math.max(24.0, media.padding.bottom + 24.0);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: _canvas,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontal = constraints.maxWidth < 360 ? 16.0 : 24.0;
            return ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(horizontal, 26, horizontal, bottomPadding),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _ToolsHeader(),
                        const SizedBox(height: 26),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: _ToolSearchField(
                                controller: _search,
                                onChanged: () => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 10),
                            _FilterButton(
                              category: _category,
                              onPressed: _showFilters,
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 6,
                          children: [
                            Semantics(
                              header: true,
                              child: const Text('功能列表', style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: _ink,
                              )),
                            ),
                            Text(
                              '${filtered ? '匹配' : '全部'} ${visible.length} 项'
                              '${_category == _ToolCategory.all ? '' : ' · ${_category.label}'}',
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (visible.isEmpty)
                          _EmptyTools(onReset: _resetFilters)
                        else
                          for (final entry in visible) ...[
                            _StaggerIn(
                              key: ValueKey(entry.index),
                              enabled: _hasEntered && !filtered && !reduceMotion,
                              delay: Duration(milliseconds: int.parse(entry.index) * 75 - 75),
                              child: _ToolCard(entry: entry),
                            ),
                            const SizedBox(height: 12),
                          ],
                        const SizedBox(height: 10),
                        const Text(
                          'QQBot 管理中心可在「账号」中打开。',
                          style: TextStyle(color: _muted, fontSize: 12, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ToolsHeader extends StatelessWidget {
  const _ToolsHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SNOWLUMA  /  TOOLS',
          style: TextStyle(
            color: _indigo,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Semantics(
          header: true,
          child: const Text(
            '发现工具',
            style: TextStyle(
              color: _ink,
              fontSize: 36,
              height: 1.1,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
        ),
        const SizedBox(height: 9),
        const Text(
          '调试、查看状态，或接入你的 QQ。',
          style: TextStyle(color: _muted, fontSize: 14, height: 1.5),
        ),
      ],
    );
  }
}

class _ToolSearchField extends StatelessWidget {
  const _ToolSearchField({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: _softShadows,
      ),
      child: TextField(
        controller: controller,
        onChanged: (_) => onChanged(),
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => FocusScope.of(context).unfocus(),
        style: const TextStyle(color: _ink, fontSize: 15),
        decoration: const InputDecoration(
          hintText: '搜索功能、关键词',
          hintStyle: TextStyle(color: Color(0xFF69717E)),
          prefixIcon: Icon(Icons.search_rounded, color: _muted, size: 22),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 17),
        ),
      ),
    );
  }
}

/// 黑色圆形筛选按钮：点开底部筛选面板，启用筛选时显示小圆点。
class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.category, required this.onPressed});

  final _ToolCategory category;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final active = category != _ToolCategory.all;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: _ink,
            shape: BoxShape.circle,
            boxShadow: _softShadows,
          ),
          child: IconButton(
            tooltip: '筛选功能分类',
            onPressed: onPressed,
            icon: const Icon(Icons.tune_rounded, color: Colors.white),
          ),
        ),
        if (active)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                  color: style_core.SnowStyle.accent, shape: BoxShape.circle),
            ),
          ),
      ],
    );
  }
}

/// 空结果卡片：给出重置入口。
class _EmptyTools extends StatelessWidget {
  const _EmptyTools({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: SnowStyle.card(),
      child: Column(
        children: [
          const Icon(Icons.search_off_rounded, size: 40, color: _muted),
          const SizedBox(height: 12),
          const Text('没有匹配的工具',
              style: TextStyle(fontWeight: FontWeight.w700, color: _ink)),
          const SizedBox(height: 6),
          const Text('换个关键词，或清除筛选条件再试。',
              style: TextStyle(color: _muted, fontSize: 12.5, height: 1.45)),
          const SizedBox(height: 14),
          TextButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('清除搜索和筛选'),
          ),
        ],
      ),
    );
  }
}

/// 工具卡片：黑底头部块叠信息 + 说明与进入区域。
class _ToolCard extends StatelessWidget {
  const _ToolCard({required this.entry});

  final _ToolEntry entry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(SnowStyle.radius),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => entry.page),
        ),
        child: Ink(
          decoration: SnowStyle.card(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  color: _ink,
                  borderRadius: BorderRadius.vertical(
                      top: Radius.circular(SnowStyle.radius)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry.badge,
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.55),
                                  fontSize: 10,
                                  letterSpacing: 1.4,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          Text(entry.title,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                    Text(entry.index,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            fontFeatures: SnowStyle.tabular)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.subtitle,
                        style: const TextStyle(
                            color: _muted, fontSize: 12.5, height: 1.45),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded,
                        size: 18, color: _indigo),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 底部筛选面板：单选分类。
class _FilterSheet extends StatelessWidget {
  const _FilterSheet({required this.selected});

  final _ToolCategory selected;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      margin: const EdgeInsets.all(14),
      padding: EdgeInsets.fromLTRB(20, 18, 20, bottom + 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('筛选分类',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          for (final category in _ToolCategory.values)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                category == selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: category == selected ? _indigo : _muted,
              ),
              title: Text(category.label),
              onTap: () => Navigator.pop(context, category),
            ),
        ],
      ),
    );
  }
}

/// 错开入场动画：延迟淡入 + 轻微上移。
class _StaggerIn extends StatefulWidget {
  const _StaggerIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.enabled = true,
  });

  final Widget child;
  final Duration delay;
  final bool enabled;

  @override
  State<_StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<_StaggerIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
    value: widget.enabled ? 0 : 1,
  );
  late final Animation<double> _animation =
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void didUpdateWidget(covariant _StaggerIn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !oldWidget.enabled && !_controller.isCompleted) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) => Opacity(
        opacity: _animation.value,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - _animation.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}
