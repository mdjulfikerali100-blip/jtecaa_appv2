// lib/presentation/screens/news/post_news_screen.dart
//
// Post / Edit News form — optional cover image (gallery picker +
// best-effort compression + Drive upload), Title, Body, and an
// auto-delete window that only applies to new posts.

import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../data/models/news/news_model.dart';
import '../../providers/core_providers.dart';
import '../../providers/news_provider.dart';
import '../../providers/profile_provider.dart' show profileViewProvider;
import '../../widgets/common/drive_image.dart';

class PostNewsScreen extends ConsumerStatefulWidget {
  final NewsModel? existingNews; // null = create mode, non-null = edit mode

  const PostNewsScreen({super.key, this.existingNews});

  @override
  ConsumerState<PostNewsScreen> createState() => _PostNewsScreenState();
}

class _PostNewsScreenState extends ConsumerState<PostNewsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  int _autoDeleteDays = 7;

  String?
      _imageFileId; // existing Drive fileId (edit mode) or newly uploaded one
  Uint8List? _pendingImageBytes; // picked-but-not-yet-uploaded preview bytes
  bool _saving = false;
  bool _uploadingImage = false;

  bool get _isEditMode => widget.existingNews != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingNews;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _bodyController = TextEditingController(text: existing?.body ?? '');
    _autoDeleteDays = existing?.autoDeleteDays ?? 7;
    _imageFileId = existing?.imageUrl;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 90,
    );
    if (picked == null) return;

    // ⚠️ Web-safe: readAsBytes() works on every platform, unlike
    // File(picked.path) which throws on Flutter Web (Appendix J.4 note,
    // applied here per Addendum §6's explicit instruction).
    final rawBytes = await picked.readAsBytes();

    setState(() {
      _pendingImageBytes = rawBytes; // instant local preview
      _uploadingImage = true;
    });

    try {
      Uint8List compressed;
      try {
        final result = await FlutterImageCompress.compressWithList(
          rawBytes,
          minWidth: 1024,
          quality: 80,
          format: CompressFormat.jpeg,
        );
        compressed = result;
      } catch (_) {
        // ⚠️ Best-effort compression: some platforms/formats can throw
        // here (e.g. certain Web codecs) — fall back to the original
        // bytes rather than blocking the whole post over a cosmetic
        // file-size optimization.
        compressed = rawBytes;
      }

      final fileId = await ref.read(driveImageServiceProvider).uploadImage(
            bytes: compressed,
            filename: 'news_${DateTime.now().millisecondsSinceEpoch}',
            mimeType: 'image/jpeg',
          );

      if (!mounted) return;
      setState(() {
        _imageFileId = fileId;
        _uploadingImage = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploadingImage = false;
        _pendingImageBytes = null;
      });
      _showError('Image upload failed: $e');
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;
    if (_uploadingImage) {
      _showError('Please wait for the image to finish uploading');
      return;
    }

    setState(() => _saving = true);

    final notifier = ref.read(newsActionsProvider.notifier);
    bool ok;

    if (_isEditMode) {
      final updated = widget.existingNews!.copyWith(
        title: _titleController.text.trim(),
        body: _bodyController.text.trim(),
        imageUrl: _imageFileId,
      );
      // ⚠️ Uses toEditBody() internally (NewsRepository.editNews) — only
      // id/title/body/image_url are sent, matching Apps Script's editNews()
      // (Addendum §6 design decision, NewsModel §toEditBody doc comment).
      ok = await notifier.edit(updated);
    } else {
      final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      // Cache-first read (§2 "never fetch when you have cache") —
      // profileViewProvider(uid) calls getMyProfile(uid) with no forced
      // refresh when uid == the signed-in user (profile_provider.dart's
      // own routing logic), so this costs zero extra reads on a normal
      // "Post News" tap right after opening the app.
      final myProfile = currentUid.isEmpty
          ? null
          : ref.read(profileViewProvider(currentUid)).value;

      ok = await notifier.post(
        title: _titleController.text.trim(),
        body: _bodyController.text.trim(),
        imageFileId: _imageFileId,
        postedByUid: currentUid,
        postedByName: myProfile?.fullName ?? 'Alumni',
        postedByBatch: myProfile?.batch ?? '',
        autoDeleteDays: _autoDeleteDays,
      );
    }

    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      Navigator.pop(context);
    } else {
      _showError(_isEditMode
          ? 'Update failed — try again'
          : 'Post failed — try again');
    }
  }

  void _showError(String message) {
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: colorScheme.errorContainer,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          _isEditMode ? 'Edit News' : 'Post News',
          style: theme.textTheme.titleLarge?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        iconTheme: IconThemeData(
          color: colorScheme.onSurface,
          size: 24,
        ),
        actions: [
          // ✅ Theme-safe SAVE — was `Colors.white` (invisible in light).
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.primary,
                      ),
                    )
                  : const Icon(Icons.check_rounded, size: 18),
              label: Text(
                _saving ? 'Saving…' : 'Save',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxContentWidth =
                  constraints.maxWidth > 640 ? 560.0 : constraints.maxWidth;
              final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

              return Center(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    constraints.maxWidth > 640 ? 32 : 20,
                    20,
                    constraints.maxWidth > 640 ? 32 : 20,
                    32 + bottomInset,
                  ),
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxContentWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── Section: Cover Image ───────────────────
                          _SectionHeader(
                            icon: Icons.image_outlined,
                            label: 'Cover Image',
                            trailing: Text(
                              'Optional',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            textTheme: theme.textTheme,
                            colorScheme: colorScheme,
                          ),
                          const SizedBox(height: 14),

                          _ImagePickerCard(
                            uploading: _uploadingImage,
                            pendingBytes: _pendingImageBytes,
                            fileId: _imageFileId,
                            onPick: _pickImage,
                            onRemove: (_pendingImageBytes != null ||
                                    _imageFileId != null)
                                ? () => setState(() {
                                      _pendingImageBytes = null;
                                      _imageFileId = null;
                                    })
                                : null,
                            colorScheme: colorScheme,
                            textTheme: theme.textTheme,
                          ),
                          const SizedBox(height: 28),

                          // ── Section: Content ───────────────────────
                          _SectionHeader(
                            icon: Icons.edit_note_outlined,
                            label: 'Content',
                            textTheme: theme.textTheme,
                            colorScheme: colorScheme,
                          ),
                          const SizedBox(height: 14),

                          TextFormField(
                            controller: _titleController,
                            textInputAction: TextInputAction.next,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              labelText: 'Title',
                              hintText: 'Headline for this update',
                              prefixIcon: Icon(Icons.title_rounded),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Title is required'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _bodyController,
                            textInputAction: TextInputAction.newline,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              labelText: 'Body',
                              hintText: 'Write the full update here…',
                              alignLabelWithHint: true,
                            ),
                            maxLines: 10,
                            minLines: 5,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Body is required'
                                : null,
                          ),

                          // ── Section: Post Visibility (create only) ─
                          if (!_isEditMode) ...[
                            const SizedBox(height: 28),
                            _SectionHeader(
                              icon: Icons.schedule_outlined,
                              label: 'Visibility',
                              textTheme: theme.textTheme,
                              colorScheme: colorScheme,
                            ),
                            const SizedBox(height: 14),
                            DropdownButtonFormField<int>(
                              initialValue: _autoDeleteDays,
                              decoration: const InputDecoration(
                                labelText: 'Auto-delete after',
                                prefixIcon: Icon(Icons.timer_outlined),
                              ),
                              items: const [3, 7, 14, 30]
                                  .map((d) => DropdownMenuItem(
                                        value: d,
                                        child: Text(
                                          '$d days',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _autoDeleteDays = v ?? 7),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'This post will automatically disappear from '
                              'the News feed after $_autoDeleteDays days.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Presentational helpers (no business logic).
// ─────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.textTheme,
    required this.colorScheme,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final TextTheme textTheme;
  final ColorScheme colorScheme;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: colorScheme.onPrimaryContainer),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            label,
            style: textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        if (trailing != null)
          trailing!
        else
          Expanded(
            child: Container(
              height: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
      ],
    );
  }
}

/// Tappable image picker / preview card.
/// States: empty → pick prompt; uploading → preview + overlay spinner;
/// set → preview + "Change"/"Remove" chips at the bottom.
class _ImagePickerCard extends StatelessWidget {
  const _ImagePickerCard({
    required this.uploading,
    required this.pendingBytes,
    required this.fileId,
    required this.onPick,
    required this.onRemove,
    required this.colorScheme,
    required this.textTheme,
  });

  final bool uploading;
  final Uint8List? pendingBytes;
  final String? fileId;
  final VoidCallback onPick;
  final VoidCallback? onRemove;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final hasImage = pendingBytes != null || fileId != null;

    return AspectRatio(
      // 16:9 — natural aspect for a cover image and consistent across
      // screen sizes (better than a fixed 180px height).
      aspectRatio: 16 / 9,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: uploading ? null : onPick,
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasImage
                    ? colorScheme.outlineVariant
                    : colorScheme.outlineVariant.withValues(alpha: 0.8),
                width: 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildContent(hasImage),
                if (uploading) _uploadingOverlay(),
                if (hasImage && !uploading)
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _MiniActionChip(
                          icon: Icons.edit_outlined,
                          label: 'Change',
                          colorScheme: colorScheme,
                          onTap: onPick,
                        ),
                        if (onRemove != null) ...[
                          const SizedBox(width: 6),
                          _MiniActionChip(
                            icon: Icons.close_rounded,
                            label: 'Remove',
                            colorScheme: colorScheme,
                            onTap: onRemove!,
                            destructive: true,
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(bool hasImage) {
    if (pendingBytes != null) {
      return Image.memory(pendingBytes!, fit: BoxFit.cover);
    }
    if (fileId != null) {
      return DriveImage(
        fileId: fileId!,
        fit: BoxFit.cover,
        width: double.infinity,
      );
    }
    // Empty state — pick prompt.
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_photo_alternate_outlined,
                size: 26,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Add a cover photo',
              textAlign: TextAlign.center,
              style: textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'Optional — tap to choose from gallery',
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _uploadingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.4),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              strokeWidth: 2.6,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Uploading…',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small chip used over the image for Change / Remove actions.
class _MiniActionChip extends StatelessWidget {
  const _MiniActionChip({
    required this.icon,
    required this.label,
    required this.colorScheme,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final ColorScheme colorScheme;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final bg = destructive
        ? colorScheme.errorContainer.withValues(alpha: 0.95)
        : colorScheme.surface.withValues(alpha: 0.95);
    final fg =
        destructive ? colorScheme.onErrorContainer : colorScheme.onSurface;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: fg,
                  letterSpacing: 0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
