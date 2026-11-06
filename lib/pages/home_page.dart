import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/bridge.dart';
import 'ai_settings_page.dart';
import 'botpanel/qqbot_home_page.dart';
import 'contacts_page.dart';
import 'login_page.dart';
import 'processes_page.dart';
import 'stickers_page.dart';
import 'vnc_page.dart';

const _background = Color(0xFFF4F5F7);
const _ink = Color(0xFF17181C);
const _muted = Color(0xFF6E7583);
const _indigo = Color(0xFF4856B7);
const _cardRadius = 26.0;

List<BoxShadow> get _softShadows => [
      BoxShadow(
        color: Colors.black.withOpacity(0.035),
        blurRadius: 10,
        offset: const Offset(0, 3),
      ),
      BoxShadow(
        color: Colors.black.withOpacity(0.045),
        blurRadius: 28,
        offset: const Offset(0, 12),
      ),
      BoxShadow(
        color: Colors.black.withOpacity(0.025),
        blurRadius: 48,
        offset: const Offset(0, 20),
      ),
    ];

enum _AccountFilter { all, online, offline }

class _Feature {
  const _Feature({
    required this.index,
    required this.title,
    required this.description,
    required this.tag,
    required this.keywords,
    required this.icon,
    required this.page,
  });

  final int index;
  final String title;
  final String description;
  final String tag;
  final String keywords;
  final IconData icon;
  final Widget page;

  bool matches(String query) =>
      '$title $description $tag $keywords'.toLowerCase().contains(query);
}

const _features = <_Feature>[
  _Feature(
    index: 0,
    title: '我的群聊和好友',
    description: '查看当前 QQ 账号已添加的群聊与好友',
    tag: 'CONTACTS',
    keywords: '群聊好友 联系人 朋友 groups friends',
    icon: Icons.people_alt_outlined,
    page: ContactsPage(),
  ),
  _Feature(
    index: 1,
    title: 'AI 收藏的表情包',
    description: '看到就收 · 回复时只发自己收藏的',
    tag: 'STICKERS',
    keywords: 'ai表情包 收藏 表情 emoji',
    icon: Icons.emoji_emotions_outlined,
    page: StickersPage(),
  ),
  _Feature(
    index: 2,
    title: 'QQBot 管理中心',
    description: '总览 / 知识库 / 记忆 / 插件 / 群管控',
    tag: 'BOT CENTER',
    keywords: 'qqbot机器人 管理面板 bot',
    icon: Icons.smart_toy_outlined,
    page: QqbotHomePage(),
  ),
];

/// 首页：服务器状态、功能入口与 QQ 账号。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  late final AnimationController _entranceController;
  bool _busy = false;
  bool _hasLoadedAccounts = false;
  Map<String, dynamic>? _status;
  Map<String, dynamic>? _coreVersion;
  List<Map<String, dynamic>> _accounts = const [];
  String? _err;
  _AccountFilter _accountFilter = _AccountFilter.all;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..forward();
    _refresh();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _err = null;
    });
    // 版本来自同一 Rust Core，读取失败时显示占位，并在下次刷新时重试。
    try {
      _coreVersion = SnowLumaBridge.call('core.version');
    } catch (_) {
      _coreVersion = null;
    }
    try {
      final api = appState.client;
      if (api == null) return;
      final status = await api.status();
      if (!mounted) return;
      setState(() => _status = status);
      final result = await api.qqList();
      final accounts = (result['accounts'] as List? ?? const [])
          .cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _hasLoadedAccounts = true;
      });
    } catch (error) {
      if (mounted) setState(() => _err = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send(int uin, int target, String text) async {
    final api = appState.client;
    if (api == null) return;
    try {
      final result =
          await api.sendPrivateMsg(uin: uin, target: target, text: text);
      if (!mounted) return;
      final display = result.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '发送结果: ${display.length > 80 ? display.substring(0, 80) : display}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('发送失败: $error')));
    }
  }

  Future<void> _msgDialog(int uin) async {
    final message = await showDialog<String>(
      context: context,
      builder: (_) => _MessageDialog(uin: uin),
    );
    if (!mounted || message == null) return;
    await _send(uin, uin, message);
  }

  bool _isOnline(Map<String, dynamic> account) {
    final raw = account['raw'] as Map?;
    // 与原列表使用相同的在线判断，确保筛选和显示一致。
    return account['online'] == true ||
        (raw?['online']?.toString().contains('on') ?? false);
  }

  bool _matchesAccount(Map<String, dynamic> account, String query) {
    final matchesSearch = query.isEmpty ||
        '${account['nickname'] ?? ''} ${account['account_id'] ?? ''} '
                '${account['status'] ?? ''} ${_isOnline(account) ? '在线' : '离线'}'
            .toLowerCase()
            .contains(query);
    final online = _isOnline(account);
    final matchesFilter = _accountFilter == _AccountFilter.all ||
        (_accountFilter == _AccountFilter.online && online) ||
        (_accountFilter == _AccountFilter.offline && !online);
    return matchesSearch && matchesFilter;
  }

  void _clearSearchAndFilter() {
    _searchController.clear();
    if (_accountFilter != _AccountFilter.all) {
      setState(() => _accountFilter = _AccountFilter.all);
    }
  }

  Widget _enter(Widget child, int index) {
    final media = MediaQuery.of(context);
    if (media.disableAnimations || media.accessibleNavigation) return child;
    final start = index * 0.09;
    final animation = CurvedAnimation(
      parent: _entranceController,
      curve: Interval(start, math.min(start + 0.4, 1.0), curve: Curves.easeOut),
    );
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.035),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final features = _features
        .where((feature) => query.isEmpty || feature.matches(query))
        .toList();
    final accounts = _accounts
        .where((account) => _matchesAccount(account, query))
        .toList();
    final isFiltering = query.isNotEmpty || _accountFilter != _AccountFilter.all;
    final bottomPadding =
        math.max(120.0, MediaQuery.of(context).padding.bottom + 100.0);

    return Scaffold(
      backgroundColor: _background,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: _background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 20,
        title: const Text(
          'SNOWLUMA',
          style: TextStyle(
            color: _ink,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
          ),
        ),
        actions: [
          IconButton(
            tooltip: '刷新状态和账号',
            onPressed: _busy ? null : _refresh,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded, color: _ink),
          ),
          PopupMenuButton<String>(
            tooltip: '更多操作',
            icon: const Icon(Icons.more_horiz_rounded, color: _ink),
            onSelected: (value) async {
              switch (value) {
                case 'logout':
                  await appState.disconnect();
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => LoginPage(onConnected: () {}),
                    ),
                    (_) => false,
                  );
                  break;
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('退出登录', style: TextStyle(color: Colors.red)),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // 大屏限制内容宽度；小屏保留一致的边距。
            final side = math.max(20.0, (constraints.maxWidth - 1120) / 2);
            return CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(side, 8, side, 0),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _enter(_header(), 0),
                      const SizedBox(height: 24),
                      _enter(_searchBar(), 1),
                      const SizedBox(height: 24),
                      _enter(_statusCard(), 2),
                      if (_err != null) ...[
                        const SizedBox(height: 14),
                        _errorNotice(_err!),
                      ],
                      const SizedBox(height: 34),
                      _sectionHeading(
                        '快捷入口',
                        query.isEmpty ? 'EXPLORE' : '${features.length} 项匹配',
                      ),
                      const SizedBox(height: 14),
                      if (features.isEmpty)
                        _hintCard('没有匹配的功能入口', '试试搜索其他名称或关键词。')
                      else
                        _featureGrid(features),
                      const SizedBox(height: 34),
                      _sectionHeading(
                        'QQ 账号',
                        !_hasLoadedAccounts
                            ? (_busy ? '加载中' : '未获取')
                            : isFiltering
                                ? '${accounts.length} / ${_accounts.length}'
                                : '${_accounts.length} 个账号',
                      ),
                      const SizedBox(height: 14),
                    ]),
                  ),
                ),
                if (!_hasLoadedAccounts && _busy)
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: side),
                    sliver: SliverToBoxAdapter(
                      child: _hintCard('正在读取 QQ 账号', '请稍候…'),
                    ),
                  )
                else if (_accounts.isEmpty)
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: side),
                    sliver: SliverToBoxAdapter(child: _emptyAccounts()),
                  )
                else if (accounts.isEmpty)
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: side),
                    sliver: SliverToBoxAdapter(
                      child: _hintCard(
                        '没有匹配的 QQ 账号',
                        '试试其他关键词或切换账号状态。',
                        action: TextButton(
                          onPressed: _clearSearchAndFilter,
                          child: const Text('清除搜索和筛选'),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: side),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _accountCard(accounts[index]),
                        ),
                        childCount: accounts.length,
                      ),
                    ),
                  ),
                SliverToBoxAdapter(child: SizedBox(height: bottomPadding)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _header() => LayoutBuilder(
        builder: (context, constraints) {
          final fontSize = constraints.maxWidth < 370 ? 38.0 : 46.0;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'YOUR WORKSPACE',
                style: TextStyle(
                  color: _muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '你好，\nSnowLuma.',
                style: TextStyle(
                  color: _ink,
                  fontSize: fontSize,
                  height: 1.05,
                  letterSpacing: -1.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '让账号与机器人，一目了然。',
                style: TextStyle(color: _muted, fontSize: 14, height: 1.45),
              ),
            ],
          );
        },
      );

  Widget _searchBar() {
    final activeFilter = _accountFilter != _AccountFilter.all;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: _softShadows,
            ),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => FocusScope.of(context).unfocus(),
              style: const TextStyle(color: _ink, fontSize: 14),
              decoration: InputDecoration(
                hintText: '搜索功能、昵称或 QQ 号',
                hintStyle: const TextStyle(color: Color(0xFF9298A3)),
                prefixIcon: const Icon(Icons.search_rounded, color: _muted),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '清除搜索',
                        onPressed: _searchController.clear,
                        icon: const Icon(Icons.close_rounded, size: 19),
                      ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 18),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: _ink,
            shape: BoxShape.circle,
            boxShadow: _softShadows,
          ),
          child: PopupMenuButton<_AccountFilter>(
            tooltip: activeFilter ? '账号筛选（已启用）' : '筛选账号状态',
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            offset: const Offset(0, 58),
            initialValue: _accountFilter,
            onSelected: (value) => setState(() => _accountFilter = value),
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.tune_rounded, color: Colors.white),
                if (activeFilter)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF9FAAFF),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            itemBuilder: (_) => [
              _filterItem(_AccountFilter.all, '全部账号'),
              _filterItem(_AccountFilter.online, '仅在线账号'),
              _filterItem(_AccountFilter.offline, '仅离线账号'),
            ],
          ),
        ),
      ],
    );
  }

  PopupMenuItem<_AccountFilter> _filterItem(_AccountFilter value, String label) =>
      PopupMenuItem(
        value: value,
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: value == _accountFilter
                  ? const Icon(Icons.check_rounded, size: 18, color: _indigo)
                  : null,
            ),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
      );

  Widget _statusCard() {
    final running = _status?['status'] == 'running';
    final statusLabel = _status == null && _busy
        ? '正在读取服务状态'
        : running
            ? '服务运行中'
            : '服务未就绪';
    final version = _coreVersion?['version']?.toString();
    final platform = _coreVersion?['platform']?.toString();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _ink,
        borderRadius: BorderRadius.circular(_cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.14),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 38,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: running ? const Color(0xFF4ADE80) : const Color(0xFF8C929C),
                  shape: BoxShape.circle,
                  boxShadow: running
                      ? [
                          BoxShadow(
                            color: const Color(0xFF4ADE80).withOpacity(0.5),
                            blurRadius: 10,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  statusLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'SYSTEM',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.48),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            appState.serverLabel,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.62),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Container(height: 1, color: Colors.white.withOpacity(0.10)),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final count = constraints.maxWidth < 360 ? 2 : 3;
              final cellWidth = (constraints.maxWidth - (count - 1) * 16) / count;
              return Wrap(
                spacing: 16,
                runSpacing: 18,
                children: [
                  SizedBox(
                    width: cellWidth,
                    child: _statusMetric(
                      'QQ 账号',
                      _hasLoadedAccounts ? '${_accounts.length}' : '—',
                    ),
                  ),
                  SizedBox(
                    width: cellWidth,
                    child: _statusMetric(
                      'Rust Core',
                      version == null || version.isEmpty ? '—' : 'v$version',
                    ),
                  ),
                  SizedBox(
                    width: cellWidth,
                    child: _statusMetric(
                      '平台',
                      platform == null || platform.isEmpty ? '—' : platform,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _statusMetric(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      );

  Widget _errorNotice(String error) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4F2),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, size: 19, color: Color(0xFFBE5147)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                error,
                style: const TextStyle(
                  color: Color(0xFF8E413A),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _sectionHeading(String title, String detail) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: _ink,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              detail,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: _muted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      );

  Widget _featureGrid(List<_Feature> features) => LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 900
              ? 3
              : constraints.maxWidth >= 560
                  ? 2
                  : 1;
          const gap = 14.0;
          final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final feature in features)
                SizedBox(
                  width: width,
                  child: _enter(
                    _FeatureCard(
                      feature: feature,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => feature.page),
                      ),
                    ),
                    3 + feature.index,
                  ),
                ),
            ],
          );
        },
      );

  Widget _hintCard(String title, String description, {Widget? action}) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_cardRadius),
          boxShadow: _softShadows,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: _ink,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(description, style: const TextStyle(color: _muted, height: 1.4)),
            if (action != null) ...[const SizedBox(height: 6), action],
          ],
        ),
      );

  Widget _emptyAccounts() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_cardRadius),
          boxShadow: _softShadows,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F2F7),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(Icons.perm_contact_calendar_outlined, color: _indigo),
            ),
            const SizedBox(height: 16),
            Text(
              _hasLoadedAccounts ? '暂无 QQ 账号' : 'QQ 账号尚未获取',
              style: const TextStyle(
                color: _ink,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              _hasLoadedAccounts
                  ? '在服务器运行 QQ 或使用 SnowLuma Docker 部署后接入'
                  : '请检查连接并刷新，或前往进程 / 账号管理。',
              style: const TextStyle(color: _muted, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: _indigo),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const VncPage()),
                  ),
                  icon: const Icon(Icons.qr_code_scanner, size: 18),
                  label: const Text('扫码登录 QQ'),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProcessesPage()),
                  ),
                  icon: const Icon(Icons.dns_outlined, size: 18),
                  label: const Text('进程 / 账号管理'),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AiSettingsPage()),
                  ),
                  icon: const Icon(Icons.smart_toy_outlined, size: 18),
                  label: const Text('AI 助手设置'),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _accountCard(Map<String, dynamic> account) {
    final uin = (account['account_id'] as int?) ?? 0;
    final name = (account['nickname'] as String?) ?? '';
    final online = _isOnline(account);
    final avatar = (account['avatar'] as String?) ?? '';
    final accountStatus = (account['status'] as String?) ?? '';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: _softShadows,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Stack(
          children: [
            ClipOval(
              child: SizedBox(
                width: 46,
                height: 46,
                child: Image.network(
                  avatar.isNotEmpty
                      ? avatar
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
                        color: online ? Colors.green : Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: online ? const Color(0xFF34C759) : Colors.grey.shade400,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
        ),
        title: Text(
          name.isNotEmpty ? '$name（$uin）' : 'QQ $uin',
          style: const TextStyle(
            color: _ink,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        subtitle: Text(
          online ? '在线' : (accountStatus.isNotEmpty ? accountStatus : '离线'),
          style: TextStyle(
            color: online ? const Color(0xFF299950) : _muted,
            fontSize: 12,
          ),
        ),
        trailing: IconButton(
          tooltip: '发送消息给 QQ $uin',
          onPressed: () => _msgDialog(uin),
          icon: const Icon(Icons.send_rounded, color: _indigo),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatefulWidget {
  const _FeatureCard({required this.feature, required this.onTap});

  final _Feature feature;
  final VoidCallback onTap;

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final reduceMotion = media.disableAnimations || media.accessibleNavigation;
    final feature = widget.feature;
    return AnimatedScale(
      scale: _pressed && !reduceMotion ? 0.985 : 1,
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_cardRadius),
          boxShadow: _softShadows,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(_cardRadius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: (pressed) {
              if (mounted && _pressed != pressed) {
                setState(() => _pressed = pressed);
              }
            },
            borderRadius: BorderRadius.circular(_cardRadius),
            splashColor: _indigo.withOpacity(0.08),
            highlightColor: _indigo.withOpacity(0.04),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F2F9),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(feature.icon, color: _indigo, size: 24),
                      ),
                      const Spacer(),
                      Text(
                        '0${feature.index + 1}',
                        style: const TextStyle(
                          color: Color(0xFFACB1BB),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    feature.title,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    feature.description,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F5F8),
                      // 外层 26 减去内边距 20；内部适当加大以保留柔和感。
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            feature.tag,
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.9,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '进入',
                          style: TextStyle(
                            color: _indigo,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Icon(Icons.arrow_forward_rounded, size: 17, color: _indigo),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageDialog extends StatefulWidget {
  const _MessageDialog({required this.uin});

  final int uin;

  @override
  State<_MessageDialog> createState() => _MessageDialogState();
}

class _MessageDialogState extends State<_MessageDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('发消息给 QQ ${widget.uin}'),
        content: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '消息内容'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _controller.text.trim()),
            child: const Text('发送'),
          ),
        ],
      );
}
