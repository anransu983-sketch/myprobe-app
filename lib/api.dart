import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class NeedLogin implements Exception {}

class ApiError implements Exception {
  final String message;
  ApiError(this.message);
  @override
  String toString() => message;
}

/// MyProbe 服务端客户端：公开接口免登录，/api/admin/* 需要先 login()
class MyProbeClient {
  static const _kServer = 'mp_server';
  static const _kCookie = 'mp_cookie';
  static const _kUser = 'mp_user';

  String baseUrl;
  String? _cookie;
  String? username;
  bool admin = false;

  final http.Client _http = http.Client();

  MyProbeClient(this.baseUrl);

  static String normalize(String u) {
    u = u.trim();
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'https://$u';
    }
    return u.replaceAll(RegExp(r'/+$'), '');
  }

  Map<String, String> get _headers => {
        'User-Agent': 'MyProbeApp/1.0',
        if (_cookie != null) 'Cookie': _cookie!,
      };

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    baseUrl = p.getString(_kServer) ?? baseUrl;
    _cookie = p.getString(_kCookie);
    username = p.getString(_kUser);
    if (_cookie != null) {
      try {
        admin = await _checkAdmin();
      } catch (_) {
        admin = false;
      }
    }
  }

  Future<void> saveServer(String u) async {
    baseUrl = normalize(u);
    final p = await SharedPreferences.getInstance();
    await p.setString(_kServer, baseUrl);
  }

  Future<dynamic> _get(String path, [Map<String, String>? q]) async {
    final uri =
        Uri.parse('$baseUrl$path').replace(queryParameters: q);
    final r = await _http.get(uri, headers: _headers).timeout(
          const Duration(seconds: 15),
        );
    if (r.statusCode == 401) throw NeedLogin();
    if (r.statusCode != 200) {
      throw ApiError('请求失败 (${r.statusCode})');
    }
    final j = json.decode(r.body);
    if (j is Map && j['ok'] == false) {
      throw ApiError('${j['error'] ?? '未知错误'}');
    }
    return j;
  }

  Future<Map<String, dynamic>> _sendJson(
      String method, String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$path');
    final req = http.Request(method, uri);
    req.headers.addAll(_headers);
    req.headers['Content-Type'] = 'application/json';
    req.body = json.encode(body);
    final streamed = await _http.send(req).timeout(
          const Duration(seconds: 15),
        );
    final r = await http.Response.fromStream(streamed);
    if (r.statusCode == 401) throw NeedLogin();
    final j = json.decode(r.body) as Map<String, dynamic>;
    if (j['ok'] != true) throw ApiError('${j['error'] ?? '操作失败'}');
    return j;
  }

  // ---------- 公开接口 ----------

  Future<List<ProbeNode>> getNodes() async {
    final j = await _get('/api/nodes') as Map<String, dynamic>;
    return ((j['nodes'] as List?) ?? [])
        .map((e) => ProbeNode.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<HistoryData> getHistory(String nid, String range) async {
    final j = await _get('/api/history/$nid', {'range': range})
        as Map<String, dynamic>;
    return HistoryData.fromJson(j);
  }

  Future<List<Map<String, dynamic>>> getTrafficDaily(
      String nid, int days) async {
    final j = await _get('/api/traffic/daily',
        {'node_id': nid, 'days': '$days'}) as Map<String, dynamic>;
    return (((j['days'] as List?) ?? []).cast<Map<String, dynamic>>());
  }

  Future<List<ProbeTask>> getProbes() async {
    final j = await _get('/api/probes') as Map<String, dynamic>;
    return ((j['tasks'] as List?) ?? [])
        .map((e) => ProbeTask.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---------- 登录 ----------

  Future<bool> _checkAdmin() async {
    try {
      final j = await _get('/api/me') as Map<String, dynamic>;
      return j['admin'] == true;
    } catch (_) {
      return false;
    }
  }

  /// 表单 POST /login，成功 302 并带 session cookie
  Future<void> login(String user, String pass) async {
    final req = http.Request('POST', Uri.parse('$baseUrl/login'));
    req.followRedirects = false;
    req.headers['Content-Type'] = 'application/x-www-form-urlencoded';
    req.bodyFields = {'username': user.trim(), 'password': pass};
    req.headers['User-Agent'] = 'MyProbeApp/1.0';
    final streamed =
        await _http.send(req).timeout(const Duration(seconds: 15));
    final r = await http.Response.fromStream(streamed);
    final sc = r.headers['set-cookie'];
    if (sc != null && sc.isNotEmpty) {
      _cookie = sc.split(';').first.trim();
    }
    if (_cookie == null) throw ApiError('登录失败：用户名或密码错误');
    admin = await _checkAdmin();
    if (!admin) {
      _cookie = null;
      throw ApiError('登录失败：用户名或密码错误');
    }
    username = user.trim();
    final p = await SharedPreferences.getInstance();
    await p.setString(_kCookie, _cookie!);
    await p.setString(_kUser, username!);
  }

  Future<void> logout() async {
    try {
      await _get('/logout');
    } catch (_) {}
    _cookie = null;
    username = null;
    admin = false;
    final p = await SharedPreferences.getInstance();
    await p.remove(_kCookie);
    await p.remove(_kUser);
  }

  // ---------- 管理：拨测任务 ----------

  Future<List<ProbeTask>> adminProbes() async {
    final j = await _get('/api/admin/probes') as Map<String, dynamic>;
    return ((j['tasks'] as List?) ?? [])
        .map((e) => ProbeTask.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> probeCreate(Map<String, dynamic> d) =>
      _sendJson('POST', '/api/admin/probes', d);

  Future<void> probeUpdate(int id, Map<String, dynamic> d) =>
      _sendJson('PUT', '/api/admin/probes/$id', d);

  Future<void> probeDelete(int id) =>
      _sendJson('DELETE', '/api/admin/probes/$id', {});

  Future<void> probeEnable(int id, bool on) async {
    final tasks = await adminProbes();
    final t = tasks.firstWhere((e) => e.id == id);
    await probeUpdate(id, {
      'name': t.name,
      'type': t.type,
      'host': t.host,
      'port': t.port ?? 0,
      'path': t.path ?? '',
      'interval': t.interval,
      'enabled': on,
    });
  }

  Future<Map<String, dynamic>> probeTest(int id) =>
      _sendJson('POST', '/api/admin/probes/$id/test', {});

  // ---------- 管理：节点 ----------

  Future<void> nodeRename(String nid, String name) =>
      _sendJson('POST', '/api/admin/node/$nid/rename', {'name': name});

  Future<void> nodeDelete(String nid) =>
      _sendJson('DELETE', '/api/admin/node/$nid', {});

  Future<void> nodesOrder(List<String> ids) =>
      _sendJson('POST', '/api/admin/nodes/order', {'order': ids});

  Future<void> nodeMeta(String nid, Map<String, dynamic> d) =>
      _sendJson('PUT', '/api/admin/node/$nid/meta', d);

  Future<String?> agentToken() async {
    final j = await _get('/api/admin/agent-token');
    if (j is Map && j['ok'] == true) {
      final t = j['token'];
      if (t is String && t.isNotEmpty) return t;
    }
    return null;
  }

  // ---------- 内置 SSH 终端 ----------

  Future<String> sshConnect(String nid,
      {String? password, int cols = 100, int rows = 30}) async {
    final j = await _sendJson('POST', '/api/admin/ssh/connect', {
      'node_id': nid,
      if (password != null && password.isNotEmpty)
        'password': password,
      'cols': cols,
      'rows': rows,
    });
    return '${j['session_id']}';
  }

  /// 直连任意主机（终端「快速连接」用，需服务端支持 host 参数）
  Future<String> sshConnectCustom(String host, int port,
      String user, String password) async {
    final j = await _sendJson('POST', '/api/admin/ssh/connect', {
      'host': host,
      'port': port,
      'username': user,
      'password': password,
    });
    return '${j['session_id']}';
  }

  Future<void> sshInput(String sid, String data) =>
      _sendJson('POST', '/api/admin/ssh/input',
          {'session_id': sid, 'data': data});

  /// 返回 {'data': 文本, 'closed': 是否断开}
  Future<Map<String, dynamic>> sshPoll(String sid) async {
    final j = await _get('/api/admin/ssh/poll',
        {'session_id': sid}) as Map<String, dynamic>;
    if (j['ok'] != true) {
      if (j['closed'] == true) return {'data': '', 'closed': true};
      throw ApiError('${j['error'] ?? '会话异常'}');
    }
    return {
      'data': '${j['data'] ?? ''}',
      'closed': j['closed'] == true
    };
  }

  Future<void> sshResize(String sid, int cols, int rows) =>
      _sendJson('POST', '/api/admin/ssh/resize',
          {'session_id': sid, 'cols': cols, 'rows': rows});

  Future<void> sshClose(String sid) =>
      _sendJson('POST', '/api/admin/ssh/close', {'session_id': sid});

  // ---------- 告警规则 ----------

  Future<List<Map<String, dynamic>>> alertRules() async {
    final j = await _get('/api/admin/rules') as Map<String, dynamic>;
    return (j['rules'] as List).cast<Map<String, dynamic>>();
  }

  Future<void> alertRuleSave({
    int? id,
    required String name,
    required String metric,
    required double threshold,
    required int duration,
    required bool enabled,
  }) {
    final body = {
      'name': name,
      'metric': metric,
      'threshold': threshold,
      'duration': duration,
      'enabled': enabled,
    };
    return id == null
        ? _sendJson('POST', '/api/admin/rules', body)
        : _sendJson('PUT', '/api/admin/rules/$id', body);
  }

  Future<void> alertRuleDelete(int id) =>
      _sendJson('DELETE', '/api/admin/rules/$id', {});

  // ---------- 通知渠道 ----------

  Future<List<Map<String, dynamic>>> alertChannels() async {
    final j = await _get('/api/admin/channels') as Map<String, dynamic>;
    return (j['channels'] as List).cast<Map<String, dynamic>>();
  }

  Future<void> alertChannelSave({
    int? id,
    required String type,
    required String name,
    required Map<String, dynamic> config,
    required bool enabled,
  }) {
    final body = {
      'type': type,
      'name': name,
      'config': config,
      'enabled': enabled,
    };
    return id == null
        ? _sendJson('POST', '/api/admin/channels', body)
        : _sendJson('PUT', '/api/admin/channels/$id', body);
  }

  Future<void> alertChannelDelete(int id) =>
      _sendJson('DELETE', '/api/admin/channels/$id', {});

  Future<void> alertChannelTest(int id) =>
      _sendJson('POST', '/api/admin/channels/$id/test', {});

  // ---------- 主题 ----------

  Future<List<Map<String, dynamic>>> themes() async {
    final j = await _get('/api/admin/themes') as Map<String, dynamic>;
    return (j['themes'] as List).cast<Map<String, dynamic>>();
  }

  Future<void> themeActivate(String tid) =>
      _sendJson('POST', '/api/admin/themes/$tid/activate', {});

  Future<void> themeDelete(String tid) =>
      _sendJson('DELETE', '/api/admin/themes/$tid', {});

  /// 上传主题 zip 包
  Future<void> themeUpload(String filePath) async {
    final uri = Uri.parse('$baseUrl/api/admin/themes/upload');
    final req = http.MultipartRequest('POST', uri);
    req.headers.addAll(_headers);
    req.files
        .add(await http.MultipartFile.fromPath('file', filePath));
    final streamed =
        await _http.send(req).timeout(const Duration(seconds: 60));
    final r = await http.Response.fromStream(streamed);
    if (r.statusCode == 401) throw NeedLogin();
    final j = json.decode(r.body) as Map<String, dynamic>;
    if (j['ok'] != true) throw ApiError('${j['error'] ?? '上传失败'}');
  }
}
