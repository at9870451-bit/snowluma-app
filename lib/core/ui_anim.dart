import 'dart:async';

import 'package:flutter/material.dart';

/// SnowLuma 交互动效工具库（Overlay 实现，全部支持「原路收回」）：
///   showAnchorMenu — 按钮弹出菜单：以按钮为原点展开，点击外部原路收回
///   showZoomPanel  — 卡片弹出详情：从原位放大为居中面板，关闭时缩回
///   showQConfirm   — 确认弹窗：轻微回弹弹出，确认后原地切换完成状态
///   showBubble     — 气泡提示：指向箭头 + 数秒自动收回

Rect _rectOf(BuildContext ctx) {
  final box = ctx.findRenderObject()! as RenderBox;
  return box.localToGlobal(Offset.zero) & box.size;
}

// ================================================================= 1. 锚点菜单

class QMenuItem {
  const QMenuItem(this.label, {this.icon, this.danger = false});
  final String label;
  final IconData? icon;
  final bool danger;
}

/// 以 anchor 组件为原点展开菜单；点屏障/选中后按原动画收回。
/// 返回被选中项的 label（点外部返回 null）。
Future<String?> showAnchorMenu(
  BuildContext context, {
  required BuildContext anchor,
  required List<QMenuItem> items,
  double width = 168,
}) {
  final nav = Navigator.of(context, rootOverlay: true);
  final overlay = Overlay.of(context, rootOverlay: true);
  final rect = _rectOf(anchor);
  final size = MediaQuery.of(context).size;
  final rowH = 44.0;
  final menuH = items.length * rowH + 12;
  final below = rect.bottom + 10 + menuH < size.height - 24;
  final top = below ? rect.bottom + 8 : rect.top - 8 - menuH;
  double left = rect.left.clamp(12.0, size.width - width - 12);
  final alignRight = left + width > rect.right;
  final comp = Completer<String?>();
  late final OverlayEntry entry;
  final ctrl = AnimationController(
      vsync: nav, duration: const Duration(milliseconds: 190));
  final anim = CurvedAnimation(parent: ctrl, curve: Curves.easeOutCubic);
  final origin = below
      ? (alignRight ? Alignment.topLeft : Alignment.topRight)
      : (alignRight ? Alignment.bottomLeft : Alignment.bottomRight);

  void close(T? val) {
    if (comp.isCompleted) return;
    ctrl.reverse().whenComplete(() {
      if (entry.mounted) entry.remove();
      comp.complete(val);
    });
  }

  entry = OverlayEntry((ctx) => Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => close(null),
            child: FadeTransition(
                opacity: anim,
                child: const ColoredBox(color: Colors.black26)),
          ),
        ),
        Positioned(
          left: left,
          top: top.clamp(12.0, size.height - menuH - 24),
          width: width,
          child: ScaleTransition(
            scale: Tween(begin: 0.72, end: 1.0).animate(anim),
            alignment: origin,
            child: FadeTransition(
              opacity: anim,
              child: Material(
                color: Colors.white,
                elevation: 10,
                shadowColor: Colors.black26,
                borderRadius: BorderRadius.circular(14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < items.length; i++)
                      InkWell(
                        borderRadius: BorderRadius.vertical(
                          top: i == 0 ? const Radius.circular(14) : Radius.zero,
                          bottom: i == items.length - 1
                              ? const Radius.circular(14)
                              : Radius.zero,
                        ),
                        onTap: () => close(items[i].label),
                        child: SizedBox(
                          height: rowH,
                          child: Row(children: [
                            const SizedBox(width: 14),
                            if (items[i].icon != null) ...[
                              Icon(items[i].icon,
                                  size: 17,
                                  color: items[i].danger
                                      ? const Color(0xFFFF3B30)
                                      : const Color(0xFF007AFF)),
                              const SizedBox(width: 10),
                            ],
                            Text(items[i].label,
                                style: TextStyle(
                                    fontSize: 13.5,
                                    color: items[i].danger
                                        ? const Color(0xFFFF3B30)
                                        : Colors.black87)),
                            const Spacer(),
                          ]),
                        ),
                      ),
                  ]),
              ),
            ),
          ),
        ),
      ]));
  overlay.insert(entry);
  ctrl.forward();
  return comp.future;
}

// ================================================================= 2. 原位缩放详情

/// 从 anchor 原位放大为居中面板，关闭时缩回原位。
Future<T?> showZoomPanel<T>(
  BuildContext context, {
  required BuildContext anchor,
  required WidgetBuilder builder,
  double widthFactor = 0.86,
  double heightFactor = 0.62,
}) {
  final nav = Navigator.of(context, rootOverlay: true);
  final overlay = Overlay.of(context, rootOverlay: true);
  final begin = _rectOf(anchor);
  final size = MediaQuery.of(context).size;
  final end = Rect.fromCenter(
    center: size.center(Offset.zero),
    width: size.width * widthFactor,
    height: (size.height * heightFactor).clamp(240.0, size.height - 120),
  );
  final comp = Completer<T?>();
  late final OverlayEntry entry;
  final ctrl = AnimationController(
      vsync: nav, duration: const Duration(milliseconds: 260));
  final anim = CurvedAnimation(parent: ctrl, curve: Curves.easeOutCubic);
  final rectTween = RectTween(begin: begin, end: end);

  void close(T? val) {
    if (comp.isCompleted) return;
    ctrl.reverse().whenComplete(() {
      if (entry.mounted) entry.remove();
      comp.complete(val);
    });
  }

  entry = OverlayEntry((ctx) => Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => close(null),
            child: FadeTransition(
                opacity: anim,
                child: const ColoredBox(color: Colors.black45)),
          ),
        ),
        AnimatedBuilder(
          animation: anim,
          builder: (_, __) {
            final r = rectTween.evaluate(anim)!;
            final t = anim.value;
            return Positioned(
              left: r.left,
              top: r.top,
              width: r.width,
              height: r.height,
              child: Opacity(
                opacity: (t * 1.6).clamp(0.0, 1.0),
                child: Material(
                  color: Colors.white,
                  elevation: 12,
                  shadowColor: Colors.black38,
                  borderRadius:
                      BorderRadius.circular(16 + 6 * (1 - t)),
                  clipBehavior: Clip.antiAlias,
                  child: SingleChildScrollView(
                    child: builder(ctx),
                  ),
                ),
              ),
            );
          },
        ),
      ]));
  overlay.insert(entry);
  ctrl.forward();
  return comp.future;
}

// ================================================================= 3. 回弹确认

/// 确认弹窗：弹出带轻微回弹；确认后按钮原地切换为「完成」再收回。
Future<bool> showQConfirm(
  BuildContext context, {
  required String title,
  String? content,
  String confirmText = '确认',
  bool danger = false,
}) async {
  final nav = Navigator.of(context, rootOverlay: true);
  final overlay = Overlay.of(context, rootOverlay: true);
  final comp = Completer<bool>();
  late final OverlayEntry entry;
  final ctrl = AnimationController(
      vsync: nav, duration: const Duration(milliseconds: 320));
  // 回弹：0.6 → 1.06 → 1.0
  final scaleAnim = TweenSequence<double>([
    TweenSequenceItem(
        tween: Tween(begin: 0.6, end: 1.06)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 62),
    TweenSequenceItem(
        tween: Tween(begin: 1.06, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 38),
  ]).animate(ctrl);
  final fade = CurvedAnimation(parent: ctrl, curve: Curves.easeOut);

  void close(bool val) {
    if (comp.isCompleted) return;
    ctrl.reverse().whenComplete(() {
      if (entry.mounted) entry.remove();
      comp.complete(val);
    });
  }

  entry = OverlayEntry((ctx) => FadeTransition(
        opacity: fade,
        child: Stack(children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => close(false),
              child: const ColoredBox(color: Colors.black45),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: ScaleTransition(
                scale: scaleAnim,
                child: _QConfirmBody(
                  title: title,
                  content: content,
                  confirmText: confirmText,
                  danger: danger,
                  onCancel: () => close(false),
                  onDone: () => close(true),
                ),
              ),
            ),
          ),
        ]),
      ));
  overlay.insert(entry);
  ctrl.forward();
  return comp.future;
}

class _QConfirmBody extends StatefulWidget {
  const _QConfirmBody({
    required this.title,
    this.content,
    required this.confirmText,
    required this.danger,
    required this.onCancel,
    required this.onDone,
  });

  final String title;
  final String? content;
  final String confirmText;
  final bool danger;
  final VoidCallback onCancel;
  final VoidCallback onDone;

  @override
  State<_QConfirmBody> createState() => _QConfirmBodyState();
}

class _QConfirmBodyState extends State<_QConfirmBody> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    final accent =
        widget.danger ? const Color(0xFFFF3B30) : const Color(0xFF007AFF);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(widget.title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        if (widget.content != null && widget.content!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(widget.content!,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, height: 1.45, color: Colors.grey.shade700)),
        ],
        const SizedBox(height: 18),
        Row(children: [
          Expanded(
            child: SizedBox(
              height: 44,
              child: OutlinedButton(
                onPressed: _done ? null : widget.onCancel,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('取消', style: TextStyle(fontSize: 14)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 44,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutBack,
                decoration: BoxDecoration(
                  color: _done ? const Color(0xFF34C759) : accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _done
                        ? null
                        : () {
                            setState(() => _done = true);
                            Future.delayed(
                                const Duration(milliseconds: 620),
                                widget.onDone);
                          },
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _done
                            ? const Row(
                                key: ValueKey('done'),
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_rounded,
                                      size: 18, color: Colors.white),
                                  SizedBox(width: 6),
                                  Text('完成',
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white)),
                                ])
                            : Text(widget.confirmText,
                                key: const ValueKey('idle'),
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ================================================================= 4. 气泡提示

/// 指向 anchor 的气泡，数秒后自动收回（也可点击气泡/屏幕关闭）。
void showBubble(
  BuildContext context, {
  required BuildContext anchor,
  required String text,
  Duration visible = const Duration(seconds: 4),
  bool below = true,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final nav = Navigator.of(context, rootOverlay: true);
  final rect = _rectOf(anchor);
  final size = MediaQuery.of(context).size;
  final comp = Completer<void>();
  late final OverlayEntry entry;
  final ctrl = AnimationController(
      vsync: nav, duration: const Duration(milliseconds: 220));
  final anim = CurvedAnimation(parent: ctrl, curve: Curves.easeOutBack);
  Timer? timer;

  void close() {
    if (comp.isCompleted) return;
    timer?.cancel();
    ctrl.reverse().whenComplete(() {
      if (entry.mounted) entry.remove();
      if (!comp.isCompleted) comp.complete();
    });
  }

  entry = OverlayEntry((ctx) {
    final bubbleTop = below ? rect.bottom + 10 : null;
    final bubbleBottom = below ? null : size.height - rect.top + 10;
    final left = (rect.left - 8).clamp(12.0, size.width - 260);
    return Stack(children: [
      Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: close,
          child: const ColoredBox(color: Colors.transparent),
        ),
      ),
      Positioned(
        left: left,
        top: bubbleTop,
        bottom: bubbleBottom,
        width: (size.width - left - 24).clamp(200.0, 280.0),
        child: FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween(begin: 0.85, end: 1.0).animate(anim),
            alignment: below ? Alignment.topLeft : Alignment.bottomLeft,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment:
                CrossAxisAlignment.start, children: [
              if (!below)
                CustomPaint(
                    size: const Size(16, 8),
                    painter: _ArrowPainter(down: false)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xE6333333),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(text,
                    style: const TextStyle(
                        fontSize: 12, height: 1.4, color: Colors.white)),
              ),
              if (below)
                CustomPaint(size: const Size(16, 8), painter: _ArrowPainter()),
            ]),
          ),
        ),
      ),
    ]);
  });
  overlay.insert(entry);
  ctrl.forward();
  timer = Timer(visible, close);
}

class _ArrowPainter extends CustomPainter {
  _ArrowPainter({this.down = true});
  final bool down;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, down ? 0 : size.height)
      ..lineTo(size.width / 2, down ? size.height : 0)
      ..lineTo(size.width, down ? 0 : size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xE6333333));
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter oldDelegate) =>
      oldDelegate.down != down;
}
