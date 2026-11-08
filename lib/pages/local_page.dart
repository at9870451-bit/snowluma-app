import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../core/snow_theme.dart';
import 'ish_sandbox_page.dart';

/// 本地部署 — 完全本地，不依赖服务器。AstrBot 风格顶部 4 Tab：
///   沙盒：App 内嵌 iSH Linux 沙盒入口
///   部署：离线包导出 / 局域网设备一键安装 / NapCat+AstrBot
///   组件：运行环境组件清单
///   说明：本地部署流程与限制
class LocalPage extends StatefulWidget {
  const LocalPage({super.key});

  @override
  State<LocalPage> createState() => _LocalPageState();
}

class _LocalPageState extends State<LocalPage> {
  bool _exporting = false;
  bool _deploying = false;
  double _deployProgress = 0;
  String _deployStatus = '准备就绪';

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('已复制到剪贴板')));
  }

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

  /// 一键部署：依次解压 rootfs、Node.js、Python、QQBot、go-cqhttp。
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

      setStep(6, '全部部署完成！可在「沙盒」中启动 Linux 终端。');
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

  Future<void> _exportOfflinePackage() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final data = await rootBundle
          .load('assets/offline/snowluma-qqbot-offline.tar.gz');
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/snowluma-qqbot-offline.tar.gz');
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已导出（${(data.lengthInBytes / 1024 / 1024).toStringAsFixed(1)} MB）到「文件」App'),
          duration: const Duration(seconds: 4),
        ),
      );
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
              Tab(text: '部署'),
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
                  _deployTab(),
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
        const Text('ISH SANDBOX',
            style: TextStyle(fontSize: 11, letterSpacing: 2,
                color: SnowStyle.muted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text('沙盒',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800,
                letterSpacing: -0.8)),
        const SizedBox(height: 6),
        const Text('App 内嵌 iSH Linux 沙盒：解压 Alpine rootfs、安装 Node.js、'
            '启动可交互终端、部署 go-cqhttp 协议端。',
            style: TextStyle(color: SnowStyle.muted, fontSize: 13, height: 1.5)),
        const SizedBox(height: 16),
        // 一键部署卡片
        Container(
          padding: const EdgeInsets.all(18),
          decoration: SnowStyle.card(color: SnowStyle.ink, radius: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('一键部署本地机器人',
                  style: TextStyle(color: Colors.white, fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('自动完成：rootfs → Node.js → Python → QQBot → go-cqhttp',
                  style: TextStyle(color: Color(0xFFB5B8C2), fontSize: 12,
                      height: 1.4)),
              const SizedBox(height: 14),
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
                onPressed: _deploying ? null : _deployAll,
                icon: _deploying
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2,
                            color: Colors.white))
                    : const Icon(Icons.rocket_launch_rounded),
                label: Text(_deploying ? '部署中…' : '开始一键部署'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _card(
          'iSH 沙盒',
          '内置 Alpine rootfs + Node.js + go-cqhttp 协议端，iPhone 本地跑 Linux。',
          icon: Icons.terminal_rounded,
          action: FilledButton(
            onPressed: () => openIshSandbox(context),
            child: const Text('打开沙盒'),
          ),
        ),
        const SizedBox(height: 10),
        _copyCard(
          '部署协议端（沙盒终端内）',
          '在 iSH 沙盒里执行以下步骤启动 QQ 协议端：',
          code: 'sh /opt/go-cqhttp/ish-qq-protocol.sh',
        ),
        const SizedBox(height: 8),
        const Text('限制：go-cqhttp 为旧版协议，可能被风控；iOS 会挂起后台 iSH。',
            style: TextStyle(fontSize: 11, color: SnowStyle.muted, height: 1.5)),
      ],
    );
  }

  // ---------- Tab 2 部署 ----------

  Widget _deployTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      children: [
        const Text('OFFLINE DEPLOY',
            style: TextStyle(fontSize: 11, letterSpacing: 2,
                color: SnowStyle.muted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text('部署',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800,
                letterSpacing: -0.8)),
        const SizedBox(height: 16),
        _card(
          '离线包已内置',
          '安装脚本 + QQBot 程序 + go-cqhttp + NapCat/AstrBot 部署脚本，'
          '导出后到 iOS「文件」App 取用。',
          icon: Icons.archive_outlined,
          action: OutlinedButton(
            onPressed: _exporting ? null : _exportOfflinePackage,
            child: Text(_exporting ? '导出中…' : '导出'),
          ),
        ),
        const SizedBox(height: 10),
        _copyCard(
          '局域网设备一键安装（Linux）',
          '把离线包拷到树莓派/NUC/旧电脑，一条命令装好 SnowLuma+QQBot：',
          code: 'tar -xzf snowluma-qqbot-offline.tar.gz\n'
              'cd offline && sudo bash install.sh',
        ),
        const SizedBox(height: 10),
        _copyCard(
          '一键部署 NapCat + AstrBot（Linux）',
          '在本地 Linux 设备上一条命令部署 QQ 协议端和机器人框架：',
          code: 'sudo bash install-napcat-astrbot.sh',
        ),
        const SizedBox(height: 10),
        _copyCard(
          'iSH（iPhone）安装',
          '在 iSH 里解压并运行安装脚本：',
          code: 'cd /mnt/你的离线包目录\n'
              'tar -xzf snowluma-qqbot-offline.tar.gz\n'
              'cd offline && sh ish-install.sh',
        ),
      ],
    );
  }

  // ---------- Tab 3 组件 ----------

  Widget _componentsTab() {
    const comps = [
      ('BusyBox', '通用 Unix 工具箱', '沙盒 bin/'),
      ('musl', '轻量 C 库', '静态链接'),
      ('Python', 'QQBot 运行环境', 'usr/bin/python3'),
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
            '使用 App 内置沙盒：解压 Alpine rootfs → 安装 Node.js → 启动终端 → '
            '部署 go-cqhttp 扫码登录。无需任何服务器。\n'
            '局限：go-cqhttp 为旧协议可能被风控；iOS 会挂起后台 iSH。'),
        _infoCard('方案二 · 局域网设备',
            '把 App 导出的离线包拷到树莓派/NUC/旧电脑，运行 install.sh，'
            '手机通过局域网连接设备上的面板。\n'
            '这是最稳定的本地部署方式，可跑 NapCat 新协议。'),
        _infoCard('方案三 · NapCat + AstrBot',
            '在本地 Linux 设备运行 install-napcat-astrbot.sh，一键部署 '
            'NapCat（QQ 协议端）+ AstrBot（机器人框架）。'),
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

  Widget _copyCard(String title, String desc, {required String code}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
      decoration: SnowStyle.card(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(desc,
                    style: const TextStyle(fontSize: 12, color: SnowStyle.muted,
                        height: 1.5)),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF1F2F5),
                      borderRadius: BorderRadius.circular(10)),
                  child: SelectableText(code,
                      style: const TextStyle(
                          fontFamily: 'Menlo', fontSize: 11, height: 1.5)),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '复制命令',
            onPressed: () => _copy(code),
            icon: const Icon(Icons.copy_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}