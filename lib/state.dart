import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'models.dart';
import 'theme.dart';

/// 全局应用状态：服务端地址 + 登录态
class AppState extends ChangeNotifier {
  static final AppState instance = AppState._();
  AppState._();

  final MyProbeClient client =
      MyProbeClient('https://probe.suanran9527.com');
  bool ready = false;

  /// 是否遮挡 IP（截图分享用）
  bool hideIp = false;

  /// 探测目标上次选的省份（全局一个，持久化；null = 从未选过，用默认）
  String? probeRegion;

  /// 节点自定义标签（养鸡场式 pill，如「三网4837」）：服务端节点表
  /// 没有 tags 字段，存在本机 SharedPreferences（key mp_node_tags_<id>，
  /// 逗号分隔），管理页可编辑；换手机不跟随。
  final Map<String, List<String>> _nodeTags = {};

  List<String> nodeTags(String id) =>
      List.unmodifiable(_nodeTags[id] ?? const []);

  Future<void> setNodeTags(String id, List<String> tags) async {
    final clean = tags
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (clean.isEmpty) {
      _nodeTags.remove(id);
    } else {
      _nodeTags[id] = clean;
    }
    final p = await SharedPreferences.getInstance();
    if (clean.isEmpty) {
      await p.remove('mp_node_tags_$id');
    } else {
      await p.setString('mp_node_tags_$id', clean.join(','));
    }
    notifyListeners();
  }

  /// 当前界面主题 id（持久化；默认 bocchi 波奇酱）
  String themeId = AppThemeDef.bocchi.id;
  AppThemeDef get themeDef => AppThemeDef.byId(themeId);

  /// 雨滴效果档位（持久化）：0=关 1=静态水滴 2=动态滑落。
  /// 默认 1（静态）：升级后立刻能看到效果，又不费电；不想要随时关。
  int rainMode = 1;

  /// 性能模式（持久化，借鉴 Folia 0.7.22 的手机性能模式）：开后关掉
  /// 毛玻璃模糊、卡片阴影、在线呼吸与入场动效，只留配色，低端机/省电优先。
  bool perfMode = false;

  Future<void> init() async {
    await client.load();
    final p = await SharedPreferences.getInstance();
    hideIp = p.getBool('mp_hide_ip') ?? false;
    probeRegion = p.getString('mp_probe_region');
    for (final k in p
        .getKeys()
        .where((k) => k.startsWith('mp_node_tags_'))) {
      final id = k.substring('mp_node_tags_'.length);
      final tags = (p.getString(k) ?? '')
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (tags.isNotEmpty) _nodeTags[id] = tags;
    }
    themeId = p.getString('mp_theme_id') ?? AppThemeDef.bocchi.id;
    rainMode = p.getInt('mp_rain_mode') ?? 1;
    perfMode = p.getBool('mp_perf_mode') ?? false;
    BocchiTheme.current = themeDef;
    BocchiTheme.performanceMode = perfMode;
    ready = true;
    notifyListeners();
  }

  Future<void> setTheme(String id) async {
    themeId = id;
    BocchiTheme.current = themeDef;
    final p = await SharedPreferences.getInstance();
    await p.setString('mp_theme_id', id);
    notifyListeners();
  }

  Future<void> setPerfMode(bool v) async {
    perfMode = v;
    BocchiTheme.performanceMode = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool('mp_perf_mode', v);
    notifyListeners();
  }

  Future<void> setRainMode(int mode) async {
    rainMode = mode;
    final p = await SharedPreferences.getInstance();
    await p.setInt('mp_rain_mode', mode);
    notifyListeners();
  }

  Future<void> setProbeRegion(String region) async {
    probeRegion = region;
    final p = await SharedPreferences.getInstance();
    await p.setString('mp_probe_region', region);
    notifyListeners();
  }

  Future<void> toggleHideIp() async {
    hideIp = !hideIp;
    final p = await SharedPreferences.getInstance();
    await p.setBool('mp_hide_ip', hideIp);
    notifyListeners();
  }

  /// 显示用 IP（遮挡时全打码）
  String showIp(String ip) {
    if (ip.isEmpty) return '--';
    return hideIp ? '••••••••' : ip;
  }

  Future<void> setServer(String u) async {
    await client.saveServer(u);
    client.admin = false;
    notifyListeners();
  }

  Future<void> login(String user, String pass) async {
    await client.login(user, pass);
    notifyListeners();
  }

  Future<void> logout() async {
    await client.logout();
    notifyListeners();
  }

  int tabIndex = 0;
  void goTab(int i) {
    tabIndex = i;
    notifyListeners();
  }

  /// 详情页 💻 点过来：跳终端 Tab 并自动弹出该节点的连接框
  ProbeNode? pendingTerminalNode;
  void openTerminalFor(ProbeNode n) {
    pendingTerminalNode = n;
    tabIndex = 2;
    notifyListeners();
  }

  /// 终端 Tab 消费掉待处理的节点（只消费一次）
  ProbeNode? consumeTerminalNode() {
    final n = pendingTerminalNode;
    pendingTerminalNode = null;
    return n;
  }
}
