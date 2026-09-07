import 'package:PiliPlus/http/user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

/// 全局缓存 — 本次应用生命周期内已添加的稍后再看视频ID
Set<String> _addedBvids = {};

class WatchLaterButton extends StatefulWidget {
  final String? bvid;
  final int? aid;
  final double size;

  const WatchLaterButton({
    super.key,
    this.bvid,
    this.aid,
    this.size = 34,
  }) : assert(bvid != null || aid != null);

  @override
  State<WatchLaterButton> createState() => _WatchLaterButtonState();
}

class _WatchLaterButtonState extends State<WatchLaterButton> {
  bool _isLoading = false;
  late bool _isAdded;

  @override
  void initState() {
    super.initState();
    // 先检查全局缓存(本次会话内已添加的)
    _isAdded = widget.bvid != null && _addedBvids.contains(widget.bvid);
  }

  Future<void> _toggleWatchLater() async {
    if (_isLoading) {
      return;
    }
    setState(() => _isLoading = true);
    if (_isAdded) {
      // 再次点击 = 取消添加（删除接口要 aid；调用点都传了，防御性兜底）
      final aid = widget.aid;
      if (aid == null) {
        setState(() => _isLoading = false);
        SmartDialog.showToast('无法取消：缺少视频ID');
        return;
      }
      final result = await UserHttp.toViewDel(
        aids: aid.toString(),
        showToast: false,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        if (result.isSuccess) {
          _isAdded = false;
          _addedBvids.remove(widget.bvid);
        }
      });
      if (result.isSuccess) {
        SmartDialog.showToast('已取消稍后再看');
      } else {
        SmartDialog.showToast('取消失败');
      }
      return;
    }
    final result = await UserHttp.toViewLater(
      bvid: widget.bvid,
      aid: widget.aid,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoading = false;
      _isAdded = result.isSuccess;
      if (result.isSuccess && widget.bvid != null) {
        _addedBvids.add(widget.bvid!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: Material(
        color: Colors.black54,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _toggleWatchLater,
          customBorder: const CircleBorder(),
          child: Center(
            child: _isLoading
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    _isAdded
                        ? Icons.check_rounded
                        : Icons.watch_later_outlined,
                    size: 20,
                    color: Colors.white,
                    semanticLabel: _isAdded ? '已添加到稍后再看' : '添加到稍后再看',
                  ),
          ),
        ),
      ),
    );
  }
}
