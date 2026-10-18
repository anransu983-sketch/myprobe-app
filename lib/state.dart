import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';

/// 全局应用状态：服务端地址 + 登录态
class AppState extends ChangeNotifier {
  static final AppState instance = AppState._();
  AppState._();

  final MyProbeClient client =
      MyProbeClient('https://probe.suanran9527.com');
  bool ready = false;

  /// 是否遮挡 IP（截图分享用）
  bool hideIp = false;

  Future<void> init() async {
    await client.load();
    final p = await SharedPreferences.getInstance();
    hideIp = p.getBool('mp_hide_ip') ?? false;
    ready = true;
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
}
