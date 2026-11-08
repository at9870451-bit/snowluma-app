import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../core/snow_theme.dart';

/// iSH 沙盒页（可交互终端）：
/// 1. 内置 Alpine rootfs 解压到 Documents/alpine-rootfs
/// 2. 启动 Linux 会话（MethodChannel snowluma/ish start）
/// 3. 终端：EventChannel 接收输出，输入命令回传（write）
class IshSandboxPage extends StatefulWidget {
  const IshSandboxPage({super.key});

  @override
  State<IshSandboxPage> createState() => _IshSandboxPageState();
}

class _IshSandboxPageState extends State<IshSandboxPage> {
  static const MethodChannel _channel = MethodChannel('snowluma/ish');
  static const EventChannel _output =
      EventChannel('snowluma/ish/output');

  bool _preparing = false;
  bool _starting = false;
  String _rootfs = '';
  String _rootfsState = '检查中…';
  String _term = '等待操作…\n> ';
  final _termController = ScrollController();
  final TextEditingController _inputController =
      TextEditingController(text: '/bin/sh');
  StreamSubscription<dynamic>? _outputSub;

  @override
  void initState() {
    super.initState();
    _initRootfs();
    _listenOutput();
  }

  @override
  void dispose() {
    _outputSub?.cancel();
    _inputController.dispose();
    _termController.dispose();
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

  void _listenOutput() {
    _outputSub = _output.receiveBroadcastStream().listen((event) {
      if (!mounted || event == null) return;
      setState(() {
        _term += '$event';
        if (_term.length > 6000) {
          _term = _term.substring(_term.length - 6000);
        }
      });
      _scrollToBottom();
    }, onError: (Object e) {
      if (mounted) {
        setState(() => _term += '\n[输出通道错误] $e\n');
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_termController.hasClients) {
        _termController.jumpTo(_termController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _ensureRootfs() async {
    if (_preparing) return;
    setState(() {
      _preparing = true;
      _term += '正在解压 Alpine rootfs…\n';
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
          Directory(target.path).createSync(recursive: true);
        }
      }
      if (!mounted) return;
      setState(() {
        _rootfsState = '已就绪（$n 文件）';
        _term += 'rootfs 就绪（$n 文件）。\n> ';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _term += '解压失败：$e\n');
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
      _term += '正在启动 Linux 会话…\n';
    });
    try {
      await _channel.invokeMethod<void>('start', {
        'rootfs': _rootfs,
        'exe': '/bin/sh',
        'envp': 'TERM=xterm',
      });
      if (!mounted) return;
      setState(() => _term += '/bin/sh 已在后台运行。输入命令试试，例如：ls\n');
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() => _term += '启动失败：${e.message}\n');
    } catch (e) {
      if (!mounted) return;
      setState(() => _term += '异常：$e\n');
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  /// 把 Node.js（Alpine x86）解压到 rootfs/usr/。
  Future<void> _installNode() async {
    if (_preparing) return;
    if (_rootfsState.contains('未解压')) {
      await _ensureRootfs();
      if (!mounted || _rootfsState.contains('失败')) return;
    }
    setState(() {
      _preparing = true;
      _term += '正在安装 Node.js…\n';
    });
    try {
      final rootfsDir = Directory(_rootfs);
      final data = await rootBundle
          .load('assets/protocol/nodejs-alpine-x86.tar.gz');
      final tar = TarDecoder()
          .decodeBytes(GZipDecoder().decodeBytes(data.buffer.asUint8List()));
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
          Directory(target.path).createSync(recursive: true);
        }
      }
      if (!mounted) return;
      setState(() {
        _preparing = false;
        _term += 'Node.js 已安装（$n 文件）到 /usr。\n'
            '终端里运行：node --version\n> ';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _preparing = false;
        _term += 'Node.js 安装失败：$e\n';
      });
    }
  }

  /// 把 Python（Alpine x86）解压到 rootfs/usr/。
  Future<void> _installPython() async {
    if (_preparing) return;
    if (_rootfsState.contains('未解压')) {
      await _ensureRootfs();
      if (!mounted || _rootfsState.contains('失败')) return;
    }
    setState(() {
      _preparing = true;
      _term += '正在安装 Python 环境…\n';
    });
    try {
      final rootfsDir = Directory(_rootfs);
      final data = await rootBundle
          .load('assets/protocol/python-alpine-x86.tar.gz');
      final tar = TarDecoder()
          .decodeBytes(GZipDecoder().decodeBytes(data.buffer.asUint8List()));
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
          Directory(target.path).createSync(recursive: true);
        }
      }
      if (!mounted) return;
      setState(() {
        _preparing = false;
        _term += 'Python 环境已安装（$n 文件）。\n'
            '终端里运行：python3 --version\n> ';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _preparing = false;
        _term += 'Python 安装失败：$e\n';
      });
    }
  }

  /// 把 QQBot 程序解压到 rootfs/opt/qqbot。
  Future<void> _installQqbot() async {
    if (_preparing) return;
    if (_rootfsState.contains('未解压')) {
      await _ensureRootfs();
      if (!mounted || _rootfsState.contains('失败')) return;
    }
    setState(() {
      _preparing = true;
      _term += '正在安装 QQBot 程序…\n';
    });
    try {
      final rootfsDir = Directory(_rootfs);
      final outDir = Directory('${rootfsDir.path}/opt/qqbot');
      outDir.createSync(recursive: true);
      final data = await rootBundle
          .load('assets/protocol/qqbot.tar.gz');
      final tar = TarDecoder()
          .decodeBytes(GZipDecoder().decodeBytes(data.buffer.asUint8List()));
      int n = 0;
      for (final file in tar) {
        var name = file.name;
        if (name.isEmpty || name.contains('..')) continue;
        if (name.startsWith('./')) name = name.substring(2);
        if (name.startsWith('/')) name = name.substring(1);
        if (name.isEmpty) continue;
        final target = File('${outDir.path}/$name');
        if (file.isFile) {
          target.parent.createSync(recursive: true);
          target.writeAsBytesSync(file.content as List<int>);
          n++;
        } else {
          Directory(target.path).createSync(recursive: true);
        }
      }
      if (!mounted) return;
      setState(() {
        _preparing = false;
        _term += 'QQBot 已安装到 /opt/qqbot（$n 文件）。\n'
            '终端里运行：python3 /opt/qqbot/run.py --no-tray\n> ';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _preparing = false;
        _term += 'QQBot 安装失败：$e\n';
      });
    }
  }

  Future<void> _sendCommand() async {
    final cmd = _inputController.text;
    if (cmd.trim().isEmpty) return;
    setState(() {
      _term += '> $cmd\n';
      _inputController.clear();
    });
    try {
      await _channel.invokeMethod<void>('write', {'text': '$cmd\n'});
    } catch (e) {
      if (mounted) setState(() => _term += '[发送失败] $e\n');
    }
  }

  /// 把 go-cqhttp 协议端 + 脚本解压到 rootfs/opt/go-cqhttp。
  Future<void> _deployProtocol() async {
    if (_preparing) return;
    if (_rootfsState.contains('未解压')) {
      await _ensureRootfs();
      if (!mounted || _rootfsState.contains('失败')) return;
    }
    setState(() {
      _preparing = true;
      _term += '正在部署 go-cqhttp 协议端…\n';
    });
    try {
      final rootfsDir = Directory(_rootfs);
      final outDir = Directory('${rootfsDir.path}/opt/go-cqhttp');
      outDir.createSync(recursive: true);

      final data = await rootBundle
          .load('assets/protocol/go-cqhttp_linux_386.tar.gz');
      final tar = TarDecoder()
          .decodeBytes(GZipDecoder().decodeBytes(data.buffer.asUint8List()));
      int n = 0;
      for (final file in tar) {
        var name = file.name;
        if (name.isEmpty || name.contains('..')) continue;
        if (name.startsWith('./')) name = name.substring(2);
        if (name.startsWith('/')) name = name.substring(1);
        if (name.isEmpty) continue;
        final target = File('${outDir.path}/$name');
        if (file.isFile) {
          target.parent.createSync(recursive: true);
          target.writeAsBytesSync(file.content as List<int>);
          n++;
        } else {
          Directory(target.path).createSync(recursive: true);
        }
      }
      // 复制启动脚本和预设配置
      final scriptData = await rootBundle
          .load('assets/protocol/ish-qq-protocol.sh');
      File('${outDir.path}/ish-qq-protocol.sh')
          .writeAsBytesSync(scriptData.buffer.asUint8List(), flush: true);
      final cfgData = await rootBundle
          .load('assets/protocol/go-cqhttp-config.yml');
      File('${outDir.path}/config.yml')
          .writeAsBytesSync(cfgData.buffer.asUint8List(), flush: true);
      if (!mounted) return;
      setState(() {
        _preparing = false;
        _term += '协议端已部署到 /opt/go-cqhttp。\n'
            '终端里运行：sh /opt/go-cqhttp/ish-qq-protocol.sh\n'
            '（编辑 config.yml 把 uin 改成你的 QQ 号后执行）\n> ';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _preparing = false;
        _term += '部署失败：$e\n';
      });
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
            constraints: const BoxConstraints(maxWidth: 800),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(_rootfsState,
                            style: const TextStyle(fontSize: 12,
                                color: SnowStyle.muted)),
                      ),
                      OutlinedButton(
                        onPressed: _preparing ? null : _ensureRootfs,
                        child: Text(_preparing ? '解压中…' : '解压 rootfs'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: (_preparing || _starting) ? null : _start,
                        child: Text(_starting ? '启动中…' : '启动 Linux'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _preparing ? null : _installNode,
                          icon: const Icon(Icons.javascript_outlined, size: 16),
                          label: Text(_preparing ? '处理中…' : '安装 Node.js'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _preparing ? null : _deployProtocol,
                          icon: const Icon(Icons.hub_outlined, size: 16),
                          label: Text(_preparing ? '处理中…' : '部署 go-cqhttp'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _preparing ? null : _installPython,
                          icon: const Icon(Icons.code_rounded, size: 16),
                          label: Text(_preparing ? '处理中…' : '安装 Python'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _preparing ? null : _installQqbot,
                          icon: const Icon(Icons.smart_toy_outlined, size: 16),
                          label: Text(_preparing ? '处理中…' : '安装 QQBot'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B0C0F),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          // 终端标题栏
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                            child: Row(
                              children: [
                                Container(
                                  width: 9, height: 9,
                                  decoration: BoxDecoration(
                                      color: const Color(0xFFFF5F57),
                                      shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  width: 9, height: 9,
                                  decoration: BoxDecoration(
                                      color: const Color(0xFFFEBC2E),
                                      shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  width: 9, height: 9,
                                  decoration: BoxDecoration(
                                      color: const Color(0xFF28C840),
                                      shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 10),
                                const Text('alpine-rootfs — /bin/sh',
                                    style: TextStyle(
                                        color: Color(0xFF8B8F9A), fontSize: 11)),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: Color(0xFF22242A)),
                          // 输出区
                          Expanded(
                            child: SingleChildScrollView(
                              controller: _termController,
                              padding: const EdgeInsets.all(12),
                              child: SelectableText(
                                _term,
                                style: const TextStyle(
                                    color: Color(0xFFD6D8DE), fontSize: 12.5,
                                    fontFamily: 'Menlo', height: 1.5),
                              ),
                            ),
                          ),
                          // 输入区
                          Container(
                            color: const Color(0xFF131418),
                            padding:
                                const EdgeInsets.fromLTRB(12, 6, 6, 6),
                            child: Row(
                              children: [
                                const Text('> ',
                                    style: TextStyle(color: Color(0xFF28C840),
                                        fontFamily: 'Menlo', fontSize: 13)),
                                Expanded(
                                  child: TextField(
                                    controller: _inputController,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'Menlo', fontSize: 13),
                                    decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        isDense: true,
                                        hintText: '输入命令，回车发送',
                                        hintStyle: TextStyle(
                                            color: Color(0xFF5A5E6A))),
                                    onSubmitted: (_) => _sendCommand(),
                                  ),
                                ),
                                IconButton(
                                  onPressed: _sendCommand,
                                  icon: const Icon(Icons.send_rounded,
                                      color: Color(0xFF8B8F9A), size: 18),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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