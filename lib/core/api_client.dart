import 'dart:convert';

import 'package:http/http.dart' as http;

import 'bridge.dart';

/// SnowLumaApiClient — SnowLuma WebUI HTTP API 客户端（Dart 传输层）
///
/// Rust Core 负责会话状态机/数据模型解析/动作构建校验；
/// 本类只负责 HTTP 传输与 bearer 头注入。
class SnowLumaApiClient {
  SnowLumaApiClient(this.baseUrl, this.token);

  final String baseUrl;
  String token;

  void setToken(String t) => token = t;

  Map<String, String> _headers([Map<String, String>? extra]) => {
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        if (extra != null) ...extra,
      };

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  // ---- 登录 / 登出 ----

  /// POST /api/login {password} → Rust 解析状态机
  Future<Map<String, dynamic>> login({
    required String password,
    String? totp,
    String? recoveryCode,
  }) async {
    final body = <String, dynamic>{'password': password};
    if (totp != null && totp.isNotEmpty) body['totp'] = totp;
    if (recoveryCode != null && recoveryCode.isNotEmpty) {
      body['recoveryCode'] = recoveryCode;
    }
    final resp = await http.post(
      _uri('/api/login'),
      headers: _headers({'Authorization': ''}),
      body: jsonEncode(body),
    );
    return SnowLumaBridge.call('auth.parse_login', {'body': _json(resp.body)});
  }

  Future<void> logout() async {
    try {
      await http.post(_uri('/api/logout'), headers: _headers());
    } catch (_) {}
  }

  // ---- 状态 ----

  Future<Map<String, dynamic>> status() async {
    final resp = await http.get(_uri('/api/status'), headers: _headers());
    return _json(resp.body);
  }

  /// GET /api/auth/state → { mustChangePassword }
  Future<Map<String, dynamic>> authState() async {
    final resp = await http.get(_uri('/api/auth/state'), headers: _headers());
    return SnowLumaBridge.call('auth.parse_state', {'body': _json(resp.body)});
  }

  // ---- 协议同意 ----

  /// GET /api/agreements → 版本 + 文档列表
  Future<Map<String, dynamic>> agreements() async {
    final resp = await http.get(_uri('/api/agreements'), headers: _headers());
    return SnowLumaBridge.call('agreement.parse', {'body': _json(resp.body)});
  }

  /// POST /api/agreements/record-consent {version}
  Future<Map<String, dynamic>> recordConsent(String version) async {
    final resp = await http.post(
      _uri('/api/agreements/record-consent'),
      headers: _headers(),
      body: jsonEncode({'version': version}),
    );
    return _json(resp.body);
  }

  // ---- 改密 ----

  /// 本地密码强度校验（Rust）
  static Map<String, dynamic> checkStrength(String password) =>
      SnowLumaBridge.call('password.check_strength', {'password': password});

  /// POST /api/auth/change-password
  Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final resp = await http.post(
      _uri('/api/auth/change-password'),
      headers: _headers(),
      body: jsonEncode({'oldPassword': oldPassword, 'newPassword': newPassword}),
    );
    return _json(resp.body);
  }

  // ---- QQ 账号 ----

  /// GET /api/qq-list → Rust 解析账号模型
  Future<Map<String, dynamic>> qqList() async {
    final resp = await http.get(_uri('/api/qq-list'), headers: _headers());
    return SnowLumaBridge.call('account.parse', {'body': _json(resp.body)});
  }

  // ---- OneBot 动作 ----

  /// GET /api/debug/actions → Rust 解析动作清单
  Future<Map<String, dynamic>> actions() async {
    final resp = await http.get(_uri('/api/debug/actions'), headers: _headers());
    return SnowLumaBridge.call('action.parse', {'body': _json(resp.body)});
  }

  /// POST /api/debug/invoke {uin, action, params}
  Future<Map<String, dynamic>> invoke({
    required int uin,
    required String action,
    required Map<String, dynamic> params,
  }) async {
    final built = SnowLumaBridge.call('invoke.build', {
      'uin': uin,
      'action': action,
      'params': params,
    });
    final resp = await http.post(
      _uri('/api/debug/invoke'),
      headers: _headers(),
      body: jsonEncode(built),
    );
    return _json(resp.body);
  }

  /// 发送私聊消息（send_private_msg）
  Future<Map<String, dynamic>> sendPrivateMsg({
    required int uin,
    required int target,
    required String text,
  }) async {
    final segments =
        SnowLumaBridge.call('action.message_segments', {'text': text});
    return invoke(
      uin: uin,
      action: 'send_private_msg',
      params: {'user_id': target, 'message': segments['value'] ?? segments},
    );
  }

  /// 发送群消息（send_group_msg）
  Future<Map<String, dynamic>> sendGroupMsg({
    required int uin,
    required int groupId,
    required String text,
  }) async {
    final segments =
        SnowLumaBridge.call('action.message_segments', {'text': text});
    return invoke(
      uin: uin,
      action: 'send_group_msg',
      params: {'group_id': groupId, 'message': segments['value'] ?? segments},
    );
  }

  /// 获取登录信息
  Future<Map<String, dynamic>> getLoginInfo(int uin) =>
      invoke(uin: uin, action: 'get_login_info', params: {});

  // ---- QQ 进程接入 ----

  /// 进程列表（服务器上检测到的 QQ 进程）
  Future<List<Map<String, dynamic>>> processes() async {
    final resp = await http.get(_uri('/api/processes'), headers: _headers());
    final body = _json(resp.body);
    return (body['list'] as List? ?? const []).cast<Map<String, dynamic>>();
  }

  /// 加载进程（接入 QQ 登录态）
  Future<Map<String, dynamic>> processLoad(String id) async {
    final resp = await http.post(
      _uri('/api/processes/$id/load'),
      headers: _headers(),
    );
    return _json(resp.body);
  }

  /// 卸载进程
  Future<Map<String, dynamic>> processUnload(String id) async {
    final resp = await http.post(
      _uri('/api/processes/$id/unload'),
      headers: _headers(),
    );
    return _json(resp.body);
  }

  /// 刷新进程（重新检测登录态）
  Future<Map<String, dynamic>> processRefresh(String id) async {
    final resp = await http.post(
      _uri('/api/processes/$id/refresh'),
      headers: _headers(),
    );
    return _json(resp.body);
  }

  Map<String, dynamic> _json(String body) =>
      (jsonDecode(body) as dynamic)?.cast<String, dynamic>() ?? {};

  // ---- AI 网关（/ai/config，无需 Bearer）----

  Future<Map<String, dynamic>> aiConfig() async {
    final resp = await http
        .get(_uri('/ai/config'))
        .timeout(const Duration(seconds: 15));
    return _json(resp.body);
  }

  Future<Map<String, dynamic>> aiSaveConfig(Map<String, dynamic> cfg) async {
    final resp = await http.post(
      _uri('/ai/config'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(cfg),
    ).timeout(const Duration(seconds: 15));
    return _json(resp.body);
  }
}
