import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../core/snow_theme.dart';

/// iSH 沙盒页：
/// 1. 内置 Alpine minirootfs 解压到 Documents/alpine-rootfs
/// 2. 通过 MethodChannel 调用原生桥接，启动 Linux 会话
/// 3. 简易终端 UI（输入命令 + 显示状态；PTY 输出回传为下一步）
class IshSandboxPage extends StatefulWidget {
  const IshSandboxPage({super.key});

  @override
  State<IshSandboxPage> createState() => _IshSandboxPageState();
}

class _IshSandboxPageState extends State<IshSandboxPage> {
  static const MethodChannel _channel = MethodChannel('snowluma/ish');

  bool _preparing = false;
  bool _starting = false;
  String _status = '未准备';
  String _rootfs = '';
  String _rootfsState = '检查中…';
  int _files = 0;
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
    final dir = await getApplicationDocumentsDirectory();
    final rootfs = '${dir.path}/alpine-rootfs';
    if (!mounted) return;
    setState(() {
      _rootfs = rootfs;
      _rootfsState = Directory(rootfs).existsSync()
          ? '已就绪'
          : '未解压（点「解压 rootfs」）';
    });
  }

  /// 从内置 asset 解压 Alpine minirootfs 到 Documents/alpine-rootfs。
  Future<void> _ensureRootfs() async {
    if (_preparing) return;
    setState(() {
      _preparing = true;
      _status = '正在解压 Alpine rootfs…';
    });
    try {
      final data =
          await rootBundle.load('assets/rootfs/alpine-minirootfs.tar.gz');
      final bytes = data.buffer.asUint8List();
      final tar = TarDecoder()
          .decodeBytes(GZipDecoder().decodeBytes(bytes));
      final rootfsDir = Directory(_rootfs);
      rootfsDir.createSync(recursive: true);
      int n = 0;
      for (final file in tar) {
        var name = file.name;
        if (name.isEmpty || name.contains('..')) continue;
        if (name.startsWith('./')) name = name.substring(2);
        if (name.startsWith('/')) name = name.substring(1);
        if (name.isEmpty) continue;
        final target = File('${rootfsDir.path}/$name');
        if (file.isFile) {
          target.parent.createSync(recursive: true);
          target.writeAsBytesSync(file.content as List<int>);
          n++;
        } else {
          // ArchiveFile 无 isDirectory；非文件项即目录（name 以 / 结尾）
          Directory(target.path).createSync(recursive: true);
        }
      }
      if (!mounted) return;
      setState(() {
        _files = n;
        _rootfsState = '已就绪（$n 文件）';
        _status = 'rootfs 就绪，可以启动 Linux 会话。';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = '解压失败：$e');
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  Future<void> _start() async {
    if (_starting) return;
    if (_rootfsState.contains('未解压')) {
      await _ensureRootfs();
      if (!mounted || _rootfsState.contains('失败')) return;
    }
    setState(() {
      _starting = true;
      _status = '正在启动 Linux 会话…';
    });
    try {
      await _channel.invokeMethod<void>('start', {
        'rootfs': _rootfs,
        'exe': _exeController.text.trim().isEmpty
            ? '/bin/sh'
            : _exeController.text.trim(),
        'envp': 'TERM=xterm',
      });
      if (!mounted) return;
      setState(() => _status =
          '已请求启动（后台线程）。内核初始化成功后 /bin/sh 会进入主循环。');
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
            constraints: const BoxConstraints(maxWidth: 760),
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
                const Text('内置 Alpine Linux rootfs，在 App 内启动 Linux 会话。',
                    style: TextStyle(color: SnowStyle.muted, fontSize: 13, height: 1.5)),
                const SizedBox(height: 20),
                _field('Rootfs 路径', _rootfs.isEmpty ? '获取中…' : _rootfs,
                    mono: true),
                _field('Rootfs 状态', _rootfsState),
                _field('启动命令', _exeController.text,
                    controller: _exeController),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _preparing ? null : _ensureRootfs,
                        icon: _preparing
                            ? const SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.archive_outlined, size: 18),
                        label: Text(_preparing ? '解压中…' : '解压 rootfs'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: (_preparing || _starting) ? null : _start,
                        icon: _starting
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.terminal_rounded),
                        label: Text(_starting ? '正在启动…' : '启动 Linux'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _terminalCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _terminalCard() {
    return Container(
      decoration: SnowStyle.card(color: const Color(0xFF101216)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Row(
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                      color: const Color(0xFFFF5F57), shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                      color: const Color(0xFFFEBC2E), shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                      color: const Color(0xFF28C840), shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                const Text('alpine-rootfs — /bin/sh',
                    style: TextStyle(color: Color(0xFF8B8F9A), fontSize: 11)),
              ],
            ),
          ),
          Container(
            height: 180,
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFF0B0C0F),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: SelectableText(
              _status.isEmpty ? '等待操作…\n' : '> $_status\n',
              style: const TextStyle(
                  color: Color(0xFFD6D8DE), fontSize: 12.5,
                  fontFamily: 'Menlo', height: 1.5),
            ),
          ),
        ],
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