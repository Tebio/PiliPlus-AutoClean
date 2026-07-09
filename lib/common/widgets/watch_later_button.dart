import 'package:PiliPlus/http/user.dart';
import 'package:PiliPlus/models_new/later/list.dart' show LaterData;
import 'package:PiliPlus/http/loading_state.dart' show LoadingState;
import 'package:flutter/material.dart';

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

  Future<void> _addToWatchLater() async {
    if (_isLoading || _isAdded) {
      return;
    }
    setState(() => _isLoading = true);
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
          onTap: _addToWatchLater,
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
