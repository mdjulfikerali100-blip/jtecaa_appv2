// lib/presentation/widgets/common/drive_image.dart
//
// Architecture Appendix J.3 — drop-in replacement for
// `CachedNetworkImage` when the source is a Google Drive fileId (never a
// direct URL — those are CORS-blocked, §5.4). Usage:
// `DriveImage(fileId: alumni.photoUrl!)`.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../../data/datasources/external/drive_image_service.dart';
import '../../providers/core_providers.dart';

class DriveImage extends ConsumerStatefulWidget {
  final String fileId;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? errorWidget;
  final Widget? placeholder;

  const DriveImage({
    super.key,
    required this.fileId,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.errorWidget,
    this.placeholder,
  });

  @override
  ConsumerState<DriveImage> createState() => _DriveImageState();
}

class _DriveImageState extends ConsumerState<DriveImage> {
  DriveImageData? _data;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(DriveImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fileId != widget.fileId) {
      _data = null;
      _failed = false;
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final data =
          await ref.read(driveImageServiceProvider).getImage(widget.fileId);
      if (mounted) {
        setState(() => _data = data);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _failed = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return widget.errorWidget ??
          Container(
            width: widget.width,
            height: widget.height,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Icon(Icons.broken_image_outlined),
          );
    }
    if (_data == null) {
      final theme = Theme.of(context);
      return widget.placeholder ??
          Shimmer.fromColors(
            baseColor: theme.colorScheme.surfaceContainerHighest,
            highlightColor: theme.colorScheme.surface,
            child: Container(
                width: widget.width,
                height: widget.height,
                color: Colors.white),
          );
    }
    return Image.memory(
      _data!.bytes,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      gaplessPlayback: true, // avoids flicker on rebuild
    );
  }
}
