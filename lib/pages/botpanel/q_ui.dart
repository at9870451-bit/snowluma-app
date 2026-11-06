import 'package:flutter/material.dart';

import '../../core/snow_theme.dart';

/// QQBot 管理页共享组件；保持现有页面与数据接口不变。
const kIosBlue = SnowStyle.accent;

/// 白色卡片：同心圆角及柔和的多层阴影。
class QCard extends StatelessWidget {
  const QCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: SnowStyle.card(),
      child: child,
    );
  }
}

/// 统计数字块（大数字 + 小标签）
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.color = kIosBlue,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                fontFeatures: SnowStyle.tabular,
                color: color)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
      ],
    );
  }
}

/// 一组统计横排
class StatRow extends StatelessWidget {
  const StatRow({super.key, required this.items});

  final List<StatTile> items;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0)
            Container(
                width: 1,
                height: 30,
                color: Colors.grey.shade200,
                margin: const EdgeInsets.symmetric(horizontal: 12)),
          Expanded(child: items[i]),
        ],
      ],
    );
  }
}

/// 章节标题
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
      child: Row(
        children: [
          Text(text,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700)),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// 加载中
class QLoading extends StatelessWidget {
  const QLoading({super.key, this.text});

  final String? text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(strokeWidth: 2.4),
          if (text != null) ...[
            const SizedBox(height: 12),
            Text(text!, style: TextStyle(color: Colors.grey.shade600)),
          ],
        ],
      ),
    );
  }
}

/// 错误 + 重试
class QError extends StatelessWidget {
  const QError({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 40, color: Colors.grey),
          const SizedBox(height: 12),
          const Text('加载失败'),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ),
          const SizedBox(height: 14),
          FilledButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}

/// 空状态
class QEmpty extends StatelessWidget {
  const QEmpty(
      {super.key, required this.text, this.icon = Icons.inbox_rounded});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 38, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

/// 底部提示 SnackBar
void qSnack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

/// 以秒转换成「x天x小时」/「x小时x分」/「x分」
String fmtDuration(num seconds) {
  final s = seconds.round();
  if (s <= 0) return '0 分';
  final d = s ~/ 86400;
  final h = (s % 86400) ~/ 3600;
  final m = (s % 3600) ~/ 60;
  if (d > 0) return '$d 天 $h 小时';
  if (h > 0) return '$h 小时 $m 分';
  return '$m 分';
}

/// 时间戳 → MM-dd HH:mm
String fmtTime(num ts) {
  if (ts <= 0) return '';
  final dt = DateTime.fromMillisecondsSinceEpoch((ts * 1000).round());
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
}

// ---------- 日志行解析 ----------

class LogLine {
  LogLine(this.raw) {
    // 形如：18:55:02 [INFO] qqbot.protocol.onebot: 消息
    final m = RegExp(r'^(\d{2}:\d{2}:\d{2})\s*\[(\w+)\]\s*([^:]+):\s*(.*)$')
        .firstMatch(raw);
    if (m != null) {
      time = m.group(1)!;
      level = m.group(2)!.toUpperCase();
      logger = m.group(3)!.trim();
      message = m.group(4)!;
      parsed = true;
    } else {
      message = raw;
    }
  }

  final String raw;
  String time = '';
  String level = 'INFO';
  String logger = '';
  String message = '';
  bool parsed = false;

  bool get isError => level == 'ERROR' || level == 'CRITICAL';
  bool get isWarn => level == 'WARNING' || level == 'WARN';
}