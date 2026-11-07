import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../core/snow_theme.dart';

/// iSH 沙盒启动页（第 4 步雏形）：
/// 通过 MethodChannel 调用 iOS 原生桥接，在后台启动一个 Linux 会话。
/// 终端输出/交互后续版本接入（当前先验证启动链路）。
class IshSandboxPage extends StatefulWidget {
  const IshSandboxPage({super.key});

  @override
  State<IshSandboxPage> createState() => _IshSandboxPageState();
}

class _IshSandboxPageState extends State<IshSandboxPage> {
  static const MethodChannel _channel = MethodChannel('snowluma/ish');

  bool _starting = false;
  String _status = '未启动';
  String _rootfs = '';
  final TextEditingController _exeController =
      TextEditingController(text: '/bin/sh');

  @override
  void initState() {
    super.initState();
    _initRootfs();
  }

  @override
  void dispose() {
    _exeController.dispose();
    super.dispose();
  }

  Future<void> _initRootfs() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      if (mounted) {
        setState(() => _rootfs = '${dir.path}/alpine-rootfs');
      }
    } catch (_) {}
  }

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _status = '正在启动 Linux 会话…';
    });
    try {
      await _channel.invokeMethod<void>('start', {
        'rootfs': _rootfs,
        'exe': _exeController.text.trim().isEmpty ? '/bin/sh' : _exeController.text.trim(),
        'envp': 'TERM=xterm',
      });
      if (!mounted) return;
      setState(() => _status =
          '已请求启动（后台线程）。若 rootfs 尚未准备，进程会在内核初始化阶段报错退出。');
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() => _status = '启动失败：${e.message}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = '异常：$e');
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SnowStyle.background,
      appBar: AppBar(title: const Text('iSH 沙盒')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
              children: [
                const Text('LINUX SANDBOX',
                    style: TextStyle(fontSize: 11, letterSpacing: 2,
                        color: SnowStyle.muted, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text('iSH 沙盒',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800,
                        letterSpacing: -0.8)),
                const SizedBox(height: 6),
                const Text('在 App 内启动 Linux 环境（内核已内嵌）。'
                    '此版本先验证启动链路，终端交互将在下一版接入。',
                    style: TextStyle(color: SnowStyle.muted, fontSize: 13, height: 1.5)),
                const SizedBox(height: 20),
                _field('Rootfs 路径', _rootfs.isEmpty ? '获取中…' : _rootfs,
                    mono: true),
                _field('启动命令', _exeController.text,
                    controller: _exeController),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _starting ? null : _start,
                  icon: _starting
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.terminal_rounded),
                  label: Text(_starting ? '正在启动…' : '启动 Linux 沙盒'),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: SnowStyle.card(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('状态',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      SelectableText(_status,
                          style: const TextStyle(fontSize: 12.5,
                              color: SnowStyle.muted, height: 1.5)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text('第 5 步预告：把 Alpine minirootfs 解压到上述路径后，'
                    '即可在沙盒里运行 /bin/sh 并部署脚本。',
                    style: TextStyle(fontSize: 11, color: SnowStyle.muted, height: 1.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(String label, String value, {bool mono = false, TextEditingController? controller}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: SnowStyle.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 2),
            child: Text(label,
                style: const TextStyle(fontSize: 11, color: SnowStyle.muted)),
          ),
          if (controller != null)
            TextField(
              controller: controller,
              style: const TextStyle(fontSize: 13, fontFamily: 'Menlo'),
              decoration: const InputDecoration(border: InputBorder.none, isDense: true),
            )
          else
            SelectableText(value,
                style: TextStyle(
                    fontSize: 12.5,
                    fontFamily: mono ? 'Menlo' : null,
                    fontFeatures: SnowStyle.tabular)),
        ],
      ),
    );
  }
}

/// 便捷入口：从本地部署页跳转到 iSH 沙盒页。
void openIshSandbox(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const IshSandboxPage()),
  );
}