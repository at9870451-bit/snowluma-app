import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../core/snow_theme.dart';
import 'ish_sandbox_page.dart';

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
  _DeployTarget _deployTarget = _DeployTarget.snowlumaQqbot;

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('已复制到剪贴板')));
  }

  String get _docRoot => '${Directory.systemTemp.path}/x'; // 占位，实际在方法里取

  /// 把内置 asset 的 tar.gz 解压到 Documents/alpine-rootfs 的指定子目录。
  Future<int> _extractAsset(String asset, String targetSubDir) async {
    final dir = await getApplicationDocumentsDirectory();
    final target = Directory('${dir.path}/alpine-rootfs/$targetSubDir');
    target.createSync(recursive: true);
    final data = await rootBundle.load(asset);
    final tar = TarDecoder()
        .decodeBytes(GZipDecoder().decodeBytes(data.buffer.asUint8List()));
    int n = 0;
    for (final file in tar) {
      var name = file.name;
      if (name.isEmpty || name.contains('..')) continue;
      if (name.startsWith('./')) name = name.substring(2);
      if (name.startsWith('/')) name = name.substring(1);
      if (name.isEmpty) continue;
      final f = File('${target.path}/$name');
      if (file.isFile) {
        f.parent.createSync(recursive: true);
        f.writeAsBytesSync(file.content as List<int>);
        n++;
      } else {
        Directory(f.path).createSync(recursive: true);
      }
    }
    return n;
  }

  /// SnowLuma + QQBot 一键部署（iOS 沙盒内完成）。
  Future<void> _deployAll() async {
    if (_deploying) return;
    setState(() {
      _deploying = true;
      _deployProgress = 0;
    });
    const steps = 6;
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
      File('${dir.path}/alpine-rootfs/opt/go-cqhttp/ish-qq-protocol.sh')
          .writeAsBytesSync(scriptData.buffer.asUint8List(), flush: true);
      File('${dir.path}/alpine-rootfs/opt/go-cqhttp/config.yml')
          .writeAsBytesSync(cfgData.buffer.asUint8List(), flush: true);

      setStep(6, 'SnowLuma + QQBot 部署完成！可在「沙盒」启动 Linux。');
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

  Future<Map<String, bool>> _checkInstalled() async {
    final dir = await getApplicationDocumentsDirectory();
    final root = '${dir.path}/alpine-rootfs';
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