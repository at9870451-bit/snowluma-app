import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/qqbot_client.dart';
import 'q_ui.dart';

/// QQBot 插件管理 — 已加载/已停用插件列表，开关与重载
///
/// 数据：GET /api/plugins · GET /api/plugins/<name>/detail
///       POST /api/plugins/<name>/toggle {enabled} · POST /api/plugins/<name>/reload
class QqbotPluginsPage extends StatefulWidget {
  const QqbotPluginsPage({super.key});

  @override
  State<QqbotPluginsPage> createState() => _QqbotPluginsPageState();
}

class _QqbotPluginsPageState extends State<QqbotPluginsPage> {
  QqbotClient get _api => QqbotClient.fromSnowLuma(appState.baseUrl);

  bool _loading = true;
  String? _err;
  List<Map<String, dynamic>> _loaded = const [];
  List<Map<String, dynamic>> _disabled = const [];
  final Map<String, bool> _busy = {};
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _loaded.isEmpty && _disabled.isEmpty;
      _err = null;
    });
    try {
      final r = await _api.plugins();
      if (!mounted) return;
      setState(() {
        _loaded = _map((r['loaded'] as List?) ?? const []);
        _disabled = _map((r['disabled'] as List?) ?? const []);
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

  List<Map<String, dynamic>> _map(List raw) => raw
      .whereType<Map>()
      .map((e) => e.cast<String, dynamic>())
      .toList();

  Future<void> _toggle(Map<String, dynamic> p, bool enabled) async {
    final name = '${p['name']}';
    final isExternal = p['source'] == 'external';
    if (isExternal || !enabled) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(enabled ? '启用插件？' : '停用插件？'),
          content: Text(
              '${p['display_name'] ?? name}\n\n'
              '${enabled ? '启用后该插件开始工作。' : '停用后该功能立即失效，AI 将不再执行这块能力。'}'
              '${isExternal ? '\n\n这是外部插件，改动会影响线上行为。' : ''}',
              style: const TextStyle(fontSize: 13)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(enabled ? '启用' : '停用',
                    style: TextStyle(
                        color: enabled
                            ? kIosBlue
                            : const Color(0xFFFF3B30)))),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => _busy[name] = true);
    try {
      final r = await _api.pluginToggle(name, enabled);
      if (!mounted) return;
      if (r['ok'] == true) {
        qSnack(context, enabled
            ? '已启用 ${p['display_name'] ?? name}'
            : '已停用 ${p['display_name'] ?? name}');
        await _load();
      } else {
        qSnack(context, QqbotClient.errText(r));
      }
    } catch (e) {
      if (mounted) qSnack(context, '操作失败：$e');
    } finally {
      if (mounted) setState(() => _busy.remove(name));
    }
  }

  Future<void> _reload(Map<String, dynamic> p) async {
    final name = '${p['name']}';
    setState(() => _busy[name] = true);
    try {
      final r = await _api.pluginReload(name);
      if (!mounted) return;
      qSnack(context, r['ok'] == true
          ? '已重载 ${p['display_name'] ?? name}'
          : '重载失败：${QqbotClient.errText(r)}');
      await _load();
    } catch (e) {
      if (mounted) qSnack(context, '重载失败：$e');
    } finally {
      if (mounted) setState(() => _busy.remove(name));
    }
  }

  Future<void> _detail(Map<String, dynamic> p) async {
    showDialog(
      context: context,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );
    Map<String, dynamic>? detail;
    String? err;
    try {
      final r = await _api.pluginDetail('${p['name']}');
      detail = (r['detail'] as Map?)?.cast<String, dynamic>();
      if (detail == null) err = QqbotClient.errText(r);
    } catch (e) {
      err = e.toString();
    }
    if (!mounted) return;
    Navigator.pop(context);
    if (err != null) {
      qSnack(context, '读取详情失败：$err');
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final commands = ((detail!['commands'] as List?) ?? const [])
            .whereType<Map>()
            .toList();
        final schema =
            (detail['config_schema'] as Map?)?.cast<String, dynamic>() ?? {};
        final labels =
            (detail['config_labels'] as Map?)?.cast<String, dynamic>() ?? {};
        final cfg = (detail['config'] as Map?)?.cast<String, dynamic>() ?? {};
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (_, ctrl) => ListView(
            controller: ctrl,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
            children: [
              Text('${detail!['display_name'] ?? detail['name']}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                '${detail['name']} · v${detail['version']} · '
                '${detail['source'] == 'external' ? '外部插件' : '内置插件'} · 优先级 ${detail['priority']}',
                style:
                    TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              if ('${detail['description'] ?? ''}'.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('${detail['description']}',
                    style: const TextStyle(fontSize: 13, height: 1.45)),
              ],
              if (commands.isNotEmpty) ...[
                const SectionLabel('指令'),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final c in commands)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: kIosBlue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('/${c['name']}',
                            style: const TextStyle(
                                fontSize: 12,
                                fontFamily: 'Menlo',
                                color: kIosBlue)),
                      ),
                  ],
                ),
              ],
              if (schema.isNotEmpty) ...[
                const SectionLabel('配置项'),
                for (final k in schema.keys)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text('${labels[k] ?? k}',
                              style: const TextStyle(fontSize: 13)),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            '${cfg.containsKey(k) ? cfg[k] : schema[k]}',
                            style: TextStyle(
                                fontSize: 12,
                                fontFamily: 'Menlo',
                                color: Colors.grey.shade700),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 16),
              Text('${detail['path'] ?? ''}',
                  style: TextStyle(
                      fontSize: 10.5,
                      fontFamily: 'Menlo',
                      color: Colors.grey.shade400)),
            ],
          ),
        );
      },
    );
  }

  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> list) {
    final kw = _q.trim().toLowerCase();
    if (kw.isEmpty) return list;
    return list
        .where((p) =>
            '${p['name']}'.toLowerCase().contains(kw) ||
            '${p['display_name'] ?? ''}'.toLowerCase().contains(kw) ||
            '${p['description'] ?? ''}'.toLowerCase().contains(kw))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('插件管理'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Builder(builder: (context) {
        if (_loading) return const QLoading(text: '读取插件…');
        if (_err != null) return QError(message: _err!, onRetry: _load);
        final loaded = _filter(_loaded);
        final disabled = _filter(_disabled);
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 120),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 8, 2, 10),
                child: TextField(
                  onChanged: (v) => setState(() => _q = v),
                  style: const TextStyle(fontSize: 12.5),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '搜索插件名 / 说明',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9)),
                  ),
                ),
              ),
              SectionLabel('已加载（${loaded.length}）'),
              if (loaded.isEmpty) const QEmpty(text: '没有匹配的插件'),
              ...loaded.map((p) => _pluginTile(p, true)),
              if (disabled.isNotEmpty) ...[
                SectionLabel('已停用（${disabled.length}）'),
                ...disabled.map((p) => _pluginTile(p, false)),
              ],
            ],
          ),
        );
      }),
    );
  }

  Widget _pluginTile(Map<String, dynamic> p, bool enabled) {
    final name = '${p['name']}';
    final busy = _busy[name] == true;
    final external = p['source'] == 'external';
    return GestureDetector(
      onTap: () => _detail(p),
      child: QCard(
        padding: const EdgeInsets.fromLTRB(13, 11, 8, 11),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: (enabled ? const Color(0xFF34C759) : Colors.grey)
                    .withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                enabled
                    ? Icons.extension_rounded
                    : Icons.extension_off_outlined,
                size: 18,
                color: enabled ? const Color(0xFF34C759) : Colors.grey,
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
                        child: Text(
                          '${p['display_name'] ?? name}',
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 5),
                      if (external)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFAF52DE)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('外部',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: Color(0xFFAF52DE))),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'v${p['version'] ?? ''} · 优先级 ${p['priority'] ?? '-'}'.trim(),
                    style:
                        TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            if (busy)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else ...[
              IconButton(
                tooltip: '重载',
                visualDensity: VisualDensity.compact,
                onPressed: () => _reload(p),
                icon: Icon(Icons.autorenew,
                    size: 18, color: Colors.grey.shade500),
              ),
              Switch.adaptive(
                value: enabled,
                onChanged: (v) => _toggle(p, v),
              ),
            ],
          ],
        ),
      ),
    );
  }
}