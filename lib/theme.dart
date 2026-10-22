import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';

/// 一套主题的全部参数：配色 + 壁纸 + 玻璃参数。
/// 页面取色统一走 [BocchiTheme] 门面（历史命名），门面背后就是当前这套定义，
/// 所以切换主题时所有引用 BocchiTheme.xxx 的地方自动换色，页面代码不用改。
class AppThemeDef {
  final String id;
  final String name;
  final String desc;

  /// 主色（原 pinkDeep 的角色：选中态、关键数值、进度条）
  final Color accent;

  /// 主色之上的文字色（黄底用黑字、粉/品红底用白字）
  final Color onAccent;

  /// 次色（原 pink 的角色：装饰、阴影、渐变起点附近）
  final Color accent2;

  /// 浅底/轨道色（原 pinkLight 的角色：进度条轨道、胶囊底、边框）
  final Color track;

  /// 页面底色（原 pinkPale 的角色；玻璃主题仅作兜底，实际 Scaffold 透明）
  final Color scaffold;
  final Color text;
  final Color textSoft;
  final Color gradientStart;
  final Color gradientEnd;
  final Color cardColor;
  final Color cardBorder;
  final Color sheetColor;
  final Color navBg;
  final Color inputFill;

  /// 壁纸 asset 路径；null = 无壁纸（波奇酱）
  final String? wallpaper;

  /// 是否玻璃主题（壁纸打底 + 毛玻璃卡片）
  final bool glass;

  /// 背景层整体模糊 sigma（轻微，让壁纸退后）
  final double bgBlur;

  /// 节点卡 BackdropFilter 模糊 sigma
  final double cardBlur;

  /// 壁纸之上的压暗/提亮罩色
  final Color scrim;

  /// 进度条渐变（null = 单色 accent；黄昏主题用青→粉）
  final List<Color>? barGradient;

  final bool dark;

  const AppThemeDef({
    required this.id,
    required this.name,
    required this.desc,
    required this.accent,
    required this.onAccent,
    required this.accent2,
    required this.track,
    required this.scaffold,
    required this.text,
    required this.textSoft,
    required this.gradientStart,
    required this.gradientEnd,
    required this.cardColor,
    required this.cardBorder,
    required this.sheetColor,
    required this.navBg,
    required this.inputFill,
    this.wallpaper,
    this.glass = false,
    this.bgBlur = 0,
    this.cardBlur = 0,
    this.scrim = Colors.transparent,
    this.barGradient,
    this.dark = false,
  });

  static const AppThemeDef bocchi = AppThemeDef(
    id: 'bocchi',
    name: '波奇酱',
    desc: '粉色经典，默认主题',
    accent: Color(0xFFEC407A),
    onAccent: Colors.white,
    accent2: Color(0xFFF48FB1),
    track: Color(0xFFFCE4EC),
    scaffold: Color(0xFFFFF6F9),
    text: Color(0xFF4A3540),
    textSoft: Color(0xFF8A6D7A),
    gradientStart: Color(0xFFF06292),
    gradientEnd: Color(0xFFEC407A),
    cardColor: Colors.white,
    cardBorder: Color(0xFFFCE4EC),
    sheetColor: Colors.white,
    navBg: Colors.white,
    inputFill: Colors.white,
  );

  static const AppThemeDef nightcityGlass = AppThemeDef(
    id: 'nightcity_glass',
    name: '夜之城·毛玻璃',
    desc: '赛博朋克 2077：雨夜壁纸 + 深色毛玻璃 + 2077 黄',
    accent: Color(0xFFFCEE0A),
    onAccent: Color(0xFF111111),
    accent2: Color(0xFF00F0FF),
    track: Color(0xFF17333D),
    scaffold: Color(0xFF05090F),
    text: Color(0xFFF2FAFF),
    textSoft: Color(0xFF9FB8C6),
    gradientStart: Color(0xFF0B1E2A),
    gradientEnd: Color(0xFF123B47),
    cardColor: Color(0xC20B141D),
    cardBorder: Color(0x59FFFFFF),
    sheetColor: Color(0xF20B141D),
    navBg: Color(0xE60B141D),
    inputFill: Color(0xB3121E2A),
    wallpaper: 'assets/wallpapers/nightcity_glass.jpg',
    glass: true,
    bgBlur: 2.5,
    cardBlur: 14,
    scrim: Color(0x33040A12),
    dark: true,
  );

  static const AppThemeDef nightcityDusk = AppThemeDef(
    id: 'nightcity_dusk',
    name: '夜之城·黄昏',
    desc: '赛博朋克 2077：黄昏城市壁纸 + 浅色磨砂玻璃 + 品红粉',
    accent: Color(0xFFFF2A6D),
    onAccent: Colors.white,
    accent2: Color(0xFF00C2FF),
    track: Color(0xFFFFE3EF),
    scaffold: Color(0xFF2A1530),
    text: Color(0xFF33182B),
    textSoft: Color(0xFF86627A),
    gradientStart: Color(0xFF7E3FA3),
    gradientEnd: Color(0xFFFF2A6D),
    cardColor: Color(0xD9FFF7FB),
    cardBorder: Color(0x80FFFFFF),
    sheetColor: Color(0xF7FFF7FB),
    navBg: Color(0xEFFFF7FB),
    inputFill: Color(0xE6FFFFFF),
    wallpaper: 'assets/wallpapers/nightcity_dusk.jpg',
    glass: true,
    bgBlur: 2.5,
    cardBlur: 14,
    scrim: Color(0x14FFF0F6),
    barGradient: [Color(0xFF00C2FF), Color(0xFFFF2A6D)],
  );

  static const List<AppThemeDef> all = [bocchi, nightcityGlass, nightcityDusk];

  static AppThemeDef byId(String? id) {
    for (final t in all) {
      if (t.id == id) return t;
    }
    return bocchi;
  }
}

/// 历史取色门面：全 App 都引用这里的名字。
/// 值来自 [current]（当前主题定义）；波奇酱时与旧版常量逐值相同，零回归。
class BocchiTheme {
  static AppThemeDef current = AppThemeDef.bocchi;

  static Color get pink => current.accent2;
  static Color get pinkDeep => current.accent;
  static Color get pinkLight => current.track;
  static Color get pinkPale => current.scaffold;
  static Color get ink => current.text;
  static Color get inkSoft => current.textSoft;
  static Color get onAccent => current.onAccent;
  static Color get gradientStart => current.gradientStart;
  static Color get gradientEnd => current.gradientEnd;

  static const Color okGreen = Color(0xFF43A047);
  static const Color warnRed = Color(0xFFE53935);

  /// 波奇酱原 ThemeData（保持旧代码一字未动，默认主题走这里）
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFF48FB1),
      primary: const Color(0xFFEC407A),
      surface: Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(
        primary: const Color(0xFFEC407A),
        secondary: const Color(0xFFF48FB1),
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFFFFF6F9),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFEC407A),
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shadowColor: const Color(0xFFF48FB1).withValues(alpha: 0.25),
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFFCE4EC), width: 1),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFFEC407A),
        foregroundColor: Colors.white,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: Color(0xFFEC407A),
        unselectedItemColor: Color(0xFF8A6D7A),
        backgroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFCE4EC)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFCE4EC)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEC407A), width: 1.6),
        ),
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: Color(0xFF4A3540)),
        bodySmall: TextStyle(color: Color(0xFF8A6D7A)),
        titleMedium:
            TextStyle(color: Color(0xFF4A3540), fontWeight: FontWeight.w600),
      ),
    );
  }

  /// 按主题定义生成 ThemeData；波奇酱直接返回原 [light]。
  static ThemeData themeDataFor(AppThemeDef def) {
    if (def.id == AppThemeDef.bocchi.id) return light;
    final scheme = ColorScheme(
      brightness: def.dark ? Brightness.dark : Brightness.light,
      primary: def.accent,
      onPrimary: def.onAccent,
      secondary: def.accent2,
      onSecondary: def.onAccent,
      surface: def.cardColor,
      onSurface: def.text,
      error: warnRed,
      onError: Colors.white,
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: def.track),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: def.dark ? Brightness.dark : Brightness.light,
      colorScheme: scheme,
      // 透明：让 MaterialApp builder 里的壁纸层透出来
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: def.cardColor,
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.35),
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: def.cardBorder, width: 1),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: def.accent,
        foregroundColor: def.onAccent,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: def.accent,
        unselectedItemColor: def.textSoft,
        backgroundColor: def.navBg,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: def.inputFill,
        border: border,
        enabledBorder: border,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: def.accent, width: 1.6),
        ),
        labelStyle: TextStyle(color: def.textSoft),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: def.sheetColor,
        modalBackgroundColor: def.sheetColor,
      ),
      dialogTheme: DialogThemeData(backgroundColor: def.sheetColor),
      dividerTheme: DividerThemeData(color: def.track),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: def.accent),
      textTheme: TextTheme(
        bodyMedium: TextStyle(color: def.text),
        bodySmall: TextStyle(color: def.textSoft),
        titleMedium: TextStyle(color: def.text, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// 全 App 背景层：玻璃主题时铺壁纸 + 轻模糊 + 罩色，Scaffold 透明透出；
/// 波奇酱时原样返回 child，零变化。
class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final def = BocchiTheme.current;
    if (!def.glass || def.wallpaper == null) return child;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(def.wallpaper!, fit: BoxFit.cover),
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: def.bgBlur, sigmaY: def.bgBlur),
            child: Container(color: def.scrim),
          ),
        ),
        child,
      ],
    );
  }
}
