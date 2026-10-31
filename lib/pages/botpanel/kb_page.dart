import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/qqbot_client.dart';
import 'q_ui.dart';

/// QQBot 知识库 — 按群管理知识文档，支持新增/删除/搜索
///
/// 数据：GET /api/kb/overview（群列表 + 统计）
///       GET /api/kb/docs?group_id=  / POST /api/kb/docs  / DELETE /api/kb/docs/<id>
///       POST /api/kb/search {text}
class QqbotKbPage extends StatefulWidget {
  const QqbotKbPage({super.key});

  @override
  State<QqbotKbPage> createState() => _QqbotKbPageState();
}

class _QqbotKbPageState extends State<QqbotKbPage> {
  QqbotClient get _api => QqbotClient.fromSnowLuma(appState.baseUrl);

  bool _loading = true;
  String? _err;
  List<Map<String, dynamic>> _groups = const [];
  Map<String, dynamic> _stats = const {};
  String? _groupId;
  List<Map<String, dynamic>> _docs = const [];
  bool _docsLoading = false;

  List<Map<String, dynamic>> _searchHits = const [];
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _loadOverview();
  }

  Future<void> _loadOverview() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final r = await _api.kbOverview();
      if (!mounted) return;
      final groups = ((r['bot_groups'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      setState(() {
        _groups = groups;
        _stats = (r['stats'] as Map?)?.cast<String, dynamic>() ?? const {};
        _loading = false;
        if (_groupId == null && groups.isNotEmpty) {
          _groupId = '${groups.first['group_id']}';
          _loadDocs();
        }
      });
      if (_groupId != null) await _loadDocs();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _err = e.toString();
      });
    }
  }

  Future<void> _loadDocs() async {
    final gid = int.tryParse(_groupId ?? '');
    if (gid == null) return;
    setState(() {
      _docsLoading = true;
      _searchHits = const [];
    });
    try {
      final docs = await _api.kbDocs(gid);
      if (!mounted) return;
      setState(() {
        _docs = docs;
        _docsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _docsLoading = false;
        _docs = const [];
      });
      qSnack(context, '读取知识库失败：$e');
    }
  }

  String _groupName(String id) {
    for (final g in _groups) {
      if ('${g['group_id']}' == id) return '${g['group_name'] ?? id}';
    }
    return id;
  }

  Future<void> _editDoc({Map<String, dynamic>? doc}) async {
    final gid = int.tryParse(_groupId ?? '');
    if (gid == null) {
      qSnack(context, '请先选择群');
      return;
    }
    final titleC = TextEditingController(text: '${doc?['title'] ?? ''}');
    final tagsC = TextEditingController(text: '${doc?['tags'] ?? ''}');
    final contentC = TextEditingController(text: '${doc?['content'] ?? ''}');
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(doc == null ? '新增知识文档' : '文档详情',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('所属群：${_groupName(_groupId!)}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            TextField(
              controller: titleC,
              enabled: doc == null,
              decoration: const InputDecoration(
                  labelText: '标题（可空）', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: tagsC,
              enabled: doc == null,
              decoration: const InputDecoration(
                  labelText: '标签（逗号分隔，可空）',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: contentC,
              readOnly: doc != null,
              minLines: 5,
              maxLines: 10,
              decoration: const InputDecoration(
                  labelText: '内容',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(doc == null ? '保存到知识库' : '关闭'),
              ),
            ),
          ],
        ),
      ),
    );
    if (ok == true && doc == null) {
      final content = contentC.text.trim();
      if (content.isEmpty) {
        qSnack(context, '内容不能为空');
        return;
      }
      try {
        final r = await _api.kbAddDoc(
          groupId: gid,
          content: content,
          title: titleC.text.trim(),
          tags: tagsC.text.trim(),
        );
        if (!mounted) return;
        if (r['ok'] == true) {
          qSnack(context, '已加入知识库，QQ 回复时会参考');
          await _loadDocs();
          await _loadOverviewStats();
        } else {
          qSnack(context, QqbotClient.errText(r));
        }
      } catch (e) {
        if (mounted) qSnack(context, '保存失败：$e');
      }
    }
  }

  Future<void> _loadOverviewStats() async {
    try {
      final r = await _api.kbOverview();
      if (mounted) {
        setState(() {
          _stats =
              (r['stats'] as Map?)?.cast<String, dynamic>() ?? const {};
        });
      }
    } catch (_) {}
  }

  Future<void> _deleteDoc(Map<String, dynamic> doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这条知识？'),
        content: Text(
            '${doc['title'] != null && '${doc['title']}'.isNotEmpty ? '${doc['title']}\n' : ''}${doc['content'] ?? ''}',
            maxLines: 4,
            overflow: TextOverflow.ellipsis),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('删除', style: TextStyle(color: Color(0xFFFF3B30))),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final r = await _api.kbDeleteDoc((doc['id'] as num).toInt());
      if (!mounted) return;
      if (r['ok'] == true) {
        qSnack(context, '已删除');
        await _loadDocs();
        await _loadOverviewStats();
      } else {
        qSnack(context, QqbotClient.errText(r));
      }
    } catch (e) {
      if (mounted) qSnack(context, '删除失败：$e');
    }
  }

  Future<void> _search(String text) async {
    final q = text.trim();
    if (q.isEmpty) {
      setState(() => _searchHits = const []);
      return;
    }
    try {
      final r =
          await _api.kbSearch(text: q, groupId: int.tryParse(_groupId ?? ''));
      if (!mounted) return;
      setState(() {
        _searchText = q;
        _searchHits = ((r['hits'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
      });
    } catch (_) {
      if (mounted) setState(() => _searchHits = const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('知识库'),
        actions: [
          IconButton(
            tooltip: '新增文档',
            onPressed: _loading ? null : () => _editDoc(),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Builder(builder: (context) {
        if (_loading) return const QLoading(text: '读取知识库…');
        if (_err != null) return QError(message: _err!, onRetry: _loadOverview);
        return Column(
          children: [
            _header(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadDocs,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 120),
                  children: [
                    if (_searchHits.isNotEmpty) ..._searchBlock(),
                    if (_docsLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child:
                            Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    else if (_docs.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 50),
                        child: QEmpty(
                          icon: Icons.menu_book_outlined,
                          text: '这个群还没有知识文档\n点右上角 + 添加，AI 回复时会参考',
                        ),
                      )
                    else
                      ..._docs.map(_docTile),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _header() {
    final docs = (_stats['docs'] as num?) ?? 0;
    final terms = (_stats['terms'] as num?) ?? 0;
    return Container(
      color: const Color(0xFFF7F7FA),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: _groupId,
            isDense: true,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(),
            ),
            style: const TextStyle(fontSize: 13, color: Colors.black87),
            items: [
              for (final g in _groups)
                DropdownMenuItem(
                  value: '${g['group_id']}',
                  child: Text('${g['group_name'] ?? g['group_id']}',
                      overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) {
              setState(() => _groupId = v);
              _loadDocs();
            },
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.search, size: 18, color: Colors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: '搜索知识（空格分词）',
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(fontSize: 13),
                  onSubmitted: _search,
                  textInputAction: TextInputAction.search,
                ),
              ),
              const SizedBox(width: 6),
              Text('全库 $docs 篇 / $terms 词条',
                  style:
                      TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _searchBlock() {
    return [
      SectionLabel('搜索结果（$_searchText，${_searchHits.length} 条）',
          trailing: TextButton(
            onPressed: () => setState(() => _searchHits = const []),
            child: const Text('清除', style: TextStyle(fontSize: 12)),
          )),
      for (final h in _searchHits.take(10))
        QCard(
          padding: const EdgeInsets.all(12),
          child: Text(
            '${h['content'] ?? h['text'] ?? h['snippet'] ?? h}',
            style: const TextStyle(fontSize: 12.5),
          ),
        ),
    ];
  }

  Widget _docTile(Map<String, dynamic> d) {
    final title = '${d['title'] ?? ''}'.trim();
    final tags = '${d['tags'] ?? ''}'.trim();
    return GestureDetector(
      onTap: () => _editDoc(doc: d),
      onLongPress: () => _deleteDoc(d),
      child: QCard(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title.isNotEmpty) ...[
              Text(title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 5),
            ],
            Text(
              '${d['content'] ?? ''}',
              style: const TextStyle(fontSize: 12.5, height: 1.4),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (tags.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: kIosBlue.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(tags,
                        style:
                            const TextStyle(fontSize: 10, color: kIosBlue)),
                  ),
                Text('更新于 ${fmtTime((d['updated_at'] as num?) ?? 0)}',
                    style:
                        TextStyle(fontSize: 10.5, color: Colors.grey.shade500)),
                const Spacer(),
                GestureDetector(
                  onTap: () => _deleteDoc(d),
                  child: Icon(Icons.delete_outline,
                      size: 17, color: Colors.grey.shade400),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}