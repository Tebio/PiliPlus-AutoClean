import 'dart:io' show Platform;

import 'package:PiliPlus/build_config.dart';
import 'package:PiliPlus/common/constants.dart';
import 'package:PiliPlus/http/api.dart';
import 'package:PiliPlus/http/browser_ua.dart';
import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/utils/accounts/account.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

abstract final class Update {
  static bool _checking = false;
  static int? _shownVersionCode;

  // 检查更新
  static Future<bool> checkUpdate([bool isAuto = true]) async {
    if (kDebugMode || _checking) return false;
    _checking = true;
    try {
      final data = await _getLatestRelease(isAuto ? 3 : 1);
      if (data == null) {
        if (!isAuto) {
          SmartDialog.showToast('检查更新失败，GitHub接口未返回数据，请检查网络');
        }
        return false;
      }

      final latestVersionCode = _releaseVersionCode(data);
      final isLatest = latestVersionCode != null
          ? BuildConfig.versionCode >= latestVersionCode
          : BuildConfig.buildTime >= _releaseTime(data);
      if (isLatest) {
        if (!isAuto) {
          SmartDialog.showToast('已是最新版本');
        }
        return true;
      } else {
        if (latestVersionCode != null &&
            _shownVersionCode == latestVersionCode) {
          return true;
        }
        _shownVersionCode = latestVersionCode;
        SmartDialog.show(
          animationType: SmartAnimationType.centerFade_otherSlide,
          builder: (context) {
            final colorScheme = ColorScheme.of(context);
            Widget downloadBtn(String text, {String? ext}) => TextButton(
              onPressed: () => onDownload(data, ext: ext),
              child: Text(text),
            );
            return AlertDialog(
              title: const Text('🎉 发现新版本 '),
              content: SizedBox(
                height: 280,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${data['tag_name']}',
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(height: 8),
                      Text('${data['body']}'),
                      TextButton(
                        onPressed: () => PageUtils.launchURL(
                          '${Constants.sourceCodeUrl}/commits/main',
                        ),
                        child: Text(
                          "点此查看完整更新(即commit)内容",
                          style: TextStyle(color: colorScheme.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                if (isAuto)
                  TextButton(
                    onPressed: () {
                      SmartDialog.dismiss();
                      GStorage.setting.put(SettingBoxKey.autoUpdate, false);
                    },
                    child: Text(
                      '不再提醒',
                      style: TextStyle(color: colorScheme.outline),
                    ),
                  ),
                TextButton(
                  onPressed: SmartDialog.dismiss,
                  child: Text(
                    '取消',
                    style: TextStyle(color: colorScheme.outline),
                  ),
                ),
                if (Platform.isWindows) ...[
                  downloadBtn('zip', ext: 'zip'),
                  downloadBtn('exe', ext: 'exe'),
                ] else if (Platform.isLinux) ...[
                  downloadBtn('rpm', ext: 'rpm'),
                  downloadBtn('deb', ext: 'deb'),
                  downloadBtn('targz', ext: 'tar.gz'),
                ] else
                  downloadBtn('Github'),
              ],
            );
          },
        );
        return true;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('failed to check update: $e');
      if (!isAuto) {
        SmartDialog.showToast('检查更新失败，请稍后重试');
      }
      return false;
    } finally {
      _checking = false;
    }
  }

  static Future<Map?> _getLatestRelease(int attempts) async {
    for (var attempt = 0; attempt < attempts; attempt++) {
      final metadata = await _requestRelease(
        Api.latestAppMetadata,
        cacheBust: true,
      );
      if (metadata != null) {
        return metadata;
      }

      final apiData = await _requestRelease(Api.latestApp);
      if (apiData != null) {
        return apiData;
      }

      if (attempt + 1 < attempts) {
        await Future.delayed(Duration(seconds: 2 << attempt));
      }
    }
    return null;
  }

  static Future<Map?> _requestRelease(
    String url, {
    bool cacheBust = false,
  }) async {
    final res = await Request().get(
      url,
      queryParameters: cacheBust
          ? {'t': DateTime.now().millisecondsSinceEpoch}
          : null,
      options: Options(
        headers: {
          'user-agent': BrowserUa.mob,
          'cache-control': 'no-cache',
        },
        extra: {'account': const NoAccount()},
      ),
    );
    return res.statusCode == 200 && res.data is Map && res.data.isNotEmpty
        ? res.data as Map
        : null;
  }

  static int? _releaseVersionCode(Map data) {
    final direct = switch (data['version_code']) {
      final int value => value,
      final String value => int.tryParse(value),
      _ => null,
    };
    if (direct != null) {
      return direct;
    }
    final match = RegExp(r'\+(\d+)$').firstMatch('${data['tag_name'] ?? ''}');
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  static int _releaseTime(Map data) {
    final value = data['published_at'] ?? data['created_at'];
    return value is String
        ? DateTime.parse(value).millisecondsSinceEpoch ~/ 1000
        : 0;
  }

  // 下载适用于当前系统的安装包
  static Future<void> onDownload(Map data, {String? ext}) async {
    SmartDialog.dismiss();
    try {
      void download(String plat) {
        if (data['assets'].isNotEmpty) {
          for (Map<String, dynamic> i in data['assets']) {
            final String name = i['name'];
            if (name.contains(plat) &&
                (ext == null || ext.isEmpty ? true : name.endsWith(ext))) {
              PageUtils.launchURL(i['browser_download_url']);
              return;
            }
          }
          throw UnsupportedError('platform not found: $plat');
        }
      }

      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await DeviceInfoPlugin().androidInfo;
        if (!androidInfo.supportedAbis.contains('arm64-v8a')) {
          throw UnsupportedError('arm64-v8a not supported');
        }
        download('arm64-v8a');
      } else {
        download(Platform.operatingSystem);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('download error: $e');
      PageUtils.launchURL('${Constants.sourceCodeUrl}/releases/latest');
    }
  }
}
