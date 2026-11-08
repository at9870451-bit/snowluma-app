import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../core/app_state.dart';
import '../core/snow_theme.dart';
import 'ish_sandbox_page.dart';

/// 本地部署 — AstrBot 风格顶部 4 Tab：
///   总览：服务器状态与连接信息
///   沙盒：iSH 内嵌 Linux 沙盒入口与说明
///   部署：局域网离线部署（离线包导出 + 安装命令）
///   组件：运行环境组件清单
class LocalPage extends StatefulWidget {
  const LocalPage({super.key});

  @override
  State<LocalPage> createState() => _LocalPageState();
}

class _LocalPageState extends State<LocalPage> {
  Map<String, dynamic>? _status;
  bool _checking = true;
  String? _err;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _err = null;
    });
    try {
      final api = appState.client;
      if (api == null) {
        if (mounted) {
          setState(() {
            _checking = false;
            _err = '尚未连接服务器';
          });
        }
        return;
      }
      final r = await api.status();
      if (!mounted) return;
      setState(() {
        _status = r;
        _checking = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _err = e.toString();
      });
    }
  }

  String get _host {
    final u = Uri.tryParse(appState.baseUrl);
    return (u != null && u.host.isNotEmpty) ? u.host : '服务器IP';
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('已复制到剪贴板')));
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
              Tab(text: '总览'),
              Tab(text: '沙盒'),
              Tab(text: '部署'),
              Tab(text: '组件'),
            ],
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: TabBarView(
                children: [
                  _overviewTab(),
                  _sandboxTab(),
                  _deployTab(),
                  _componentsTab(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------- Tab 1 总览 ----------

  Widget _overviewTab() {
    final running = _status?['running'] == true;
    final connected = _status?['connected'] == true;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      children: [
        const Text('LOCAL DEPLOY',
            style: TextStyle(fontSize: 11, letterSpacing: 2,
                color: SnowStyle.muted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text('总览',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800,
                letterSpacing: -0.8)),
        const SizedBox(height: 16),
        _statusBanner(running, connected),
        const SizedBox(height: 16),
        _section('连接信息'),
        _row('服务器地址', appState.baseUrl.isEmpty ? '未连接' : appState.baseUrl),
        _row('控制面板', 'http://$_host:6199'),
        _row('AI 网关', 'http://$_host:8090'),
        _row('QQ 接入', 'ws://$_host:3001'),
      ],
    );
  }

  // ---------- Tab 2 沙盒 ----------

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

  // ---------- Tab 3 部署 ----------

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
          '安装脚本 + QQBot 程序 + go-cqhttp，导出后到 iOS「文件」App 取用。',
          icon: Icons.archive_outlined,
          action: OutlinedButton(
            onPressed: _exporting ? null : _exportOfflinePackage,
            child: Text(_exporting ? '导出中…' : '导出'),
          ),
        ),
        const SizedBox(height: 10),
        _copyCard(
          '局域网设备安装',
          '把离线包拷到 Linux 设备（树莓派/NUC）执行：',
          code: 'tar -xzf snowluma-qqbot-offline.tar.gz\n'
              'cd offline && sudo bash install.sh',
        ),
        const SizedBox(height: 10),
        _copyCard(
          'iSH（iPhone）安装',
          '在 iSH 里解压并运行安装脚本：',
          code: 'cd /mnt/你的离线包目录\n'
              'tar -xzf snowluma-qqbot-offline.tar.gz\n'
              'cd offline && sh ish-install.sh',
        ),
        const SizedBox(height: 10),
        _copyCard(
          '一键部署 NapCat + AstrBot（Linux）',
          '在服务器/树莓派上一条命令部署 QQ 协议端 NapCat 和机器人框架 AstrBot：',
          code: 'sudo bash install-napcat-astrbot.sh',
        ),
      ],
    );
  }

  // ---------- Tab 4 组件 ----------

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

  // ---------- 通用组件 ----------

  Widget _statusBanner(bool running, bool connected) {
    final ok = running && connected;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: SnowStyle.card(color: SnowStyle.ink, radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 9, height: 9, decoration: BoxDecoration(
              color: ok ? const Color(0xFF9BD1B1) : const Color(0xFFB9A795),
              shape: BoxShape.circle)),
            const SizedBox(width: 8),
            const Expanded(child: Text('SERVER STATUS',
                style: TextStyle(color: Color(0xFFB5B8C2), fontSize: 10,
                    letterSpacing: 1.4, fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 14),
          const Text('部署状态',
              style: TextStyle(color: Colors.white, fontSize: 21,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            _checking
                ? '检查中…'
                : (_err != null
                    ? '连接失败：$_err'
                    : (ok ? '运行中 · QQ 已连接' : (running ? '运行中 · QQ 未连接' : '未运行'))),
            style: const TextStyle(color: Color(0xFFC5C7CF), fontSize: 12,
                height: 1.5),
          ),
        ],
      ),
    );
  }

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