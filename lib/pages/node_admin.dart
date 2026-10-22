import 'package:flutter/material.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../ui.dart';
import '../widgets/widgets.dart';

/// 节点管理操作（重命名 / 计费信息 / 删除），节点卡片与详情页共用
class NodeAdmin {
  static void sheet(
      BuildContext context, ProbeNode n, VoidCallback onChanged,
      {bool popAfterDelete = false}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => GlassSheet(
        topRadius: 20,
        child: SafeArea(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('重命名节点'),
                onTap: () {
                  Navigator.pop(context);
                  renameDialog(context, n, onChanged);
                }),
            ListTile(
                leading: const Icon(Icons.tune),
                title: const Text('计费 / 到期信息'),
                onTap: () {
                  Navigator.pop(context);
                  metaDialog(context, n, onChanged);
                }),
            ListTile(
                leading: const Icon(Icons.delete_outline,
                    color: BocchiTheme.warnRed),
                title: const Text('删除节点',
                    style:
                        TextStyle(color: BocchiTheme.warnRed)),
                onTap: () {
                  Navigator.pop(context);
                  deleteNode(context, n, onChanged,
                      popAfterDelete: popAfterDelete);
                }),
            const SizedBox(height: 8),
          ],
        ),
        ),
      ),
    );
  }

  static Future<void> renameDialog(BuildContext context,
      ProbeNode n, VoidCallback onChanged) async {
    final c = TextEditingController(text: n.name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('重命名节点'),
        content: TextField(
            controller: c,
            decoration:
                const InputDecoration(labelText: '节点名称')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('保存')),
        ],
      ),
    );
    if (ok == true && c.text.trim().isNotEmpty) {
      try {
        await AppState.instance.client
            .nodeRename(n.id, c.text.trim());
        showOk(context, '已重命名');
        onChanged();
      } catch (e) {
        showErr(context, e);
      }
    }
  }

  static Future<void> metaDialog(BuildContext context,
      ProbeNode n, VoidCallback onChanged) async {
    final price =
        TextEditingController(text: (n.price ?? '').toString());
    final quota = TextEditingController(
        text: n.quotaGb > 0
            ? n.quotaGb.toStringAsFixed(0)
            : '');
    final buy = TextEditingController(text: n.buyDate ?? '');
    final exp =
        TextEditingController(text: n.expireDate ?? '');
    final currency =
        TextEditingController(text: n.currency ?? '¥');
    String cycle =
        (n.billCycle == 'yearly') ? 'yearly' : 'monthly';
    final sshHost =
        TextEditingController(text: n.sshHost ?? '');
    final sshPort = TextEditingController(
        text: (n.sshPort ?? 22).toString());
    final sshUser =
        TextEditingController(text: n.sshUser ?? 'root');
    final sshPass = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('计费 / 到期信息'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: price,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: '价格（数字）')),
                TextField(
                    controller: quota,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: '流量配额 GB（0=不限）')),
                TextField(
                    controller: currency,
                    decoration: const InputDecoration(
                        labelText: '货币符号')),
                DropdownButtonFormField<String>(
                  initialValue: cycle,
                  items: const [
                    DropdownMenuItem(
                        value: 'monthly',
                        child: Text('按月')),
                    DropdownMenuItem(
                        value: 'yearly', child: Text('按年')),
                  ],
                  onChanged: (v) =>
                      setS(() => cycle = v ?? 'monthly'),
                  decoration: const InputDecoration(
                      labelText: '计费周期'),
                ),
                TextField(
                    controller: buy,
                    decoration: const InputDecoration(
                        labelText: '购买日期 YYYY-MM-DD')),
                TextField(
                    controller: exp,
                    decoration: const InputDecoration(
                        labelText: '到期日期 YYYY-MM-DD')),
                const SizedBox(height: 12),
                 Text('SSH（终端用，留空则终端不显示）',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: BocchiTheme.ink)),
                const SizedBox(height: 8),
                TextField(
                    controller: sshHost,
                    decoration: const InputDecoration(
                        labelText: 'SSH 主机（IP/域名）')),
                TextField(
                    controller: sshPort,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'SSH 端口（默认 22）')),
                TextField(
                    controller: sshUser,
                    decoration: const InputDecoration(
                        labelText: 'SSH 用户名（默认 root）')),
                TextField(
                    controller: sshPass,
                    obscureText: true,
                    decoration: InputDecoration(
                        labelText:
                            'SSH 密码${n.sshReady ? '（已保存，留空不改）' : ''}')),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('保存')),
          ],
        ),
      ),
    );
    if (ok == true) {
      try {
        final d = <String, dynamic>{
          'price': price.text.trim(),
          'quota_gb': quota.text.trim(),
          'currency': currency.text.trim(),
          'bill_cycle': cycle,
          'buy_date': buy.text.trim(),
          'expire_date': exp.text.trim(),
          'ssh_host': sshHost.text.trim(),
          'ssh_port': sshPort.text.trim(),
          'ssh_user': sshUser.text.trim(),
        };
        // 密码留空=不改（跟网页端一致）
        if (sshPass.text.isNotEmpty) {
          d['ssh_password'] = sshPass.text;
        }
        await AppState.instance.client.nodeMeta(n.id, d);
        showOk(context, '已保存');
        onChanged();
      } catch (e) {
        showErr(context, e);
      }
    }
  }

  static Future<void> deleteNode(BuildContext context,
      ProbeNode n, VoidCallback onChanged,
      {bool popAfterDelete = false}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除节点'),
        content:
            Text('确定删除「${n.name}」吗？历史数据会一并清除。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('删除',
                  style: TextStyle(
                      color: BocchiTheme.warnRed))),
        ],
      ),
    );
    if (ok == true) {
      try {
        await AppState.instance.client.nodeDelete(n.id);
        showOk(context, '已删除');
        if (popAfterDelete && context.mounted) {
          Navigator.pop(context);
        } else {
          onChanged();
        }
      } catch (e) {
        showErr(context, e);
      }
    }
  }
}
