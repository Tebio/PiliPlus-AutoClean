<div align="center">
  <img width="160" height="160" src="assets/images/logo/logo.png">
  <h1>PiliPlus AutoClean</h1>

![GitHub release](https://img.shields.io/github/v/release/Tebio/PiliPlus-AutoClean?include_prereleases)
![GitHub downloads](https://img.shields.io/github/downloads/Tebio/PiliPlus-AutoClean/total)
![Android](https://img.shields.io/badge/Android-arm64--v8a-green)

  <p>基于 PiliPlus 的个人 Android fork，重点优化“稍后再看”自动清理体验。</p>
</div>

## 和原版 PiliPlus 的区别

本仓库不是官方 PiliPlus，而是个人维护的 AutoClean 版本。

- 可与官方 PiliPlus 共存安装：`com.tebio.piliplus.autoclean`
- App 名称：`PiliPlus AutoClean`
- 仅发布 Android `arm64-v8a` APK
- App 内更新检测指向本仓库 Releases
- 保留上游 PiliPlus 的主要功能，并定期自动同步上游

上游项目：

- [bggRGjQaUbCoE/PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus)

## AutoClean 功能

- 看完后自动从“稍后再看”移除，默认开启
- 移除阈值可设置，默认 `98%`
- 达到阈值后先标记 pending，不立即刷新列表或打断播放
- 切到下一 P、下一个合集视频或下一个稍后再看视频后，后台移除上一个已完成视频
- 如果看完后直接刷新、退出或稍后再打开，会从本地 pending 队列补删
- 分 P 视频尽量等最后一 P 看完再移除
- 只对来自“稍后再看”的视频生效，不影响收藏、历史记录、合集、UP 主视频列表、推荐流
- 删除失败只记录或轻提示，不中断播放
- 同一个 `aid/bvid` 只移除一次

## 保留规则

为了避免 ASMR、睡眠音频、BGM 等视频被误清理，AutoClean 支持多层保护：

- 视频详情页点亮 `保留`，当前视频不会自动从稍后再看移除
- 设置标题关键词，例如 `ASMR|睡眠|BGM`
- 设置 UP 主 UID，指定 UP 的视频不会自动移除
- 设置视频时长保护，例如一小时以上不自动移除

## 安全菜单调整

在“稍后再看”页面隐藏危险的 `清空全部` 菜单。

保留：

- `清空失效`
- `清空看完`

## 自动同步与构建

本仓库通过 GitHub Actions 自动维护 Android 版本：

- 定时尝试同步上游 PiliPlus
- 上游更新后自动构建 AutoClean APK
- 使用固定签名 Secrets 构建 release 包
- 如果同步冲突，会停止，不会强行覆盖 AutoClean 定制功能
- 构建前会运行 AutoClean 守门检查，防止关键定制被上游改动冲掉

Release APK 命名规则：

```text
PiliPlus_AutoClean_android_${version}_arm64-v8a.apk
```

## 下载

请从本仓库 [Releases](https://github.com/Tebio/PiliPlus-AutoClean/releases) 下载最新 APK。

本 fork 只提供 Android `arm64-v8a` release APK。

## 说明

本项目仅供个人学习、测试与自用。项目基于 PiliPlus 上游开源代码进行定制，不提供任何破解内容，所用接口均来自公开网络环境。

感谢原项目和上游作者的开源工作：

- [guozhigq/pilipala](https://github.com/guozhigq/pilipala)
- [orz12/PiliPalaX](https://github.com/orz12/PiliPalaX)
- [bggRGjQaUbCoE/PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus)

## 致谢

- [bilibili-API-collect](https://github.com/SocialSisterYi/bilibili-API-collect)
- [flutter_meedu_videoplayer](https://github.com/zezo357/flutter_meedu_videoplayer)
- [media-kit](https://github.com/media-kit/media-kit)
- [dio](https://pub.dev/packages/dio)
