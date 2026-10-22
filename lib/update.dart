import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'theme.dart';

const _repo = 'anransu983-sketch/myprobe-app';
const _releasesUrl = 'https://api.github.com/repos/$_repo/releases/latest';

/// 远端版本信息
class RemoteVersion {
  final String tag; // v1.3.0
  final String version; // 1.3.0
  final String apkUrl;
  final String name;
  const RemoteVersion(
      {required this.tag,
      required this.version,
      required this.apkUrl,
      required this.name});
}

/// 查 GitHub latest release，返回 null 表示已是最新或查不到
Future<RemoteVersion?> checkForUpdate() async {
  final local =
      (await PackageInfo.fromPlatform()).version.trim();
  final resp = await http
      .get(Uri.parse(_releasesUrl),
          headers: {'Accept': 'application/vnd.github+json'})
      .timeout(const Duration(seconds: 15));
  if (resp.statusCode != 200) {
    throw Exception('GitHub 返回 ${resp.statusCode}');
  }
  final j = jsonDecode(resp.body) as Map<String, dynamic>;
  final tag = (j['tag_name'] as String? ?? '').trim();
  final ver = tag.startsWith('v') ? tag.substring(1) : tag;
  if (ver.isEmpty || !_isNewer(ver, local)) return null;
  String apkUrl = '';
  for (final a in (j['assets'] as List? ?? [])) {
    final name = (a['name'] as String? ?? '').toLowerCase();
    if (name.endsWith('.apk')) {
      apkUrl = a['browser_download_url'] as String? ?? '';
      break;
    }
  }
  if (apkUrl.isEmpty) throw Exception('Release 里没有 APK');
  return RemoteVersion(
      tag: tag,
      version: ver,
      apkUrl: apkUrl,
      name: j['name'] as String? ?? tag);
}

bool _isNewer(String remote, String local) {
  List<int> p(String v) => v
      .split('.')
      .map((e) => int.tryParse(e) ?? 0)
      .toList();
  final r = p(remote), l = p(local);
  for (var i = 0; i < 3; i++) {
    final a = i < r.length ? r[i] : 0;
    final b = i < l.length ? l[i] : 0;
    if (a != b) return a > b;
  }
  return false;
}

/// 下载 APK（带进度）并调起安装
Future<void> downloadAndInstall(
    BuildContext context, RemoteVersion rv,
    {void Function(double progress)? onProgress}) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/myprobe-update.apk');
  final client = http.Client();
  try {
    final req = http.Request('GET', Uri.parse(rv.apkUrl));
    final resp = await client.send(req);
    if (resp.statusCode != 200) {
      throw Exception('下载失败：${resp.statusCode}');
    }
    final total = resp.contentLength ?? 0;
    var received = 0;
    final sink = file.openWrite();
    await for (final chunk in resp.stream) {
      received += chunk.length;
      sink.add(chunk);
      if (total > 0) onProgress?.call(received / total);
    }
    await sink.close();
  } finally {
    client.close();
  }
  final result = await OpenFilex.open(file.path);
  if (result.type != ResultType.done) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '调起安装失败：${result.message}，可去系统设置允许「安装未知应用」后重试')));
    }
  }
}

/// 设置页「检查更新」一整套交互
Future<void> runUpdateCheck(BuildContext context) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => Center(
        child: CircularProgressIndicator(
            color: BocchiTheme.pinkDeep)),
  );
  RemoteVersion? rv;
  Object? err;
  try {
    rv = await checkForUpdate();
  } catch (e) {
    err = e;
  }
  if (context.mounted) Navigator.of(context).pop();
  if (!context.mounted) return;
  if (err != null) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('检查更新失败：$err')));
    return;
  }
  if (rv == null) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已经是最新版 🎸')));
    return;
  }
  final rvFinal = rv;
  final go = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('发现新版 ${rvFinal.version} 🎸'),
      content: Text('${rvFinal.name}\n\n现在下载安装？'),
      actions: [
        TextButton(
            onPressed: () =>
                Navigator.of(context).pop(false),
            child: const Text('稍后')),
        FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
                backgroundColor:
                    BocchiTheme.pinkDeep),
            child: const Text('更新')),
      ],
    ),
  );
  if (go != true || !context.mounted) return;
  final dlgState = ValueNotifier<double>(0);
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => ValueListenableBuilder<double>(
      valueListenable: dlgState,
      builder: (_, p, __) => AlertDialog(
        title: const Text('下载中…'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
                value: p <= 0 ? null : p,
                color: BocchiTheme.pinkDeep),
            const SizedBox(height: 8),
            Text(p <= 0
                ? '准备下载'
                : '已下载 ${(p * 100).toStringAsFixed(0)}%'),
          ],
        ),
      ),
    ),
  );
  try {
    await downloadAndInstall(context, rvFinal,
        onProgress: (p) => dlgState.value = p);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载失败：$e')));
    }
  } finally {
    dlgState.dispose();
    if (context.mounted) Navigator.of(context).pop();
  }
}
