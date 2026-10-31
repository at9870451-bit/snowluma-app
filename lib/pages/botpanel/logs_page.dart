import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/qqbot_client.dart';
import 'q_ui.dart';

/// QQBot 运行日志 — 实时查看 QQBot 日志，支持级别过滤
class QqbotLogsPage extends StatefulWidget {
  const QqbotLogsPage({super.key});

  @override
  State<QqbotLogsPage> createState() => _QqbotLogsPageState();
}

enum _Lv { all, error, warn }

class _QqbotLogsPageState extends State<QqbotLogsPage> {
  QqbotClient get _api => QqbotClient.fromSnowLuma(appState.baseUrl);

  bool _loading = true;
  bool _refreshing = false;
  String? _err;
  List<LogLine> _lines = const [];
  int _limit = 300;
  _Lv _lv = _Lv.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _lines.isEmpty;
      _refreshing = true;
      _err = null;
    });
    try {
      final raw = await _api.logs(limit: _limit);
      if (!mounted) return;
      setState(() {
        _lines = raw.map(LogLine.new).toList();
        _loading = false;
        _refreshing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
        _err = e.toString();
      });
    }
  }

  List<LogLine> get _visible {
    return _lines.reversed.where((l) {
      switch (_lv) {
        case _Lv.error:
          return l.isError;
        case _Lv.warn:
          return l.isError || l.isWarn;
        case _Lv.all:
          return true;
      }
    }).toList();
  }

  Color _lvColor(LogLine l) {
    if (l.isError) return const Color(0xFFFF3B30);
    if (l.isWarn) return const Color(0xFFFF9500);
    if (l.level == 'DEBUG') return const Color(0xFF5856D6);
    return const Color(0xFF34C759);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('运行日志'),
        actions: [
          PopupMenuButton<_Lv>(
            initialValue: _lv,
            onSelected: (v) => setState(() => _lv = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: _Lv.all, child: Text('全部级别')),
              PopupMenuItem(value: _Lv.warn, child: Text('警告及以上')),
              PopupMenuItem(value: _Lv.error, child: Text('仅错误')),
            ],
          ),
          IconButton(
            tooltip: '刷新',
            onPressed: _refreshing ? null : _load,
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
        if (_loading) return const QLoading(text: '正在读取日志…');
        if (_err != null) return QError(message: _err!, onRetry: _load);
        final visible = _visible;
        if (visible.isEmpty) {
          return const QEmpty(
              text: '没有符合条件的日志', icon: Icons.event_note_outlined);
        }
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 120),
            itemCount: visible.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '共 ${visible.length} 条（服务器保留最近 ${_limit} 行），下拉刷新',
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                );
              }
              final l = visible[i - 1];
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            l.parsed ? '${l.time} · ${l.logger}' : l.time,
                            style: TextStyle(
                                fontSize: 10.5,
                                fontFamily: 'Menlo',
                                color: Colors.grey.shade500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (l.parsed)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: _lvColor(l).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(l.level,
                                style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: _lvColor(l))),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l.parsed ? l.message : l.raw,
                      style: const TextStyle(fontSize: 12, height: 1.35),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      }),
    );
  }
}