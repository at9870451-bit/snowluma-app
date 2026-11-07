import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../core/app_state.dart';
import '../core/snow_theme.dart';

/// 本地部署 — 纯本地页面，不依赖服务器新增接口。
///
/// 内容：
///   1. 部署状态（复用已有 /api/status 连接检测，仅检测当前服务器连通）
///   2. Rootfs 管理：本地部署目标目录结构说明
///   3. 沙盒创建：一键复制服务器命令
///   4. 环境组件：BusyBox / musl / Python / Node.js / OpenSSL / Git 清单
///   5. SnowLuma + QQBot 本地部署向导（命令可复制）
class LocalPage extends StatefulWidget {
  const LocalPage({super.key});

  @override
  State<LocalPage> createState() => _LocalPageState();
}

class _LocalPageState extends State<LocalPage> {
  Map<String, dynamic>? _status;
  bool _checking = true;
  String? _err;

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

  bool _exporting = false;

  /// 把内置的离线部署包导出到 App 文档目录（iOS 可在「文件」App 里看到）。
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
          content: Text('已导出（${(data.lengthInBytes / 1024 / 1024).toStringAsFixed(1)} MB）到「文件」App：${file.path}'),
          duration: const Duration(seconds: 5),
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
    final running = _status?['running'] == true;
    final connected = _status?['connected'] == true;
    return Scaffold(
      backgroundColor: SnowStyle.background,
      appBar: AppBar(title: const Text('本地部署')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
              children: [
                const Text('LOCAL DEPLOY',
                    style: TextStyle(fontSize: 11, letterSpacing: 2,
                        color: SnowStyle.muted, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text('本地部署工坊',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800,
                        letterSpacing: -0.8)),
                const SizedBox(height: 6),
                const Text('在服务器或沙盒里搭建 SnowLuma + QQBot，全部命令可复制。',
                    style: TextStyle(color: SnowStyle.muted, fontSize: 13, height: 1.5)),
                const SizedBox(height: 18),
                _statusBanner(running, connected),
                const SizedBox(height: 16),
                _section('连接信息'),
                _row('服务器地址', appState.baseUrl.isEmpty ? '未连接' : appState.baseUrl),
                _row('控制面板', 'http://$_host:6199'),
                _row('AI 网关', 'http://$_host:8090'),
                const SizedBox(height: 16),
                _section('Rootfs 管理'),
                _copyCard(
                  '目标 Rootfs 结构',
                  '本地部署机器人的标准目录布局：\n'
                  '/opt/qqbot          # QQBot 服务（主程序+配置+数据）\n'
                  '/opt/sandbox       # 沙盒 rootfs（环境组件）\n'
                  '  ├─ bin/          # busybox 软链\n'
                  '  ├─ usr/bin/      # python3 / node / openssl\n'
                  '  ├─ etc/          # 配置文件\n'
                  '  ├─ opt/          # 应用\n'
                  '  └─ tmp/          # 临时文件',
                  code: 'mkdir -p /opt/sandbox/{bin,usr/bin,etc,opt,root,tmp,home}',
                ),
                const SizedBox(height: 16),
                _section('沙盒添加'),
                _copyCard(
                  '创建沙盒 rootfs',
                  '在服务器上新建一个沙盒目录并安装核心组件。',
                  code: 'mkdir -p /opt/sandbox && cd /opt/sandbox\n'
                      'ln -s /usr/bin/python3 usr/bin/python3\n'
                      'ln -s /usr/bin/openssl usr/bin/openssl\n'
                      'ln -s /usr/bin/git usr/bin/git',
                ),
                const SizedBox(height: 16),
                _section('环境组件'),
                _componentsCard(),
                const SizedBox(height: 16),
                _section('iSH 沙盒部署（iPhone 当服务器）'),
                _copyCard(
                  '① 安装 iSH 并导出离线包',
                  'App Store 搜索安装 iSH（Alpine Linux 环境）。'
                  '然后回到本页点上方「导出」，把离线包存到「文件」App。',
                  code: 'iSH 内访问文件：mount -t ios . /mnt',
                ),
                _copyCard(
                  '② iSH 里一键安装',
                  '在 iSH 里进入离线包目录，解压并运行 iSH 专用安装脚本'
                  '（自动装 Python、解压 QQBot、装依赖、启动服务）：',
                  code: 'cd /mnt/你的离线包目录\n'
                      'tar -xzf snowluma-qqbot-offline.tar.gz\n'
                      'cd offline && sh ish-install.sh',
                ),
                _copyCard(
                  '③ App 连接本机沙盒',
                  'QQBot 启动后监听本机 6199，在 App「接入」页填写：',
                  code: 'http://127.0.0.1:6199',
                ),
                const SizedBox(height: 6),
                const Text(
                    '限制说明：iSH 里能跑 Python 版 QQBot（面板/插件/AI 逻辑），'
                    '但 NapCat（QQ 协议端）无法在 iSH 运行，QQ 消息收发需另配协议端；'
                    'iOS 会挂起长时间后台的 iSH，需要保持前台。',
                    style: TextStyle(fontSize: 11, color: SnowStyle.muted, height: 1.5)),
                const SizedBox(height: 16),
                _section('局域网部署（离线包）'),
                _exportCard(),
                _copyCard(
                  '① 下载离线包',
                  '在局域网设备（树莓派/NUC/家用服务器）的浏览器打开下面的地址，'
                  '或在电脑上下载后拷到目标设备：',
                  code: 'http://$_host:6199/static/snowluma-qqbot-offline.tar.gz',
                ),
                _copyCard(
                  '② 解压并安装',
                  '把离线包拷到目标设备，解压后执行安装脚本（会自动装 Docker、QQBot、'
                  'systemd 服务和沙盒目录）：',
                  code: 'tar -xzf snowluma-qqbot-offline.tar.gz\n'
                      'cd offline && sudo bash install.sh',
                ),
                _copyCard(
                  '③ App 连接局域网',
                  '安装完成后脚本会打印局域网 IP，在 App「接入」页填写面板地址，'
                  '即可连接本地机器人：',
                  code: 'http://<局域网IP>:6199',
                ),
                const SizedBox(height: 8),
                const Text(
                    '要求：目标设备为 Debian/Ubuntu 系 Linux，可访问 Docker Hub；'
                    '完全离线环境请先 docker save/load SnowLuma 镜像。',
                    style: TextStyle(fontSize: 11, color: SnowStyle.muted, height: 1.5)),
                const SizedBox(height: 8),
                const Text('提示：以上命令在服务器终端执行；本页只负责本地引导与复制。',
                    style: TextStyle(fontSize: 11, color: SnowStyle.muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
              style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            _checking
                ? '检查中…'
                : (_err != null
                    ? '连接失败：$_err'
                    : (ok ? '运行中 · QQ 已连接' : (running ? '运行中 · QQ 未连接' : '未运行'))),
            style: const TextStyle(color: Color(0xFFC5C7CF), fontSize: 12, height: 1.5),
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

  Widget _exportCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: SnowStyle.card(),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: SnowStyle.softAccent,
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.archive_outlined,
                size: 19, color: SnowStyle.accent),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('离线包已内置',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                SizedBox(height: 4),
                Text('安装脚本 + QQBot 程序，约 1.1 MB。导出后到 iOS「文件」App 取用，'
                    '拷到目标设备即可部署。',
                    style: TextStyle(
                        fontSize: 12, color: SnowStyle.muted, height: 1.45)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _exporting ? null : _exportOfflinePackage,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 34),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              visualDensity: VisualDensity.compact,
            ),
            child: _exporting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('导出', style: TextStyle(fontSize: 12)),
          ),
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
                    borderRadius: BorderRadius.circular(10),
                  ),
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

  Widget _componentsCard() {
    const comps = [
      ('BusyBox', '通用 Unix 工具箱（sh/ls/cp/df…）', '沙盒 bin/ 软链'),
      ('musl', '轻量 C 库（Alpine 基础）', '随 busybox 静态二进制'),
      ('Python', 'QQBot/插件运行环境', 'usr/bin/python3'),
      ('Node.js', 'NapCat/SnowLuma 网关', 'usr/bin/node'),
      ('OpenSSL', 'HTTPS/证书工具', 'usr/bin/openssl'),
      ('Git', '版本管理与插件源', 'usr/bin/git'),
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: SnowStyle.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final c in comps)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: SnowStyle.softAccent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.inventory_2_outlined,
                        size: 16, color: SnowStyle.accent),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 90,
                    child: Text(c.$1,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                  Expanded(
                    child: Text(c.$2,
                        style: const TextStyle(
                            fontSize: 11.5, color: SnowStyle.muted)),
                  ),
                  Text(c.$3,
                      style: const TextStyle(
                          fontSize: 10.5, color: SnowStyle.accent)),
                ],
              ),
            ),
        ],
      ),
    );
  }

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
}