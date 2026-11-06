import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/qqbot_client.dart';
import '../../core/ui_anim.dart';
import 'q_ui.dart';

/// QQBot 插件市场 — 浏览市场可用插件，一键安装（走子进程自检后热加载）
///
/// 数据：GET /api/plugins/market/list
///       POST /api/plugins/market/install {name}
class QqbotMarketPage extends StatefulWidget {
  const QqbotMarketPage({super.key});

  @override
  State<QqbotMarketPage> createState() => _QqbotMarketPageState();
}

enum _MarketFilter { all, installed, uninstalled }

class _QqbotMarketPageState extends State<QqbotMarketPage> {
  QqbotClient get _api => QqbotClient.fromSnowLuma(appState.baseUrl);

  bool _loading = true;
  String? _err;
  List<Map<String, dynamic>> _items = const [];
  final Map<String, bool> _busy = {};
  String _q = '';
  _MarketFilter _filter = _MarketFilter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _items.isEmpty;
      _err = null;
    });
    try {
      final r = await _api.marketList();
      if (!mounted) return;
      setState(() {
        _items = ((r['items'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _err = e.toString();
      });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _q.trim().toLowerCase();
    return _items.where((it) {
      final name = '${it['name'] ?? ''}'.toLowerCase();
      final display = '${it['display'] ?? ''}'.toLowerCase();
      final desc = '${it['description'] ?? ''}'.toLowerCase();
      final hit = q.isEmpty ||
          name.contains(q) ||
          display.contains(q) ||
          desc.contains(q);
      final installed = it['installed'] == true;
      final okFilter = _filter == _MarketFilter.all ||
          (_filter == _MarketFilter.installed && installed) ||
          (_filter == _MarketFilter.uninstalled && !installed);
      return hit && okFilter;
    }).toList();
  }

  Future<void> _install(Map<String, dynamic> it) async {
    final name = '${it['name'] ?? ''}';
    final display = '${it['display'] ?? name}';
    if (it['installed'] == true) {
      qSnack(context, '$display 已安装');
      return;
    }
    final ok = await showQConfirm(
      context,
      title: '安装插件',
      content: '确定从市场安装「$display」？\n'
          '系统会在独立子进程里自检，全部通过才会加载。',
      confirmText: '安装',
    );
    if (ok != true) return;
    setState(() => _busy[name] = true);
    try {
      final r = await _api.marketInstall(name);
      if (!mounted) return;
      if (r['ok'] == true) {
        qSnack(context, '「$display」安装成功');
        await _load();
      } else {
        final err = QqbotClient.errText(r);
        qSnack(context, '安装失败：$err');
      }
    } catch (e) {
      if (mounted) qSnack(context, '安装异常：$e');
    } finally {
      if (mounted) setState(() => _busy.remove(name));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('插件市场'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Builder(builder: (context) {
        if (_loading) return const QLoading(text: '读取市场…');
        if (_err != null) return QError(message: _err!, onRetry: _load);
        final shown = _filtered;
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 120),
            children: [
              TextField(
                onChanged: (v) => setState(() => _q = v),
                style: const TextStyle(fontSize: 12.5),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: '搜索插件名 / 说明',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _chip(_MarketFilter.all, '全部'),
                  _chip(_MarketFilter.installed, '已安装'),
                  _chip(_MarketFilter.uninstalled, '未安装'),
                ],
              ),
              const SizedBox(height: 4),
              SectionLabel('市场插件（${shown.length}）'),
              if (shown.isEmpty) const QEmpty(text: '没有匹配的插件'),
              ...shown.map((it) => _marketTile(it)),
            ],
          ),
        );
      }),
    );
  }

  Widget _chip(_MarketFilter f, String label) {
    final active = _filter == f;
    return ChoiceChip(
      label: Text(label),
      selected: active,
      onSelected: (_) => setState(() => _filter = f),
      labelStyle: TextStyle(fontSize: 12, color: active ? Colors.white : Colors.grey.shade700),
      selectedColor: const Color(0xFF007AFF),
      backgroundColor: Colors.white,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _marketTile(Map<String, dynamic> it) {
    final name = '${it['name'] ?? ''}';
    final display = '${it['display'] ?? name}';
    final installed = it['installed'] == true;
    final disabled = it['disabled'] == true;
    final busy = _busy[name] == true;
    final sizeKb = ((it['size'] as num?) ?? 0) / 1024;
    return QCard(
      padding: const EdgeInsets.fromLTRB(13, 12, 10, 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (installed ? const Color(0xFF34C759) : const Color(0xFF007AFF))
                  .withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              installed ? Icons.check_circle_outline : Icons.download_rounded,
              size: 19,
              color: installed ? const Color(0xFF34C759) : const Color(0xFF007AFF),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(display,
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 6),
                    Text('v${it['version'] ?? '-'}',
                        style: TextStyle(
                            fontSize: 10.5, color: Colors.grey.shade500)),
                  ],
                ),
                const SizedBox(height: 2),
                Text('${it['description'] ?? ''}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
                const SizedBox(height: 3),
                Text('${sizeKb.toStringAsFixed(1)} KB · '
                    '${installed ? (disabled ? '已停用' : '已安装') : '未安装'}',
                    style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          FilledButton(
            onPressed: busy || installed ? null : () => _install(it),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 34),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              visualDensity: VisualDensity.compact,
            ),
            child: busy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(installed ? '已安装' : '安装',
                    style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}