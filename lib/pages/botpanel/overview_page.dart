import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/qqbot_client.dart';
import 'q_ui.dart';

/// QQBot 总览 — 运行状态 / 插件概览 / 关键统计 / 最近日志
///
/// 数据：GET /api/status + /api/logs?limit=N + /api/kb/overview + /api/memory/overview
class QqbotOverviewPage extends StatefulWidget {
  const QqbotOverviewPage({super.key});

  @override
  State<QqbotOverviewPage> createState() => _QqbotOverviewPageState();
}

class _QqbotOverviewPageState extends State<QqbotOverviewPage> {
  QqbotClient get _api => QqbotClient.fromSnowLuma(appState.baseUrl);

  bool _loading = true;
  bool _refreshing = false;
  String? _err;
  Map<String, dynamic> _status = const {};
  List<LogLine> _logs = const [];
  Map<String, dynamic> _kbStats = const {};
  Map<String, dynamic> _memStats = const {};
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _load();
    // 每 10 秒静默刷新一次（状态灯保持鲜活）
    _ticker = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _load(silent: true);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = _loading && _status.isEmpty;
        _refreshing = true;
        _err = null;
      });
    }
    try {
      final api = _api;
      final results = await Future.wait([
        api.status(),
        api.logs(limit: 40),
        api.kbOverview().catchError((_) => <String, dynamic>{}),
        api.memoryOverview().catchError((_) => <String, dynamic>{}),
      ]);
      if (!mounted) return;
      setState(() {
        _status = results[0] as Map<String, dynamic>;
        _logs = (results[1] as List<String>).map(LogLine.new).toList();
        _kbStats =
            ((results[2] as Map)['stats'] as Map?)?.cast<String, dynamic>() ??
                const {};
        _memStats =
            ((results[3] as Map)['stats'] as Map?)?.cast<String, dynamic>() ??
                const {};
        _loading = false;
        _refreshing = false;
        _err = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
        if (_status.isEmpty) _err = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QQBot 总览'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _refreshing ? null : () => _load(),
            icon: _refreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Builder(builder: (context) {
        if (_loading) return const QLoading(text: '正在连接 QQBot…');
        if (_err != null) return QError(message: _err!, onRetry: _load);
        return RefreshIndicator(
          onRefresh: () => _load(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 120),
            children: [
              _statusCard(),
              _statCard(),
              _pluginCard(),
              _recentLogCard(),
            ],
          ),
        );
      }),
    );
  }

  Widget _statusCard() {
    final running = _status['running'] == true;
    final connected = _status['connected'] == true;
    final ok = running && connected;
    final uptime = (_status['uptime'] as num?) ?? 0;
    final selfId = _status['self_id'];
    return QCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (ok ? const Color(0xFF34C759) : const Color(0xFFFF9500))
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  ok ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                  color: ok ? const Color(0xFF34C759) : const Color(0xFFFF9500),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ok
                          ? '运行中 · 已连接 QQ'
                          : (running ? '运行中 · QQ 未连接' : '未运行'),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (selfId != null && '$selfId' != '0') 'QQ ${selfId}',
                        '版本 ${_status['version'] ?? '-'}',
                        if (_status['backend'] != null) '${_status['backend']}',
                      ].join(' · '),
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer_outlined, size: 16, color: kIosBlue),
                const SizedBox(width: 8),
                Text('已运行 ${fmtDuration(uptime)}',
                    style: const TextStyle(fontSize: 13)),
                const Spacer(),
                Text('每 10 秒自动刷新',
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard() {
    final pluginCount = ((_status['plugins'] as List?) ?? const []).length;
    final kbDocs = (_kbStats['docs'] as num?) ?? 0;
    final kbTerms = (_kbStats['terms'] as num?) ?? 0;
    final memTotal = (_memStats['total'] as num?) ?? 0;
    final memEnabled = (_memStats['enabled'] as num?) ?? 0;
    return QCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatRow(items: [
            StatTile(value: '$pluginCount', label: '插件'),
            StatTile(value: '$memTotal', label: '记忆（启用 $memEnabled）'),
            StatTile(value: '$kbDocs', label: '知识库文档'),
          ]),
          const SizedBox(height: 12),
          Divider(height: 1, color: Colors.grey.shade200),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.menu_book_outlined,
                  size: 15, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              Text('知识条目 $kbTerms 条 · 记忆按群/用户自动隔离',
                  style:
                      TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pluginCard() {
    final plugins = ((_status['plugins'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
    if (plugins.isEmpty) return const SizedBox.shrink();
    final shown = plugins.take(8).toList();
    return QCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('已加载插件',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${plugins.length} 个',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
          const SizedBox(height: 10),
          for (final p in shown)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                        color: Color(0xFF34C759), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      (p['display_name'] ?? p['name'] ?? '').toString(),
                      style: const TextStyle(fontSize: 13.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (p['source'] == 'external'
                              ? const Color(0xFFAF52DE)
                              : Colors.grey)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      '${p['source'] == 'external' ? '外部' : '内置'} v${p['version'] ?? ''}',
                      style: TextStyle(
                          fontSize: 10,
                          color: p['source'] == 'external'
                              ? const Color(0xFFAF52DE)
                              : Colors.grey.shade600),
                    ),
                  ),
                ],
              ),
            ),
          if (plugins.length > shown.length)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('还有 ${plugins.length - shown.length} 个插件，去「插件管理」查看',
                  style:
                      TextStyle(fontSize: 11.5, color: Colors.grey.shade500)),
            ),
        ],
      ),
    );
  }

  Widget _recentLogCard() {
    if (_logs.isEmpty) return const SizedBox.shrink();
    final recent = _logs.reversed.take(8).toList();
    return QCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('最近日志',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          for (final l in recent)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.time,
                      style: TextStyle(
                          fontSize: 10.5,
                          fontFamily: 'Menlo',
                          color: Colors.grey.shade500)),
                  const SizedBox(width: 6),
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: l.isError
                          ? const Color(0xFFFF3B30)
                          : l.isWarn
                              ? const Color(0xFFFF9500)
                              : const Color(0xFF34C759),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      l.parsed ? l.message : l.raw,
                      style: TextStyle(
                          fontSize: 11.5, color: Colors.grey.shade800),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}