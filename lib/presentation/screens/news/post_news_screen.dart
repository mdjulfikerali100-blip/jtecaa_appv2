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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image upload failed: $e')),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_uploadingImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please wait for the image to finish uploading')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_isEditMode
                ? 'Update failed — try again'
                : 'Post failed — try again')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit News' : 'Post News'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('SAVE', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Image picker/preview
            GestureDetector(
              onTap: _uploadingImage ? null : _pickImage,
              child: Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: _buildImagePreview(theme),
              ),
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Title is required' : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _bodyController,
              decoration: const InputDecoration(
                  labelText: 'Body', alignLabelWithHint: true),
              maxLines: 8,
              minLines: 4,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Body is required' : null,
            ),
            const SizedBox(height: 16),

            // Auto-delete days — only meaningful for a new post; the
            // Apps Script editNews() (§6) never changes this on an edit,
            // so it's hidden entirely in edit mode rather than shown but
            // silently ignored.
            if (!_isEditMode)
              DropdownButtonFormField<int>(
                initialValue:
                    _autoDeleteDays, // ⚠️ K.5 — `value:` is deprecated (Addendum §3.9)
                decoration:
                    const InputDecoration(labelText: 'Auto-delete after'),
                items: const [3, 7, 14, 30]
                    .map((d) =>
                        DropdownMenuItem(value: d, child: Text('$d days')))
                    .toList(),
                onChanged: (v) => setState(() => _autoDeleteDays = v ?? 7),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview(ThemeData theme) {
    if (_uploadingImage && _pendingImageBytes != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(_pendingImageBytes!, fit: BoxFit.cover),
          Container(
            color: Colors.black38,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
        ],
      );
    }
    if (_imageFileId != null) {
      return DriveImage(
          fileId: _imageFileId!, fit: BoxFit.cover, width: double.infinity);
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_photo_alternate_outlined,
              size: 40, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(
            'Add a photo (optional)',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
