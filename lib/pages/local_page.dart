import 'dart:async';
import 'dart:isolate';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../core/snow_theme.dart';
import 'ish_sandbox_page.dart';
import 'local_panel_page.dart';

/// 本地部署 — 完全本地。AstrBot 风格顶部 4 Tab：
///   沙盒：一键部署（NapCat+AstrBot / SnowLuma+QQBot 单选）+ iSH 沙盒入口
///   网关：已部署的网关/组件状态与连接信息
///   组件：运行环境组件清单
///   说明：本地部署流程与限制
class LocalPage extends StatefulWidget {
  const LocalPage({super.key});

  @override
  State<LocalPage> createState() => _LocalPageState();
}

enum _DeployTarget { snowlumaQqbot, napcatAstrbot }

class _LocalPageState extends State<LocalPage> {
  bool _exporting = false;
  bool _deploying = false;
  double _deployProgress = 0;
  String _deployStatus = '准备就绪';
  String _termLog = '';
  _DeployTarget _deployTarget = _DeployTarget.snowlumaQqbot;
  static const _ish = MethodChannel('snowluma/ish');
  static const _ishOut = EventChannel('snowluma/ish/output');

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('已复制到剪贴板')));
  }

  String get _docRoot => '${Directory.systemTemp.path}/x'; // 占位，实际在方法里取

  /// 把内置 asset 的 tar.gz 解压到 Documents/alpine-rootfs/data 的指定子目录。
  /// 解压放到独立 isolate，避免主线程长时间同步 IO 被 iOS watchdog 杀掉。
  Future<int> _extractAsset(String asset, String targetSubDir) async {
    final dir = await getApplicationDocumentsDirectory();
    // 解压 Alpine rootfs 前：清理旧的坏解压（旧版本把符号链接写成了空文件）
    if (asset.contains('alpine-minirootfs')) {
      final busybox = File('${dir.path}/alpine-rootfs/data/bin/busybox');
      final rootDir = Directory('${dir.path}/alpine-rootfs');
      if (rootDir.existsSync() &&
          (!busybox.existsSync() || busybox.lengthSync() < 1024)) {
        rootDir.deleteSync(recursive: true);
      }
    }
    final data = await rootBundle.load(asset);
    final bytes = data.buffer.asUint8List();
    final targetPath = '${dir.path}/alpine-rootfs/data/$targetSubDir';
    return Isolate.run(() => _extractTarSync(bytes, targetPath));
  }

  /// SnowLuma + QQBot 一键部署（iOS 沙盒内完成）。
  Future<void> _deployAll() async {
    if (_deploying) return;
    setState(() {
      _deploying = true;
      _deployProgress = 0;
    });
    const steps = 5;
    void setStep(int i, String msg) {
      if (!mounted) return;
      setState(() {
        _deployProgress = i / steps;
        _deployStatus = msg;
      });
    }

    try {
      setStep(1, '正在解压 Alpine rootfs…');
      await _extractAsset('assets/rootfs/alpine-minirootfs.tar.gz', '.');
      // iSH fakefs 需要 meta.db 预先存在（SQLITE_OPEN_READWRITE 不会自动创建）
      final _mbDir = await getApplicationDocumentsDirectory();
      File('${_mbDir.path}/alpine-rootfs/meta.db')
          .createSync(recursive: true);

      setStep(2, '正在安装 Node.js…');
      await _extractAsset('assets/protocol/nodejs-alpine-x86.tar.gz', 'usr');

      setStep(3, '正在安装 Python 环境…');
      await _extractAsset('assets/protocol/python-alpine-x86.tar.gz', 'usr');

      setStep(4, '正在安装 QQBot…');
      await _extractAsset('assets/protocol/qqbot.tar.gz', 'opt/qqbot');

      setStep(5, '正在部署 go-cqhttp 协议端…');
      await _extractAsset('assets/protocol/go-cqhttp_linux_386.tar.gz',
          'opt/go-cqhttp');
      final scriptData = await rootBundle
          .load('assets/protocol/ish-qq-protocol.sh');
      final cfgData = await rootBundle
          .load('assets/protocol/go-cqhttp-config.yml');
      final dir = await getApplicationDocumentsDirectory();
      File('${dir.path}/alpine-rootfs/data/opt/go-cqhttp/ish-qq-protocol.sh')
          .writeAsBytesSync(scriptData.buffer.asUint8List(), flush: true);
      File('${dir.path}/alpine-rootfs/data/opt/go-cqhttp/config.yml')
          .writeAsBytesSync(cfgData.buffer.asUint8List(), flush: true);

      setStep(5, '✅ 文件部署完成！');
      if (mounted) setState(() => _deploying = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _deploying = false;
          _deployStatus = '部署失败：$e';
        });
      }
    }
  }

  /// NapCat + AstrBot：把脚本导出到本机，复制一键命令（在 Linux 设备执行）。
  Future<void> _prepareNapcatAstrbot() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final scriptData = await rootBundle
          .load('assets/offline/install-napcat-astrbot.sh');
      final dir = await getApplicationDocumentsDirectory();
      final f = File('${dir.path}/install-napcat-astrbot.sh');
      await f.writeAsBytes(scriptData.buffer.asUint8List(), flush: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('脚本已导出到「文件」App，请拷到 Linux 设备执行。')),
      );
      _copy('sudo bash install-napcat-astrbot.sh');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('导出失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: SnowStyle.background,
        appBar: AppBar(
          title: const Text('本地部署'),
          bottom: const TabBar(
            isScrollable: true,
            labelPadding: EdgeInsets.symmetric(horizontal: 12),
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              color: SnowStyle.ink,
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: SnowStyle.muted,
            dividerColor: Colors.transparent,
            tabs: [
              Tab(text: '沙盒'),
              Tab(text: '网关'),
              Tab(text: '组件'),
              Tab(text: '说明'),
            ],
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: TabBarView(
                children: [
                  _sandboxTab(),
                  _gatewayTab(),
                  _componentsTab(),
                  _infoTab(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------- Tab 1 沙盒 ----------

  Widget _sandboxTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      children: [
        const Text('ONE-CLICK DEPLOY',
            style: TextStyle(fontSize: 11, letterSpacing: 2,
                color: SnowStyle.muted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text('沙盒',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800,
                letterSpacing: -0.8)),
        const SizedBox(height: 16),
        // 一键部署卡片
        Container(
          padding: const EdgeInsets.all(18),
          decoration: SnowStyle.card(color: SnowStyle.ink, radius: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('一键部署',
                  style: TextStyle(color: Colors.white, fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              _targetRadio(
                _DeployTarget.snowlumaQqbot,
                title: 'SnowLuma + QQBot',
                desc: '在 iPhone 沙盒内完成：rootfs + Node + Python + QQBot + go-cqhttp',
              ),
              const SizedBox(height: 8),
              _targetRadio(
                _DeployTarget.napcatAstrbot,
                title: 'NapCat + AstrBot',
                desc: '导出部署脚本，在本地 Linux 设备一键部署协议端与机器人框架',
              ),
              const SizedBox(height: 12),
              if (_deploying) ...[
                LinearProgressIndicator(
                  value: _deployProgress,
                  minHeight: 6,
                  backgroundColor: const Color(0xFF2A2B31),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF4ADE80)),
                ),
                const SizedBox(height: 8),
                Text(_deployStatus,
                    style: const TextStyle(color: Color(0xFFD6D8DE),
                        fontSize: 12, fontFeatures: SnowStyle.tabular)),
                if (_termLog.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    height: 92,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B0C0F),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      reverse: true,
                      child: Text(_termLog,
                          style: const TextStyle(
                              color: Color(0xFF7EE787),
                              fontSize: 10,
                              height: 1.4,
                              fontFamily: 'monospace')),
                    ),
                  ),
                ],
              ] else
                Text(_deployStatus,
                    style: const TextStyle(color: Color(0xFFB5B8C2),
                        fontSize: 12)),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _deploying
                    ? null
                    : (_deployTarget == _DeployTarget.snowlumaQqbot
                        ? _deployAll
                        : _prepareNapcatAstrbot),
                icon: _deploying
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2,
                            color: Colors.white))
                    : Icon(_deployTarget == _DeployTarget.snowlumaQqbot
                        ? Icons.rocket_launch_rounded
                        : Icons.terminal_rounded),
                label: Text(
                    _deploying
                        ? '部署中…'
                        : (_deployTarget == _DeployTarget.snowlumaQqbot
                            ? '开始一键部署'
                            : '导出并复制命令'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _card(
          'iSH 沙盒终端',
          '部署完成后打开终端，启动 Linux 并运行脚本。',
          icon: Icons.terminal_rounded,
          action: FilledButton(
            onPressed: () => openIshSandbox(context),
            child: const Text('打开沙盒'),
          ),
        ),
      ],
    );
  }

  Widget _targetRadio(_DeployTarget value, {required String title, required String desc}) {
    final selected = _deployTarget == value;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => setState(() => _deployTarget = value),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2E3038) : const Color(0xFF1E1F24),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? const Color(0xFF4ADE80) : const Color(0xFF33353D),
            width: 1.2,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: selected ? const Color(0xFF4ADE80) : const Color(0xFF8B8F9A),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(color: Colors.white,
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(desc,
                      style: const TextStyle(color: Color(0xFFB5B8C2),
                          fontSize: 11.5, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Tab 2 网关 ----------

  Widget _gatewayTab() {
    return FutureBuilder<Map<String, bool>>(
      future: _checkInstalled(),
      builder: (context, snap) {
        final data = snap.data ?? {};
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            const Text('DEPLOYED GATEWAY',
                style: TextStyle(fontSize: 11, letterSpacing: 2,
                    color: SnowStyle.muted, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('已部署网关',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800,
                    letterSpacing: -0.8)),
            const SizedBox(height: 6),
            const Text('沙盒中已安装的组件与连接信息。',
                style: TextStyle(color: SnowStyle.muted, fontSize: 13, height: 1.5)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _openPanel,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('打开本地面板（127.0.0.1:6199）'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                backgroundColor: SnowStyle.ink,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _copy('http://127.0.0.1:6199'),
              icon: const Icon(Icons.link_rounded, size: 16),
              label: const Text('复制面板地址'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _diagnose,
              icon: const Icon(Icons.troubleshoot_rounded, size: 16),
              label: const Text('诊断服务（查看终端输出）'),
            ),
            const SizedBox(height: 16),
            _statusRow('Alpine rootfs', data['rootfs'] == true),
            _statusRow('Node.js', data['node'] == true),
            _statusRow('Python', data['python'] == true),
            _statusRow('QQBot', data['qqbot'] == true),
            _statusRow('go-cqhttp', data['gocqhttp'] == true),
            const SizedBox(height: 12),
            _section('连接信息（沙盒内）'),
            _row('QQ 协议端 WS', 'ws://127.0.0.1:3001'),
            _row('HTTP 协议端', 'http://127.0.0.1:5700'),
            _row('QQBot 面板', 'http://127.0.0.1:6199'),
          ],
        );
      },
    );
  }

  void _openPanel() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => const LocalPanelPage(),
    ));
  }

  /// 诊断：启动沙盒并执行检查命令，把终端输出显示出来。
  Future<void> _diagnose() async {
    final buf = StringBuffer();
    StreamSubscription<dynamic>? sub;
    try {
      sub = _ishOut.receiveBroadcastStream().listen((ev) {
        buf.write(ev);
      }, onError: (_) {});
      final dir = await getApplicationDocumentsDirectory();
      final rootfs = '${dir.path}/alpine-rootfs';
      try {
        await _ish.invokeMethod<void>('start', {
          'rootfs': rootfs,
          'exe': '/bin/sh',
          'envp': 'TERM=xterm\\u0000PATH=/usr/bin:/bin:/usr/sbin:/sbin\\u0000HOME=/root\\u0000\\u0000',
        });
      } catch (_) {
        // 已启动会抛错，忽略
      }
      await Future<void>.delayed(const Duration(seconds: 2));
      await _ish.invokeMethod<void>('write', {
        'text': 'export PATH=/usr/bin:/bin:/usr/sbin:/sbin\\n'
                'echo ===== python =====\\n'
                'python3 --version 2>&1\\n'
                'echo ===== qqbot =====\\n'
                'ls /opt/qqbot 2>&1 | head -10\\n'
                'echo ===== run =====\\n'
                'cd /opt/qqbot && timeout 8 python3 run.py --no-tray 2>&1 | head -25\\n'
                'echo ===== 6199 =====\\n'
                'netstat -ltn 2>/dev/null | grep 6199 || echo "6199 未监听"\\n',
      });
      await Future<void>.delayed(const Duration(seconds: 12));
    } catch (e) {
      buf.write('\n[诊断异常] $e');
    } finally {
      await sub?.cancel();
    }
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('服务诊断'),
        content: SingleChildScrollView(
          child: SelectableText(
            buf.isEmpty ? '（无输出）' : buf.toString(),
            style: const TextStyle(fontSize: 11, fontFamily: 'monospace',
                height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<Map<String, bool>> _checkInstalled() async {
    final dir = await getApplicationDocumentsDirectory();
    final root = '${dir.path}/alpine-rootfs/data';
    return {
      'rootfs': Directory(root).existsSync(),
      'node': File('$root/usr/bin/node').existsSync(),
      'python': File('$root/usr/bin/python3').existsSync(),
      'qqbot': Directory('$root/opt/qqbot').existsSync(),
      'gocqhttp': File('$root/opt/go-cqhttp/go-cqhttp').existsSync() ||
          Directory('$root/opt/go-cqhttp').existsSync(),
    };
  }

  Widget _statusRow(String label, bool ok) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: SnowStyle.card(),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              size: 19,
              color: ok ? const Color(0xFF34C759) : const Color(0xFFC7C7CC)),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(ok ? '已就绪' : '未安装',
              style: TextStyle(fontSize: 11.5,
                  color: ok ? const Color(0xFF34C759) : const Color(0xFF9A9FA8))),
        ],
      ),
    );
  }

  // ---------- Tab 3 组件 ----------

  Widget _componentsTab() {
    const comps = [
      ('BusyBox', '通用 Unix 工具箱', '沙盒 bin/'),
      ('musl', '轻量 C 库', '静态链接'),
      ('Python', '已内置', 'usr/bin/python3'),
      ('Node.js', '已内置 v20.15.1', 'usr/bin/node'),
      ('OpenSSL', '证书/HTTPS', 'usr/bin/openssl'),
      ('Git', '版本管理', 'usr/bin/git'),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      children: [
        const Text('ENVIRONMENT',
            style: TextStyle(fontSize: 11, letterSpacing: 2,
                color: SnowStyle.muted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text('组件',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800,
                letterSpacing: -0.8)),
        const SizedBox(height: 16),
        for (final c in comps)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: SnowStyle.card(),
            child: Row(
              children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                      color: SnowStyle.softAccent,
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.inventory_2_outlined,
                      size: 17, color: SnowStyle.accent),
                ),
                const SizedBox(width: 10),
                SizedBox(width: 90,
                    child: Text(c.$1,
                        style: const TextStyle(fontSize: 13.5,
                            fontWeight: FontWeight.w700))),
                Expanded(
                    child: Text(c.$2,
                        style: const TextStyle(fontSize: 12,
                            color: SnowStyle.muted))),
                Text(c.$3,
                    style: const TextStyle(fontSize: 10.5,
                        color: SnowStyle.accent)),
              ],
            ),
          ),
      ],
    );
  }

  // ---------- Tab 4 说明 ----------

  Widget _infoTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      children: [
        const Text('LOCAL GUIDE',
            style: TextStyle(fontSize: 11, letterSpacing: 2,
                color: SnowStyle.muted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text('说明',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800,
                letterSpacing: -0.8)),
        const SizedBox(height: 16),
        _infoCard('方案一 · iPhone 本机（iSH）',
            '一键部署 SnowLuma + QQBot：rootfs + Node + Python + QQBot + go-cqhttp，'
            '全部在沙盒内完成。局限：go-cqhttp 旧协议可能被风控；iOS 会挂起后台。'),
        _infoCard('方案二 · 本地 Linux 设备',
            '选择 NapCat + AstrBot，导出脚本到 Linux 设备执行 '
            'sudo bash install-napcat-astrbot.sh，一键部署协议端与机器人框架。'),
        _infoCard('离线包内容',
            'install.sh / ish-install.sh / ish-qq-protocol.sh / '
            'install-napcat-astrbot.sh / qqbot.tar.gz / go-cqhttp / README'),
      ],
    );
  }

  Widget _infoCard(String title, String desc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: SnowStyle.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Text(desc,
              style: const TextStyle(fontSize: 12.5, color: SnowStyle.muted,
                  height: 1.5)),
        ],
      ),
    );
  }

  // ---------- 通用组件 ----------

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
        child: Text(title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                letterSpacing: 1, color: SnowStyle.muted)),
      );

  Widget _row(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: SnowStyle.card(),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(fontSize: 12.5, color: SnowStyle.muted)),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(value,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 12.5,
                    fontFeatures: SnowStyle.tabular)),
          ),
        ],
      ),
    );
  }

  Widget _card(String title, String desc,
      {required IconData icon, Widget? action}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: SnowStyle.card(),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
                color: SnowStyle.softAccent,
                borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, size: 20, color: SnowStyle.accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(desc,
                    style: const TextStyle(fontSize: 12, color: SnowStyle.muted,
                        height: 1.45)),
              ],
            ),
          ),
          if (action != null) ...[const SizedBox(width: 8), action],
        ],
      ),
    );
  }
}

/// 顶层函数：在独立 isolate 里解压 tar.gz（逐文件写盘）。
int _extractTarSync(List<int> bytes, String targetPath) {
  final target = Directory(targetPath)..createSync(recursive: true);
  final tar = TarDecoder()
      .decodeBytes(GZipDecoder().decodeBytes(bytes));
  int n = 0;
  for (final file in tar) {
    var name = file.name;
    if (name.isEmpty || name.contains('..')) continue;
    if (name.startsWith('./')) name = name.substring(2);
    if (name.startsWith('/')) name = name.substring(1);
    if (name.isEmpty) continue;
    final f = File('${target.path}/$name');
    if (file.isSymbolicLink) {
      final raw = file.content;
      final linkTarget = raw is String
          ? raw
          : String.fromCharCodes(raw as List<int>);
      f.parent.createSync(recursive: true);
      try {
        Link(f.path).createSync(linkTarget);
      } catch (_) {}
      n++;
    } else if (file.isFile) {
      f.parent.createSync(recursive: true);
      f.writeAsBytesSync(file.content as List<int>);
      n++;
    } else {
      Directory(f.path).createSync(recursive: true);
    }
  }
  return n;
}
