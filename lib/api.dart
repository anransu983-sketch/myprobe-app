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
      String method, String path, Map<String, dynamic> body,
      {Duration timeout = const Duration(seconds: 15)}) async {
    final uri = Uri.parse('$baseUrl$path');
    final req = http.Request(method, uri);
    req.headers.addAll(_headers);
    req.headers['Content-Type'] = 'application/json';
    req.body = json.encode(body);
    final streamed = await _http.send(req).timeout(timeout);
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

  // ---------- v6.7：节点详情新数据（公开只读） ----------

  /// 三网延迟：{telecom/unicom/mobile: {ts(ms), lat, loss, latest}}
  Future<Map<String, dynamic>> getNetq(String nid) async {
    final j = await _get('/api/netq/$nid', {'range': '24h'})
        as Map<String, dynamic>;
    return (j['netq'] as Map?)?.cast<String, dynamic>() ?? {};
  }

  /// MTR 逐跳：{target: {ts, hops: [{n, host, loss, avg}], signature}}
  Future<Map<String, dynamic>> getMtr(String nid) async {
    final j = await _get('/api/mtr/$nid') as Map<String, dynamic>;
    return (j['mtr'] as Map?)?.cast<String, dynamic>() ?? {};
  }

  /// 解锁检测：[{service, ts, ok, code}]
  Future<List<Map<String, dynamic>>> getUnlock(String nid) async {
    final j = await _get('/api/unlock/$nid') as Map<String, dynamic>;
    return (j['unlock'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  }

  /// 在线状态：{days, since(s), now(s), online, events: [{ts, event}]}
  Future<Map<String, dynamic>> getUptime(String nid) async {
    return await _get('/api/uptime/$nid', {'days': '7'})
        as Map<String, dynamic>;
  }

  /// 硬盘写满预测：{slope_per_day, days_left, latest, note?}
  Future<Map<String, dynamic>> getDiskForecast(String nid) async {
    return await _get('/api/disk-forecast/$nid') as Map<String, dynamic>;
  }

  // ---------- v6.7 管理：账单 ----------

  Future<List<Map<String, dynamic>>> billingList() async {
    final j = await _get('/api/admin/billing') as Map<String, dynamic>;
    return (j['billing'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  }

  /// 按商家汇总每月花费：{vendor: [{currency, monthly}]}
  Future<Map<String, dynamic>> billingSummary() async {
    final j = await _get('/api/admin/billing/summary')
        as Map<String, dynamic>;
    return (j['summary'] as Map?)?.cast<String, dynamic>() ?? {};
  }

  Future<void> billingSave(
      {int? id, required Map<String, dynamic> d}) {
    return id == null
        ? _sendJson('POST', '/api/admin/billing', d)
        : _sendJson('PUT', '/api/admin/billing/$id', d);
  }

  Future<void> billingDelete(int id) =>
      _sendJson('DELETE', '/api/admin/billing/$id', {});

  // ---------- v6.7 管理：域名 ----------

  Future<List<Map<String, dynamic>>> domainsList() async {
    final j = await _get('/api/admin/domains') as Map<String, dynamic>;
    return (j['domains'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  }

  Future<void> domainSave(
      {int? id, required Map<String, dynamic> d}) {
    return id == null
        ? _sendJson('POST', '/api/admin/domains', d)
        : _sendJson('PUT', '/api/admin/domains/$id', d);
  }

  Future<void> domainDelete(int id) =>
      _sendJson('DELETE', '/api/admin/domains/$id', {});

  /// RDAP 自动拉到期日，返回新的 expire_date（YYYY-MM-DD）
  Future<String> domainRdap(int id) async {
    final j = await _sendJson('POST', '/api/admin/domains/$id/rdap', {});
    return '${j['expire_date']}';
  }

  // ---------- v6.7 管理：运行周报 ----------

  Future<Map<String, dynamic>> weeklyGet() async {
    return await _get('/api/admin/weekly') as Map<String, dynamic>;
  }

  Future<void> weeklySave(
      {required bool enabled, required String channel}) =>
      _sendJson('POST', '/api/admin/weekly',
          {'enabled': enabled, 'channel': channel});

  Future<void> weeklyTest() =>
      _sendJson('POST', '/api/admin/weekly/test', {});

  // ---------- v6.7 管理：AI 分析 ----------

  /// {endpoint, model, configured}
  Future<Map<String, dynamic>> aiGet() async {
    return await _get('/api/admin/ai') as Map<String, dynamic>;
  }

  /// key 为空 = 保持原值（服务端永不回显）
  Future<void> aiSave(
          {required String endpoint,
          required String model,
          required String key}) =>
      _sendJson('POST', '/api/admin/ai',
          {'endpoint': endpoint, 'model': model, 'key': key});

  /// 服务端调模型最长 90 秒，客户端超时放宽到 100 秒
  Future<String> aiAnalyze(String nid) async {
    final j = await _sendJson('POST', '/api/admin/ai/analyze',
        {'node_id': nid},
        timeout: const Duration(seconds: 100));
    return '${j['analysis'] ?? ''}';
  }

  // ---------- v6.7 管理：两步验证 ----------

  /// {enabled, configured}
  Future<Map<String, dynamic>> totpGet() async {
    return await _get('/api/admin/totp') as Map<String, dynamic>;
  }

  /// 生成 secret（已配时返回现有）+ otpauth 链接
  Future<Map<String, dynamic>> totpSetup() async {
    return await _sendJson('POST', '/api/admin/totp/setup', {});
  }

  /// 验证通过即开启，返回 8 个备用码（只显示一次）
  Future<List<String>> totpVerify(String code) async {
    final j = await _sendJson(
        'POST', '/api/admin/totp/verify', {'code': code});
    return ((j['backup_codes'] as List?) ?? [])
        .map((e) => '$e')
        .toList();
  }

  Future<void> totpDisable() =>
      _sendJson('POST', '/api/admin/totp/disable', {});

  // ---------- v6.7 管理：操作审计 ----------

  Future<List<Map<String, dynamic>>> auditList({int limit = 100}) async {
    final j = await _get('/api/admin/audit', {'limit': '$limit'})
        as Map<String, dynamic>;
    return (j['audit'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  }

  // ---------- v6.7 管理：公开 API 令牌 ----------

  /// [{id, name, created, last_used}]（不含明文）
  Future<List<Map<String, dynamic>>> apiTokensList() async {
    final j = await _get('/api/admin/api-tokens') as Map<String, dynamic>;
    return (j['tokens'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  }

  /// 创建后返回 {id, token}，明文只出现这一次
  Future<Map<String, dynamic>> apiTokenCreate(String name) async {
    return await _sendJson('POST', '/api/admin/api-tokens', {'name': name});
  }

  Future<void> apiTokenDelete(int id) =>
      _sendJson('DELETE', '/api/admin/api-tokens/$id', {});

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

  /// 新建节点占位（v1.11.0，需服务端 v6.5+）：节点先存入服务器，
  /// 之后 nodeMeta 补 SSH 凭据；agent 首次上报时自动补全主机信息。
  Future<void> nodeCreate(String id, String name) async {
    try {
      await _sendJson('POST', '/api/admin/nodes', {'id': id, 'name': name});
    } on ApiError {
      rethrow;
    } catch (_) {
      // 老服务端没有这个接口（返回 HTML 404，JSON 解析失败落到这里）
      throw ApiError('服务端版本太旧，请先把服务端升级到 v6.5 再新增 VPS');
    }
  }

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
