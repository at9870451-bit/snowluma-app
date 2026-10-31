import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/qqbot_client.dart';
import 'q_ui.dart';

/// QQBot 表情包库 — 查看 AI 收藏/可用的表情包
///
/// 数据：GET /api/stickers → {stickers:[{id,name,tags,size}], stats}
/// 图片：GET /api/stickers/<id>/raw
class QqbotStickersLibPage extends StatefulWidget {
  const QqbotStickersLibPage({super.key});

  @override
  State<QqbotStickersLibPage> createState() => _QqbotStickersLibPageState();
}

class _QqbotStickersLibPageState extends State<QqbotStickersLibPage> {
  QqbotClient get _api => QqbotClient.fromSnowLuma(appState.baseUrl);

  bool _loading = true;
  String? _err;
  List<Map<String, dynamic>> _items = const [];
  Map<String, dynamic> _stats = const {};
  String _tag = '全部';

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
      final r = await _api.stickers();
      if (!mounted) return;
      setState(() {
        _items = ((r['stickers'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
        _stats = (r['stats'] as Map?)?.cast<String, dynamic>() ?? const {};
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_items.isEmpty) _err = e.toString();
      });
    }
  }

  List<String> get _tags {
    final set = <String>{'全部'};
    for (final s in _items) {
      for (final t in ((s['tags'] as List?) ?? const [])) {
        set.add('$t');
      }
    }
    return set.toList();
  }

  List<Map<String, dynamic>> get _visible {
    if (_tag == '全部') return _items;
    return _items
        .where((s) => ((s['tags'] as List?) ?? const []).contains(_tag))
        .toList();
  }

  Future<void> _delete(Map<String, dynamic> s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这个表情包？'),
        content: const Text('AI 将不再发这张图'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('删除',
                  style: TextStyle(color: Color(0xFFFF3B30)))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final r = await _api.stickerDelete('${s['id']}');
      if (!mounted) return;
      if (r['ok'] == true) {
        setState(() =>
            _items = _items.where((e) => e['id'] != s['id']).toList());
        qSnack(context, '已删除');
      } else {
        qSnack(context, QqbotClient.errText(r));
      }
    } catch (e) {
      if (mounted) qSnack(context, '删除失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('表情包库'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Builder(builder: (context) {
        if (_loading) return const QLoading(text: '读取表情包…');
        if (_err != null) return QError(message: _err!, onRetry: _load);
        final visible = _visible;
        return Column(
          children: [
            Container(
              width: double.infinity,
              color: const Color(0xFFF7F7FA),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '共 ${_stats['count'] ?? _items.length} 张 · ${_fmtBytes((_stats['bytes'] as num?) ?? 0)}',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final t in _tags)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(t,
                                  style: const TextStyle(fontSize: 11.5)),
                              selected: _tag == t,
                              visualDensity: VisualDensity.compact,
                              onSelected: (_) => setState(() => _tag = t),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: visible.isEmpty
                    ? ListView(children: const [
                        SizedBox(height: 90),
                        QEmpty(
                            icon: Icons.emoji_emotions_outlined,
                            text: '还没有表情包'),
                      ])
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 120),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 0.84,
                        ),
                        itemCount: visible.length,
                        itemBuilder: (_, i) => _cell(visible[i]),
                      ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _cell(Map<String, dynamic> s) {
    final url = _api.stickerRawUrl('${s['id']}');
    return GestureDetector(
      onLongPress: () => _delete(s),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Expanded(
              child: Image.network(
                url,
                fit: BoxFit.cover,
                width: double.infinity,
                loadingBuilder: (_, child, p) => p == null
                    ? child
                    : const Center(
                        child: SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(strokeWidth: 2))),
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image_outlined,
                      size: 22, color: Colors.grey),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              child: Text(
                _fmtBytes((s['size'] as num?) ?? 0),
                style:
                    TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtBytes(num b) {
    if (b >= 1024 * 1024) return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
    if (b >= 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
    return '${b.toInt()} B';
  }
}