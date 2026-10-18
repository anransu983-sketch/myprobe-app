import 'package:flutter/foundation.dart';
import 'api.dart';

/// 全局应用状态：服务端地址 + 登录态
class AppState extends ChangeNotifier {
  static final AppState instance = AppState._();
  AppState._();

  final MyProbeClient client =
      MyProbeClient('https://probe.suanran9527.com');
  bool ready = false;

  Future<void> init() async {
    await client.load();
    ready = true;
    notifyListeners();
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
