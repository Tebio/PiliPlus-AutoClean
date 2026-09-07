/// AutoClean 外挂模块：稍后再看自动清理（看完自动删 + 进度达标刷新删 + 保护规则）。
///
/// 2026-09-07 外挂化重构：全部逻辑从 lib/pages/video/controller.dart（~270 行内嵌）
/// 和 lib/pages/later/controller.dart 抽到这里。上游文件只保留个位数行的 hook
/// 委托，上游 merge 冲突面从 ~300 行降到 hook 行级别。
///
/// Hook 点（改这里才算碰冻结逻辑，CI guard 会守）：
/// - video/controller.dart: `watchLaterCleaner` 字段 + 3 个一行委托方法
///   + onInit 里一行 removeStoredPendingOnOpen()
/// - later/controller.dart: `.where(WatchLaterCleaner.shouldAutoRemoveViewedItem)`
library;

import 'dart:async';

import 'package:PiliPlus/http/user.dart';
import 'package:PiliPlus/models/common/video/source_type.dart';
import 'package:PiliPlus/models_new/later/list.dart';
import 'package:PiliPlus/pages/video/controller.dart';
import 'package:PiliPlus/pages/video/introduction/pgc/controller.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/controller.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

/// 待删除条目（持久化到 SettingBoxKey.autoRemoveWatchedLaterPending）。
/// 编码格式：aid \t bvid \t key \t title \t upMid \t durationMs \t 'completed'
/// 末段恒为 'completed'——旧版按进度触发的遗留记录（无此标记）一律不执行。
class PendingWatchLaterRemoval {
  final int aid;
  final String bvid;
  final String key;
  final String? title;
  final int? upMid;
  final int? durationMs;

  const PendingWatchLaterRemoval({
    required this.aid,
    required this.bvid,
    required this.key,
    this.title,
    this.upMid,
    this.durationMs,
  });
}

/// 绑定到单个 VideoDetailController 的清理器实例。
class WatchLaterCleaner {
  WatchLaterCleaner(this.ctr);

  final VideoDetailController ctr;

  /// 本次会话内已删除过的 key（防重复删/重复提示）
  final Set<String> removedKeys = <String>{};

  /// 当前视频待删除标记（播放完成时武装，切集/播完时执行）
  PendingWatchLaterRemoval? pending;

  // ── 基础工具 ──────────────────────────────────────────────

  String removalKey(int aid, String bvid) =>
      bvid.isNotEmpty ? bvid : aid.toString();

  double get autoRemoveThreshold => Pref.autoRemoveWatchedLaterThreshold / 100;

  List<String> get storedPending => List<String>.from(
        ctr.setting.get(
          SettingBoxKey.autoRemoveWatchedLaterPending,
          defaultValue: const <String>[],
        ),
      );

  String _pendingField(String? value) =>
      (value ?? '').replaceAll(RegExp(r'[\t\r\n]+'), ' ');

  String _encodePending(PendingWatchLaterRemoval pending) => [
        pending.aid.toString(),
        _pendingField(pending.bvid),
        _pendingField(pending.key),
        _pendingField(pending.title),
        pending.upMid?.toString() ?? '',
        pending.durationMs?.toString() ?? '',
        'completed',
      ].join('\t');

  PendingWatchLaterRemoval? _decodePending(String value) {
    return decodePending(value);
  }

  /// 静态版解码（later 页清仓等无控制器场景用）。
  /// 旧版按进度武装的遗留记录没有 'completed' 标记，一律拒绝执行。
  static PendingWatchLaterRemoval? decodePending(String value) {
    final parts = value.split('\t');
    // 旧版按进度武装的遗留记录没有 'completed' 标记，一律拒绝执行
    if (parts.length < 7 || parts[6] != 'completed') {
      return null;
    }
    final aid = int.tryParse(parts[0]);
    if (aid == null) {
      return null;
    }
    return PendingWatchLaterRemoval(
      aid: aid,
      bvid: parts[1],
      key: parts[2],
      title: parts.length > 3 ? parts[3] : null,
      upMid: parts.length > 4 ? int.tryParse(parts[4]) : null,
      durationMs: parts.length > 5 ? int.tryParse(parts[5]) : null,
    );
  }

  void _storePending(PendingWatchLaterRemoval pending) {
    final encoded = _encodePending(pending);
    final pendingList = storedPending
      ..removeWhere((item) => _decodePending(item)?.key == pending.key)
      ..add(encoded);
    unawaited(
      ctr.setting.put(SettingBoxKey.autoRemoveWatchedLaterPending, pendingList),
    );
  }

  void _removeStoredPending(String key) {
    final pendingList = storedPending
      ..removeWhere((item) => _decodePending(item)?.key == key);
    unawaited(
      ctr.setting.put(SettingBoxKey.autoRemoveWatchedLaterPending, pendingList),
    );
  }

  // ── 打开播放页时清理遗留 pending（Hook: controller onInit）──────────

  void removeStoredPendingOnOpen() {
    if (!Pref.autoRemoveWatchedLater || ctr.isFileSource) {
      return;
    }
    final pendingList = storedPending;
    if (pendingList.isEmpty) {
      return;
    }
    unawaited(ctr.setting.delete(SettingBoxKey.autoRemoveWatchedLaterPending));
    for (final item in pendingList) {
      final pending = _decodePending(item);
      if (pending == null || removedKeys.contains(pending.key)) {
        continue;
      }
      if (Pref.autoRemoveWatchedLaterExcludes.contains(pending.key) ||
          isProtectedByRules(
            durationMs: pending.durationMs ?? 0,
            title: pending.title,
            upMid: pending.upMid,
          )) {
        continue;
      }
      removedKeys.add(pending.key);
      Future.microtask(() async {
        final res = await UserHttp.toViewDel(
          aids: pending.aid.toString(),
          showToast: false,
        );
        if (res.isSuccess) {
          ctr.mediaList.removeWhere((item) => item.aid == pending.aid);
          return;
        }
        removedKeys.remove(pending.key);
        _storePending(pending);
        if (kDebugMode) {
          debugPrint('stored auto remove watch later failed: $res');
        }
      });
    }
  }

  // ── 当前视频上下文（UGC/PGC 通用）─────────────────────────

  bool _isLastPart() {
    if (!ctr.isUgc) {
      return true;
    }
    try {
      final pages = Get.find<UgcIntroController>(
        tag: ctr.heroTag,
      ).videoDetail.value.pages;
      if (pages == null || pages.length <= 1) {
        return true;
      }
      final index = pages.indexWhere((item) => item.cid == ctr.cid.value);
      return index == -1 || index == pages.length - 1;
    } catch (_) {
      return true;
    }
  }

  String? _currentTitle() {
    try {
      if (ctr.isUgc) {
        return Get.find<UgcIntroController>(
          tag: ctr.heroTag,
        ).videoDetail.value.title;
      }
      final introCtr = Get.find<PgcIntroController>(tag: ctr.heroTag);
      return [
        introCtr.pgcItem.title,
        introCtr.videoDetail.value.title,
      ].whereType<String>().where((item) => item.isNotEmpty).join(' ');
    } catch (_) {
      final title = ctr.args['title'];
      return title is String ? title : null;
    }
  }

  int? _currentUpMid() {
    try {
      if (ctr.isUgc) {
        return Get.find<UgcIntroController>(
          tag: ctr.heroTag,
        ).videoDetail.value.owner?.mid;
      }
      return Get.find<PgcIntroController>(tag: ctr.heroTag)
          .pgcItem
          .upInfo
          ?.mid;
    } catch (_) {
      return null;
    }
  }

  // ── 保护规则（标题关键词 / UP 主 / 最短时长）─────────────────

  /// 静态版：只用显式传入的数据判定（无控制器回退），later 页清仓用。
  static bool isProtectedByRulesData({
    required int durationMs,
    String? title,
    int? upMid,
  }) {
    final keywords = Pref.autoRemoveWatchedLaterTitleKeywords
        .split(RegExp(r'[\n|]+'))
        .map((item) => item.trim().toLowerCase())
        .where((item) => item.isNotEmpty);
    if (keywords.isNotEmpty) {
      final effectiveTitle = title?.toLowerCase() ?? '';
      if (keywords.any(effectiveTitle.contains)) {
        return true;
      }
    }

    final upMids = Pref.autoRemoveWatchedLaterUpMids;
    if (upMids.isNotEmpty && upMid != null && upMids.contains(upMid)) {
      return true;
    }

    final minDuration = Pref.autoRemoveWatchedLaterMinDuration;
    if (minDuration > 0 && durationMs >= minDuration * 1000) {
      return true;
    }

    return false;
  }

  bool isProtectedByRules({
    required int durationMs,
    String? title,
    int? upMid,
  }) {
    final keywords = Pref.autoRemoveWatchedLaterTitleKeywords
        .split(RegExp(r'[\n|]+'))
        .map((item) => item.trim().toLowerCase())
        .where((item) => item.isNotEmpty);
    if (keywords.isNotEmpty) {
      final effectiveTitle =
          title?.toLowerCase() ?? _currentTitle()?.toLowerCase() ?? '';
      if (keywords.any(effectiveTitle.contains)) {
        return true;
      }
    }

    final upMids = Pref.autoRemoveWatchedLaterUpMids;
    if (upMids.isNotEmpty) {
      final effectiveUpMid = upMid ?? _currentUpMid();
      if (effectiveUpMid != null && upMids.contains(effectiveUpMid)) {
        return true;
      }
    }

    final minDuration = Pref.autoRemoveWatchedLaterMinDuration;
    if (minDuration > 0 && durationMs >= minDuration * 1000) {
      return true;
    }

    return false;
  }

  // ── 播放完成时武装待删除（Hook: view 完成回调经委托进来）─────────
  // 注意：只在播放完成（completion）路径调用。进度监听里禁止调用本方法
  // （CI guard: video/view.dart positionListener 禁止出现 markWatchLaterAutoRemoveIfNeeded）。

  void markAutoRemoveIfNeeded(Duration position) {
    final key = removalKey(ctr.aid, ctr.bvid);
    if (!Pref.autoRemoveWatchedLater ||
        ctr.sourceType != SourceType.watchLater ||
        ctr.isFileSource ||
        Pref.autoRemoveWatchedLaterExcludes.contains(key) ||
        !_isLastPart()) {
      return;
    }

    final durationMs = ctr.data.timeLength;
    if (durationMs == null || durationMs <= 0) {
      return;
    }
    final title = _currentTitle();
    final upMid = _currentUpMid();
    if (isProtectedByRules(
      durationMs: durationMs,
      title: title,
      upMid: upMid,
    )) {
      return;
    }
    if (position.inMilliseconds / durationMs < autoRemoveThreshold) {
      return;
    }

    if (removedKeys.contains(key) || pending?.key == key) {
      return;
    }
    pending = PendingWatchLaterRemoval(
      aid: ctr.aid,
      bvid: ctr.bvid,
      key: key,
      title: title,
      upMid: upMid,
      durationMs: durationMs,
    );
    _storePending(pending!);
  }

  /// 用户手动从稍后再看删除该视频后，撤销 pending（Hook: 委托）
  void clearPending(String key) {
    if (pending?.key == key) {
      pending = null;
    }
    _removeStoredPending(key);
  }

  // ── 切集/播完后执行 pending 删除（Hook: UGC/PGC intro 委托）────────

  void removePendingAfterAdvance() {
    if (!Pref.autoRemoveWatchedLater ||
        ctr.sourceType != SourceType.watchLater) {
      return;
    }
    final pending = this.pending;
    if (pending == null || removedKeys.contains(pending.key)) {
      return;
    }
    if (Pref.autoRemoveWatchedLaterExcludes.contains(pending.key)) {
      this.pending = null;
      _removeStoredPending(pending.key);
      return;
    }

    this.pending = null;
    _removeStoredPending(pending.key);
    removedKeys.add(pending.key);
    Future.microtask(() async {
      final res = await UserHttp.toViewDel(
        aids: pending.aid.toString(),
        showToast: false,
      );
      if (res.isSuccess) {
        ctr.mediaList.removeWhere((item) => item.aid == pending.aid);
        return;
      }
      removedKeys.remove(pending.key);
      if (kDebugMode) {
        debugPrint('auto remove watch later failed: $res');
      }
      SmartDialog.showToast('稍后再看自动清理失败');
    });
  }

  // ── 稍后再看页面刷新：执行已武装的待删除队列 ─────────────────
  // 2026-09-07 修复「进度达标退出后刷新不删」：旧链路里武装后的 pending 只在
  // 「打开下一个稍后再看视频」时执行，刷新 later 页永远轮不到它。现在刷新即清仓。
  // 返回本次实际删除的 aid 列表（用于本地剔除，绕开服务端删除延迟）；
  // 删除失败返回 null，队列保留下次再试。

  static Future<List<int>?> drainPendingOnRefresh() async {
    if (!Pref.autoRemoveWatchedLater) {
      return null;
    }
    final setting = GStorage.setting;
    final list = List<String>.from(
      setting.get(
        SettingBoxKey.autoRemoveWatchedLaterPending,
        defaultValue: const <String>[],
      ),
    );
    if (list.isEmpty) {
      return null;
    }
    final keep = <String>[];
    final delAids = <int>[];
    for (final item in list) {
      final p = decodePending(item);
      if (p == null) {
        continue; // 旧版无 'completed' 标记的遗留记录，直接丢弃
      }
      if (Pref.autoRemoveWatchedLaterExcludes.contains(p.key) ||
          isProtectedByRulesData(
            durationMs: p.durationMs ?? 0,
            title: p.title,
            upMid: p.upMid,
          )) {
        keep.add(item);
        continue;
      }
      delAids.add(p.aid);
    }
    if (delAids.isEmpty) {
      if (keep.length != list.length) {
        unawaited(
          setting.put(SettingBoxKey.autoRemoveWatchedLaterPending, keep),
        );
      }
      return null;
    }
    final res = await UserHttp.toViewDel(
      aids: delAids.join(','),
      showToast: false,
    );
    if (!res.isSuccess) {
      return null;
    }
    unawaited(setting.put(SettingBoxKey.autoRemoveWatchedLaterPending, keep));
    return delAids;
  }

  // ── 稍后再看页面：服务端已看完条目自动删（静态，Hook: later/controller）──

  static bool shouldAutoRemoveViewedItem(LaterItemModel item) {
    if (item.progress != -1 || item.aid == null) {
      return false;
    }

    final key = item.bvid?.isNotEmpty == true
        ? item.bvid!
        : item.aid.toString();
    if (Pref.autoRemoveWatchedLaterExcludes.contains(key)) {
      return false;
    }

    final title = item.title?.toLowerCase() ?? '';
    final keywords = Pref.autoRemoveWatchedLaterTitleKeywords
        .split(RegExp(r'[\n|]+'))
        .map((item) => item.trim().toLowerCase())
        .where((item) => item.isNotEmpty);
    if (keywords.any(title.contains)) {
      return false;
    }

    final upMids = Pref.autoRemoveWatchedLaterUpMids;
    if (item.owner?.mid case final int upMid when upMids.contains(upMid)) {
      return false;
    }

    final minDuration = Pref.autoRemoveWatchedLaterMinDuration;
    if (minDuration > 0 &&
        item.duration != null &&
        item.duration! >= minDuration) {
      return false;
    }

    return true;
  }
}
