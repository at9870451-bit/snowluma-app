import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
                _section('局域网部署（离线包）'),
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