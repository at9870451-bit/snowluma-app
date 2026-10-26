import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'bridge.dart';

/// AppState — 全局连接状态（登录流程编排：登录 → 协议同意 → 改初始密码 → 重登）
class AppState extends ChangeNotifier {
  String baseUrl = '';
  String token = '';
  SnowLumaApiClient? client;

  /// 是否已可用（token 有效）
  bool get connected => token.isNotEmpty;
  /// 服务器地址显示名
  String get serverLabel => baseUrl.isEmpty ? '未连接' : baseUrl;

  /// 初始化：载入 Rust 里受保护存储的会话
  Future<void> init({required String dataDir, String? storedBase, String? storedToken}) async {
    await SnowLumaBridge.init(dataDir);
    try {
      final saved = SnowLumaBridge.call('session.load');
      if (saved['exists'] == true && (saved['token'] as String).isNotEmpty) {
        baseUrl = saved['baseUrl'] as String;
        token = saved['token'] as String;
        client = SnowLumaApiClient(baseUrl, token);
        notifyListeners();
        return;
      }
    } catch (_) {}
    if (storedBase != null && storedBase.isNotEmpty) baseUrl = storedBase;
  }

  /// 记住服务器地址（未登录也记住）
  Future<void> rememberServer(String url) async {
    baseUrl = SnowLumaBridge.call('session.normalize', {'url': url})['url'] as String;
    notifyListeners();
  }

  /// 完整连接流程
  ///
  /// 1. POST /api/login → token
  /// 2. 若 need_consent：GET agreements + record-consent
  /// 3. 若 need_change_password：changePassword + 重新登录
  /// 4. token 受保护持久化
  Future<ConnectResult> connect({
    required String url,
    required String password,
    String? newPassword,
  }) async {
    try {
      await rememberServer(url);
      final c = SnowLumaApiClient(baseUrl, '');
      final r1 = await c.login(password: password);
      final state1 = r1['state'] as String;
      if (state1 == 'invalid' || state1 == 'need_totp') {
        return ConnectResult.fail(r1['message'] as String? ?? '登录失败，请检查密码');
      }

      var token = r1['token'] as String;
      c.setToken(token);

      // 2. 协议同意
      await ensureConsent(c);

      // 3. 初始密码修改
      if (state1 == 'need_change_password' || (await c.authState())['mustChangePassword'] == true) {
        final np = newPassword?.trim() ?? '';
        if (np.isEmpty) {
          return ConnectResult.fail('该服务器要求首次修改初始密码，请填写新密码');
        }
        final strength = SnowLumaBridge.call('password.check_strength', {'password': np});
        if (strength['valid'] != true) {
          return ConnectResult.fail('新密码强度不足：至少 8 位且含大小写、数字、符号');
        }
        final ch = await c.changePassword(oldPassword: password, newPassword: np);
        if (ch['success'] != true) {
          return ConnectResult.fail('改密失败：${ch['message'] ?? ''}');
        }
        // 重新登录
        final r2 = await c.login(password: np);
        if (r2['state'] != 'ready') {
          return ConnectResult.fail('改密后登录失败：${r2['message'] ?? r2['state']}');
        }
        token = r2['token'] as String;
        c.setToken(token);
      }


      await SnowLumaBridge.call('session.save', {'baseUrl': baseUrl, 'token': token});
      this.token = token;
      this.client = c;
      notifyListeners();
      return ConnectResult.success();
    } catch (e) {
      return ConnectResult.fail(_fmt(e));
    }
  }

  /// 协议同意（若需要）
  Future<bool> ensureConsent(SnowLumaApiClient c) async {
    try {
      final ag = await c.agreements();
      if (ag['consentRequired'] != true) return true;
      final version = ag['version'] as String? ?? '';
      if (version.isEmpty) return true;
      final rc = await c.recordConsent(version);
      return rc['success'] == true;
    } catch (_) {
      return false;
    }
  }

  /// 退出登录（清 Rust 会话）
  Future<void> disconnect() async {
    try {
      await client?.logout();
    } catch (_) {}
    token = '';
    client = null;
    try {
      SnowLumaBridge.call('session.clear');
    } catch (_) {}
    notifyListeners();
  }

  String _fmt(Object e) {
    if (e is Exception) return e.toString();
    return '$e';
  }
}

/// 全局 AppState 实例（main.dart 注入依赖树）
final appState = AppState();

/// 连接结果
class ConnectResult {
  final bool ok;
  final String message;
  const ConnectResult._(this.ok, this.message);
  static ConnectResult success() => const ConnectResult._(true, '连接成功');
  static ConnectResult fail(String m) => ConnectResult._(false, m);
}
