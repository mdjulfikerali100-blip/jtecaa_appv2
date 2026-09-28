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

  /// Optional border radius — set this instead of wrapping the widget in
  /// a ClipRRect when you want the placeholder & error states to share
  /// the same rounded shape. Non-breaking: default `null` = no clipping,
  /// exactly like before.
  final BorderRadius? borderRadius;

  const DriveImage({
    super.key,
    required this.fileId,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.errorWidget,
    this.placeholder,
    this.borderRadius,
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
    final child = _buildChild(context);
    final radius = widget.borderRadius;

    // No radius requested → skip the wrapper entirely (zero extra cost).
    if (radius == null) return child;

    return ClipRRect(
      borderRadius: radius,
      child: child,
    );
  }

  Widget _buildChild(BuildContext context) {
    if (_failed) {
      return widget.errorWidget ??
          _DefaultError(
            width: widget.width,
            height: widget.height,
          );
    }
    if (_data == null) {
      return widget.placeholder ??
          _DefaultPlaceholder(
            width: widget.width,
            height: widget.height,
          );
    }
    return Image.memory(
      _data!.bytes,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      gaplessPlayback: true, // avoids flicker on rebuild
      // Prevent decode-time blurring on high-DPI screens; Image.memory
      // picks the source scale automatically, but this makes the intent
      // explicit and keeps memory bounded for very large images.
      filterQuality: FilterQuality.medium,
      // Graceful degradation if bytes are somehow corrupt.
      errorBuilder: (_, __, ___) =>
          widget.errorWidget ??
          _DefaultError(
            width: widget.width,
            height: widget.height,
          ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Default placeholder & error — theme-safe in both light and dark mode.
// ─────────────────────────────────────────────────────────────────────────

class _DefaultPlaceholder extends StatelessWidget {
  const _DefaultPlaceholder({this.width, this.height});

  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Shimmer.fromColors(
      baseColor: colorScheme.surfaceContainerHighest,
      highlightColor: colorScheme.surfaceContainerHigh,
      child: Container(
        width: width,
        height: height,
        // ✅ Theme-aware — was `Colors.white`, which flashed white in
        // dark mode before the shimmer layer painted over it.
        color: colorScheme.surfaceContainerHighest,
      ),
    );
  }
}

class _DefaultError extends StatelessWidget {
  const _DefaultError({this.width, this.height});

  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: width,
      height: height,
      color: colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        Icons.broken_image_outlined,
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
      ),
    );
  }
}
