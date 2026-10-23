import 'package:flutter/material.dart';
import 'theme.dart';
import 'state.dart';
import 'widgets/widgets.dart';
import 'pages/nodes_page.dart';
import 'pages/probes_page.dart';
import 'pages/terminal_page.dart';
import 'pages/settings_page.dart';

void main() {
  runApp(const MyProbeApp());
}

class MyProbeApp extends StatelessWidget {
  const MyProbeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (_, __) => MaterialApp(
        title: '探针',
        theme: BocchiTheme.themeDataFor(AppState.instance.themeDef),
        builder: (_, child) => AppBackground(
            // 背景层在 theme.dart、不能 import state（循环），档位从这里传
            rainMode: AppState.instance.rainMode,
            child: child ?? const SizedBox()),
        home: const _Boot(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class _Boot extends StatefulWidget {
  const _Boot();
  @override
  State<_Boot> createState() => _BootState();
}

class _BootState extends State<_Boot> {
  @override
  void initState() {
    super.initState();
    AppState.instance.init();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (_, __) {
        if (!AppState.instance.ready) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return const HomePage();
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (_, __) {
        final app = AppState.instance;
        final pages = [
          const NodesPage(),
          const ProbesPage(),
          const TerminalTab(),
          const SettingsPage(),
        ];
        return Scaffold(
          body: IndexedStack(index: app.tabIndex, children: pages),
          bottomNavigationBar: GlassBottomBar(
            child: BottomNavigationBar(
            backgroundColor: BocchiTheme.current.navBg,
            currentIndex: app.tabIndex,
            onTap: (i) => app.goTab(i),
            type: BottomNavigationBarType.fixed,
            items: [
              const BottomNavigationBarItem(
                  icon: Icon(Icons.dns_outlined),
                  activeIcon: Icon(Icons.dns),
                  label: '节点'),
              const BottomNavigationBarItem(
                  icon: Icon(Icons.speed_outlined),
                  activeIcon: Icon(Icons.speed),
                  label: '拨测'),
              const BottomNavigationBarItem(
                  icon: Icon(Icons.terminal_outlined),
                  activeIcon: Icon(Icons.terminal),
                  label: '终端'),
              BottomNavigationBarItem(
                icon: AppState.instance.client.admin
                    ? const Icon(Icons.admin_panel_settings)
                    : const Icon(Icons.settings_outlined),
                activeIcon: const Icon(Icons.settings),
                label: '设置',
              ),
            ],
            ),
          ),
        );
      },
    );
  }
}
