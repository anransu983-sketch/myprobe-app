// 地区选择器：PickMyVPS 式分组（常用/华北/东北/华东/华中/华南/西南/
// 西北），底部弹层；只有拨测覆盖的地区可点，没覆盖的置灰，不编数。
import 'package:flutter/material.dart';
import 'package:myprobe_app/theme.dart';

/// 地区分组（与 PickMyVPS 回程路由页的地区选择器同结构）。
const Map<String, List<String>> regionGroups = {
  '常用': ['北京', '上海', '广东'],
  '华北': ['北京', '河北', '山西', '内蒙古', '天津'],
  '东北': ['辽宁', '吉林', '黑龙江'],
  '华东': ['上海', '浙江', '江苏', '安徽', '福建', '江西', '山东'],
  '华中': ['湖北', '河南', '湖南'],
  '华南': ['广东', '广西', '海南'],
  '西南': ['四川', '重庆', '贵州', '云南', '西藏'],
  '西北': ['陕西', '甘肃', '青海', '宁夏', '新疆'],
};

/// 弹出地区选择器；返回选中的地区，取消返回 null。
/// [available] 是拨测覆盖的地区集合（只有这些可点）。
Future<String?> showRegionPicker(
  BuildContext context, {
  required Set<String> available,
  required String current,
}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('选择地区',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('只有拨测覆盖的地区可点；没覆盖的不编数',
                  style: TextStyle(
                      fontSize: 12, color: BocchiTheme.inkSoft)),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final group in regionGroups.entries) ...[
                        Text(group.key,
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: BocchiTheme.inkSoft)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final r in group.value)
                              ChoiceChip(
                                label: Text(r),
                                selected: r == current,
                                onSelected: available.contains(r)
                                    ? (_) =>
                                        Navigator.of(ctx).pop(r)
                                    : null,
                                selectedColor: BocchiTheme.pinkDeep,
                                labelStyle: TextStyle(
                                    color: r == current
                                        ? Colors.white
                                        : (available.contains(r)
                                            ? BocchiTheme.ink
                                            : BocchiTheme.inkSoft)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
