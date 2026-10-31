import 'dart:convert';

import 'package:http/http.dart' as http;

/// QqbotClient — QQBot WebUI HTTP API 客户端（默认端口 6199，无鉴权）
///
/// 与 SnowLumaApiClient（8090 网关 / Bearer）区分开：
///   - SnowLumaApiClient：QQ 客户端控制 + AI 网关配置（8090）
///   - QqbotClient：QQBot 机器人大脑自带面板的全部管理 API（6199）
///
/// 返回体约定：成功 {ok:true, ...}，失败 4xx/5xx + {ok:false,error:"中文"} 或 {detail:"..."}
class QqbotClient {
  QqbotClient(this.baseUrl);

  /// QQBot 面板根地址，例如 http://1.2.3.4:6199
  final String baseUrl;

  static final http.Client _client = http.Client();

  /// 从 SnowLuma WebUI 的 baseUrl 推导 QQBot 面板地址：
  /// 主机名不变，端口换 6199
  factory QqbotClient.fromSnowLuma(String snowlumaBaseUrl) {
    try {
      final uri = Uri.parse(snowlumaBaseUrl);
      if (uri.host.isNotEmpty) return QqbotClient('http://${uri.host}:6199');
    } catch (_) {}
    return QqbotClient('http://154.12.16.204:6199');
  }

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<Map<String, dynamic>> _get(String path,
      {Duration timeout = const Duration(seconds: 12)}) async {
    final resp = await _client.get(_uri(path)).timeout(timeout);
    return _decode(resp);
  }

  Future<Map<String, dynamic>> _post(String path,
      {Object? body,
      Duration timeout = const Duration(seconds: 15)}) async {
    final resp = await _client
        .post(_uri(path),
            headers: {'Content-Type': 'application/json'},
            body: body == null ? '{}' : jsonEncode(body))
        .timeout(timeout);
    return _decode(resp);
  }

  Future<Map<String, dynamic>> _delete(String path) async {
    final resp = await _client.delete(_uri(path)).timeout(const Duration(seconds: 15));
    return _decode(resp);
  }

  Map<String, dynamic> _decode(http.Response resp) {
    try {
      final m = jsonDecode(resp.body);
      if (m is Map) {
        final out = m.cast<String, dynamic>();
        // detail 型错误（FastAPI 405/404）转成统一 error 字段
        if (resp.statusCode >= 400 && !out.containsKey('error')) {
          out['error'] = out['detail']?.toString() ?? 'HTTP ${resp.statusCode}';
        }
        if (!out.containsKey('ok') && resp.statusCode < 400) {
          out['ok'] = true;
        }
        return out;
      }
      return {'ok': resp.statusCode < 400, 'data': m};
    } catch (_) {
      return {
        'ok': false,
        'error': resp.statusCode >= 400
            ? 'HTTP ${resp.statusCode}'
            : '服务器返回格式异常',
      };
    }
  }

  /// 统一把错误转成可读文案
  static String errText(Map<String, dynamic> r) =>
      (r['error'] ?? r['msg'] ?? r['detail'] ?? '请求失败').toString();

  // ==================== P0 · 总览 ====================

  /// GET /api/status → {running, connected, backend, self_id, uptime, version, auth, plugins}
  Future<Map<String, dynamic>> status() => _get('/api/status');

  /// GET /api/logs?limit=N → {lines:["HH:MM:SS [LEVEL] logger: msg"]}
  Future<List<String>> logs({int limit = 200}) async {
    final r = await _get('/api/logs?limit=$limit');
    return ((r['lines'] as List?) ?? const []).map((e) => '$e').toList();
  }

  // ==================== P0 · 知识库 ====================

  Future<Map<String, dynamic>> kbOverview() => _get('/api/kb/overview');

  /// GET /api/kb/docs?group_id=X → {ok, docs:[{id,title,content,tags,updated_at}]}
  Future<List<Map<String, dynamic>>> kbDocs(num groupId) async {
    final r = await _get('/api/kb/docs?group_id=$groupId');
    return ((r['docs'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
  }

  Future<Map<String, dynamic>> kbAddDoc({
    required num groupId,
    required String content,
    String title = '',
    String tags = '',
  }) =>
      _post('/api/kb/docs', body: {
        'group_id': groupId,
        'content': content,
        'title': title,
        'tags': tags,
      });

  Future<Map<String, dynamic>> kbDeleteDoc(num id) => _delete('/api/kb/docs/$id');

  Future<Map<String, dynamic>> kbSearch({required String text, num? groupId}) =>
      _post('/api/kb/search',
          body: {'text': text, if (groupId != null) 'group_id': groupId});

  // ==================== P0 · 记忆库 ====================

  Future<Map<String, dynamic>> memoryOverview() => _get('/api/memory/overview');

  /// GET /api/memory[?scope=&group_id=&user_id=] → {ok, memories:[...]}
  Future<List<Map<String, dynamic>>> memories({
    String? scope,
    num? groupId,
    num? userId,
  }) async {
    final q = <String>[];
    if (scope != null && scope.isNotEmpty) q.add('scope=$scope');
    if (groupId != null) q.add('group_id=$groupId');
    if (userId != null) q.add('user_id=$userId');
    final r = await _get('/api/memory${q.isEmpty ? '' : '?${q.join('&')}'}');
    return ((r['memories'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
  }

  Future<Map<String, dynamic>> memoryAdd({
    required String content,
    String scope = 'global',
    num groupId = 0,
    num userId = 0,
  }) =>
      _post('/api/memory', body: {
        'content': content,
        'scope': scope,
        'group_id': groupId,
        'user_id': userId,
      });

  Future<Map<String, dynamic>> memoryDelete(num id) => _delete('/api/memory/$id');

  // ==================== P1 · 置控台（群管控） ====================

  /// GET /api/console/overview → {ok, groups:[{group_id,group_name,enabled,silenced,permanent,remaining,source,can_speak}]}
  Future<List<Map<String, dynamic>>> consoleGroups() async {
    final r = await _get('/api/console/overview');
    return ((r['groups'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
  }

  /// POST /api/console/group {group_id, silenced?, duration?...} → {ok, state}
  Future<Map<String, dynamic>> consoleSetGroup(
    String groupId, {
    bool? silenced,
    int? duration, // 秒
    bool? permanent,
    bool? enabled,
  }) =>
      _post('/api/console/group', body: {
        'group_id': groupId,
        if (silenced != null) 'silenced': silenced,
        if (duration != null) 'duration': duration,
        if (permanent != null) 'permanent': permanent,
        if (enabled != null) 'enabled': enabled,
      });

  // ==================== P1 · 表情包 ====================

  /// GET /api/stickers → {ok, stickers:[{id,name,tags,size}], stats}
  Future<Map<String, dynamic>> stickers() => _get('/api/stickers');

  /// 表情原图 URL
  String stickerRawUrl(String id) => '$baseUrl/api/stickers/$id/raw';

  Future<Map<String, dynamic>> stickerDelete(String id) =>
      _delete('/api/stickers/$id');

  // ==================== P1 · 插件 ====================

  /// GET /api/plugins → {loaded:[...], disabled:[...], ok?}
  Future<Map<String, dynamic>> plugins() => _get('/api/plugins');

  /// GET /api/plugins/<name>/detail
  Future<Map<String, dynamic>> pluginDetail(String name) =>
      _get('/api/plugins/$name/detail');

  /// POST /api/plugins/<name>/toggle {enabled} → {ok, enabled}
  Future<Map<String, dynamic>> pluginToggle(String name, bool enabled) =>
      _post('/api/plugins/$name/toggle', body: {'enabled': enabled});

  /// POST /api/plugins/<name>/reload
  Future<Map<String, dynamic>> pluginReload(String name) =>
      _post('/api/plugins/$name/reload', timeout: const Duration(seconds: 30));

  // ==================== P1 · 原始配置（AI / 生图只读展示） ====================

  /// GET /api/config → 完整配置（含 ai / image / custom 等段）
  Future<Map<String, dynamic>> config() => _get('/api/config');
}
