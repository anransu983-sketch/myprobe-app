import 'package:flutter/material.dart';

/// 极简 VT100 屏幕缓冲：处理 SGR 颜色、光标移动、清屏/清行。
/// 够用即可（bash/vim/htop 基本可看），不是完整 xterm。
class TermCell {
  String ch;
  Color fg;
  Color bg;
  TermCell({this.ch = ' ', this.fg = Colors.white, this.bg = Colors.black});
  TermCell clone() => TermCell(ch: ch, fg: fg, bg: bg);
}

class TermBuffer extends ChangeNotifier {
  static const int maxScrollback = 600;

  int cols;
  int rows;
  late List<List<TermCell>> _screen;
  final List<List<TermCell>> _scrollback = [];

  int _cx = 0, _cy = 0;
  Color _fg = Colors.white, _bg = Colors.black;
  bool _bold = false;

  // 保存的光标
  int _sx = 0, _sy = 0;
  Color _sfg = Colors.white, _sbg = Colors.black;
  bool _sbold = false;

  // ANSI 解析状态
  int _state = 0; // 0 普通 1 ESC 2 CSI 3 OSC
  String _csiParams = '';

  TermBuffer({this.cols = 100, this.rows = 30}) {
    _screen = _blankScreen();
  }

  List<List<TermCell>> _blankScreen() => List.generate(
      rows, (_) => List.generate(cols, (_) => TermCell()));

  List<List<TermCell>> get scrollback => _scrollback;

  List<List<TermCell>> lines() =>
      [..._scrollback, ..._screen];

  void resize(int c, int r) {
    cols = c.clamp(20, 300);
    rows = r.clamp(10, 100);
    _screen = _blankScreen();
    _cx = 0;
    _cy = 0;
    notifyListeners();
  }

  void _newline() {
    _cx = 0;
    if (_cy >= rows - 1) {
      _scrollback.add(_screen.removeAt(0));
      if (_scrollback.length > maxScrollback) {
        _scrollback.removeAt(0);
      }
      _screen.add(List.generate(cols, (_) => TermCell()));
    } else {
      _cy++;
    }
  }

  void _put(String ch) {
    if (_cx >= cols) _newline();
    if (_cy < 0 || _cy >= rows) return;
    _screen[_cy][_cx] =
        TermCell(ch: ch, fg: _fg, bg: _bg);
    _cx++;
  }

  void _eraseLine(int mode) {
    // 0 右 1 左 2 整行
    final y = _cy.clamp(0, rows - 1);
    final start = mode == 1 ? 0 : _cx;
    final end = mode == 0 ? cols - 1 : _cx;
    for (var x = start; x <= end && x < cols; x++) {
      _screen[y][x] = TermCell(bg: _bg);
    }
  }

  void _eraseDisplay(int mode) {
    if (mode == 2) {
      for (var y = 0; y < rows; y++) {
        for (var x = 0; x < cols; x++) {
          _screen[y][x] = TermCell(bg: _bg);
        }
      }
      _cx = 0;
      _cy = 0;
    } else {
      _eraseLine(0);
      for (var y = _cy + 1; y < rows; y++) {
        for (var x = 0; x < cols; x++) {
          _screen[y][x] = TermCell(bg: _bg);
        }
      }
    }
  }

  static const _ansiColors = [
    Colors.black,
    Color(0xFFCD0000),
    Color(0xFF00CD00),
    Color(0xFFCDCD00),
    Color(0xFF0000EE),
    Color(0xFFCD00CD),
    Color(0xFF00CDCD),
    Color(0xFFE5E5E5),
  ];
  static const _ansiBright = [
    Color(0xFF7F7F7F),
    Color(0xFFFF0000),
    Color(0xFF00FF00),
    Color(0xFFFFFF00),
    Color(0xFF5C5CFF),
    Color(0xFFFF00FF),
    Color(0xFF00FFFF),
    Colors.white,
  ];

  void _sgr(List<int> p) {
    if (p.isEmpty) p = [0];
    var i = 0;
    while (i < p.length) {
      final n = p[i];
      if (n == 0) {
        _fg = Colors.white;
        _bg = Colors.black;
        _bold = false;
      } else if (n == 1) {
        _bold = true;
      } else if (n == 22) {
        _bold = false;
      } else if (n >= 30 && n <= 37) {
        _fg = _bold ? _ansiBright[n - 30] : _ansiColors[n - 30];
      } else if (n >= 90 && n <= 97) {
        _fg = _ansiBright[n - 90];
      } else if (n == 39) {
        _fg = Colors.white;
      } else if (n >= 40 && n <= 47) {
        _bg = _ansiColors[n - 40];
      } else if (n >= 100 && n <= 107) {
        _bg = _ansiBright[n - 100];
      } else if (n == 49) {
        _bg = Colors.black;
      }
      // 38;5;n / 48;5;n 扩展色：简单跳过
      if ((n == 38 || n == 48) &&
          i + 2 < p.length &&
          p[i + 1] == 5) {
        i += 2;
      }
      i++;
    }
  }

  List<int> _params() {
    if (_csiParams.isEmpty) return [];
    return _csiParams
        .split(';')
        .map((s) => int.tryParse(s) ?? 0)
        .toList();
  }

  void _csiDispatch(String final_) {
    final p = _params();
    int n(int idx, int dflt) =>
        idx < p.length && p[idx] != 0 ? p[idx] : dflt;
    switch (final_) {
      case 'm':
        _sgr(p);
        break;
      case 'H':
      case 'f':
        _cy = (n(0, 1) - 1).clamp(0, rows - 1);
        _cx = (n(1, 1) - 1).clamp(0, cols - 1);
        break;
      case 'A':
        _cy = (_cy - n(0, 1)).clamp(0, rows - 1);
        break;
      case 'B':
        _cy = (_cy + n(0, 1)).clamp(0, rows - 1);
        break;
      case 'C':
        _cx = (_cx + n(0, 1)).clamp(0, cols - 1);
        break;
      case 'D':
        _cx = (_cx - n(0, 1)).clamp(0, cols - 1);
        break;
      case 'E':
        _cy = (_cy + n(0, 1)).clamp(0, rows - 1);
        _cx = 0;
        break;
      case 'F':
        _cy = (_cy - n(0, 1)).clamp(0, rows - 1);
        _cx = 0;
        break;
      case 'G':
        _cx = (n(0, 1) - 1).clamp(0, cols - 1);
        break;
      case 'J':
        _eraseDisplay(n(0, 0));
        break;
      case 'K':
        _eraseLine(n(0, 0));
        break;
      case 'S':
        for (var k = 0; k < n(0, 1); k++) _newline();
        break;
      case 'T':
        for (var k = 0; k < n(0, 1); k++) {
          if (_cy <= 0) {
            _screen.insert(0, List.generate(cols, (_) => TermCell()));
            _screen.removeLast();
          } else {
            _cy--;
          }
        }
        break;
      // h/l/r 等直接忽略
    }
  }

  void write(String data) {
    var dirty = false;
    for (var i = 0; i < data.length; i++) {
      final ch = data[i];
      final code = ch.codeUnitAt(0);
      if (_state == 3) {
        // OSC：吃到 BEL 或 ESC \ 为止
        if (code == 7) {
          _state = 0;
        } else if (code == 27) {
          _state = 4; // 可能是 OSC 结束
        }
        continue;
      }
      if (_state == 4) {
        _state = ch == '\\' ? 0 : 3;
        continue;
      }
      if (_state == 2) {
        // CSI
        if (ch == '?') {
          
          continue;
        }
        if ((code >= 48 && code <= 57) || ch == ';') {
          _csiParams += ch;
          continue;
        }
        _csiDispatch(ch);
        _state = 0;
        dirty = true;
        continue;
      }
      if (_state == 1) {
        // ESC 后
        if (ch == '[') {
          _state = 2;
          _csiParams = '';
          
        } else if (ch == ']') {
          _state = 3;
        } else if (ch == 'M') {
          // 反向换行
          if (_cy <= 0) {
            _screen.insert(0, List.generate(cols, (_) => TermCell()));
            _screen.removeLast();
          } else {
            _cy--;
          }
          _state = 0;
        } else if (ch == '7') {
          _sx = _cx;
          _sy = _cy;
          _sfg = _fg;
          _sbg = _bg;
          _sbold = _bold;
          _state = 0;
        } else if (ch == '8') {
          _cx = _sx;
          _cy = _sy;
          _fg = _sfg;
          _bg = _sbg;
          _bold = _sbold;
          _state = 0;
        } else if (ch == '=' || ch == '>') {
          _state = 0; // 应用/数字键盘模式，忽略
        } else if (ch == '(' || ch == ')' || ch == '#' || ch == '%') {
          _state = 5; // 字符集选择，吃掉下一个字符
        } else {
          _state = 0;
        }
        dirty = true;
        continue;
      }
      if (_state == 5) {
        _state = 0;
        continue;
      }
      // 普通字符
      if (code == 27) {
        _state = 1;
      } else if (code == 10 || code == 11 || code == 12) {
        _newline();
        dirty = true;
      } else if (code == 13) {
        _cx = 0;
        dirty = true;
      } else if (code == 8) {
        if (_cx > 0) _cx--;
        dirty = true;
      } else if (code == 9) {
        _cx = ((_cx ~/ 8) + 1) * 8;
        if (_cx >= cols) _newline();
        dirty = true;
      } else if (code == 7) {
        // bell 忽略
      } else if (code < 32) {
        // 其他控制字符忽略
      } else {
        _put(ch);
        dirty = true;
      }
    }
    if (dirty) notifyListeners();
  }

  /// 渲染为 TextSpan 行（供 SelectableText.rich 用）
  List<TextSpan> buildSpans(
      {double fontSize = 12, String fontFamily = 'monospace'}) {
    final out = <TextSpan>[];
    for (final line in lines()) {
      final spans = <TextSpan>[];
      var cur = StringBuffer();
      Color? cfg;
      Color? cbg;
      void flush() {
        if (cur.isEmpty) return;
        spans.add(TextSpan(
          text: cur.toString(),
          style: TextStyle(
            color: cfg,
            backgroundColor:
                cbg == Colors.black ? null : cbg,
            fontSize: fontSize,
            fontFamily: fontFamily,
          ),
        ));
        cur = StringBuffer();
      }

      var text = line.map((c) => c.ch).join().trimRight();
      if (text.isEmpty) text = ' ';
      var idx = 0;
      for (final cell in line) {
        if (idx >= text.length) break;
        if (cell.fg != cfg || cell.bg != cbg) {
          flush();
          cfg = cell.fg;
          cbg = cell.bg;
        }
        cur.write(cell.ch);
        idx++;
      }
      flush();
      if (spans.isEmpty) {
        spans.add(TextSpan(
            text: ' ',
            style: TextStyle(
                fontSize: fontSize, fontFamily: fontFamily)));
      }
      out.add(TextSpan(children: spans));
      out.add(const TextSpan(text: '\n'));
    }
    return out;
  }
}
