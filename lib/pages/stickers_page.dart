import 'package:flutter/material.dart';

import '../core/app_state.dart';

/// AI 收藏的表情包页 — 网格展示 QQBot 自动收藏的表情包库。
/// 数据：GET /ai/sticker-collect（列表）+ /ai/sticker-image?file=xx（图片直读）。
class StickersPage extends StatefulWidget {
  const StickersPage({super.key});

  @override
  State<StickersPage> createState() => _StickersPageState();
}

class _StickersPageState extends State<StickersPage> {
  bool _loading = true;
  String? _err;
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final api = appState.client;
      if (api == null) {
        if (mounted) {
          setState(() {
            _loading = false;
            _err = '尚未连接服务器';
          });
        }
        return;
      }
      final r = await api.stickerCollect();
      if (!mounted) return;
      setState(() {
        _items = (r['items'] as List? ?? const []).cast<Map<String, dynamic>>();
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

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 收藏的表情包'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: _loading
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(context, text),
    );
  }

  Widget _buildBody(BuildContext context, TextTheme text) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_err != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 40, color: Colors.grey),
            const SizedBox(height: 12),
            Text('加载失败', style: text.titleMedium),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(_err!, style: text.bodySmall, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('重试')),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 统计条
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: const Color(0xFF007AFF).withValues(alpha: 0.06),
          child: Text(
            'AI 已自动收藏 $_items 张表情包（看到就收，回复时只发这些）',
            style: text.bodyMedium?.copyWith(color: const Color(0xFF007AFF)),
          ),
        ),
        Expanded(
          child: _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.emoji_emotions_outlined,
                          size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text('还没有收藏', style: text.titleMedium),
                      const SizedBox(height: 6),
                      Text('群里有人发表情包后，AI 会自动收藏到这里',
                          style: text.bodySmall?.copyWith(color: Colors.grey)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: _items.length,
                    itemBuilder: (context, i) {
                      final item = _items[i];
                      final file = (item['file'] ?? '').toString();
                      final name = (item['name'] ?? '').toString();
                      return _stickerCell(file, name, text);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _stickerCell(String file, String name, TextTheme text) {
    final url = appState.client?.stickerImageUrl(file) ?? '';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(6),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                url,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : const Center(
                        child: SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))),
                errorBuilder: (context, e, s) => Container(
                  color: Colors.grey.shade100,
                  child: const Icon(Icons.broken_image_outlined,
                      color: Colors.grey),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            name.isEmpty ? '收藏' : name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall?.copyWith(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}