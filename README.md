# 探针（MyProbe Android 客户端）

自建 MyProbe 探针的安卓客户端：https://probe.suanran9527.com

## 功能

- **节点**：在线状态、CPU / 内存 / 硬盘、实时上下行、到期天数、本月流量，5 秒自动刷新；点卡片看历史曲线（CPU / 内存 / 网速）、每日流量
- **拨测**：拨测任务列表、最新延迟 / 丢包、30 条历史小柱状图，支持搜索
- **设置**：服务器地址（默认 `https://probe.suanran9527.com`，可改）、管理员登录
- **管理员**（登录后解锁）：
  - 拨测任务：添加 / 删除 / 启停 / 立即测试
  - 节点：重命名 / 删除 / 计费与到期信息编辑 / 卡片排序

## 构建

Actions 页手动触发 `Build 探针 APK`，产物为 debug 签名 APK（签名 keystore 在 CI 缓存中固定，多次构建签名一致，可直接覆盖安装）。

本地构建需要 Flutter SDK（stable）：

```bash
flutter pub get
flutter build apk --debug
```

## 版本

- v1.0.0：首版
