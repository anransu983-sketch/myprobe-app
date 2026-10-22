import 'package:flutter/material.dart';
import 'api.dart';
import 'theme.dart';

/// 通用错误提示
void showErr(BuildContext context, Object e) {
  final msg = e is ApiError
      ? e.message
      : e is NeedLogin
          ? '需要管理员登录'
          : '$e';
  // 夜之城·毛玻璃的底色是 2077 黄（pinkDeep=accent），白字对比太弱，用深字
  final darkText = BocchiTheme.current.id == 'nightcity_glass';
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg,
          style: darkText ? const TextStyle(color: Color(0xFF111111)) : null),
      backgroundColor: BocchiTheme.pinkDeep,
    ),
  );
}

void showOk(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: BocchiTheme.okGreen),
  );
}
