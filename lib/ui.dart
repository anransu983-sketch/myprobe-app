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
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: BocchiTheme.pinkDeep),
  );
}

void showOk(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: BocchiTheme.okGreen),
  );
}
