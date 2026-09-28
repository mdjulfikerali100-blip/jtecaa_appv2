// lib/presentation/screens/student/my_profile_screen.dart
//
// Architecture §M.7 — "Unlike Jobs/News... a Student may edit their own
// info whenever they like." No restriction window, no approval step —
// every field here can be changed and saved immediately.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/districts.dart';
import '../../../core/utils/phone_validator.dart';
import '../../../data/models/user/student_profile_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../widgets/common/blood_group_dropdown_field.dart';

/// Cache-first fetch of the signed-in Student's own profile
/// (StudentProfileRepository already implements the Hive-first, 12h-TTL
/// logic internally per §M.7 — this provider is a thin Riverpod wrapper).
final myStudentProfileProvider =
    FutureProvider.autoDispose<StudentProfileModel>((ref) async {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) {
    throw StateError('myStudentProfileProvider watched while signed out.');
  }
  return ref.watch(studentProfileRepositoryProvider).getMyProfile(uid);
});

class MyProfileScreen extends ConsumerWidget {
  const MyProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final profileAsync = ref.watch(myStudentProfileProvider);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'My Profile',
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
        iconTheme: IconThemeData(color: colorScheme.onSurface, size: 24),
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => _ErrorState(
          error: e,
          onRetry: () => ref.invalidate(myStudentProfileProvider),
          colorScheme: colorScheme,
          textTheme: theme.textTheme,
        ),
        data: (profile) => _MyProfileForm(profile: profile),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// ERROR STATE — icon chip + retry, replaced the bare red text
// ─────────────────────────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _ErrorState({
    required this.error,
    required this.onRetry,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color:
                            colorScheme.errorContainer.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.error_outline_rounded,
                        size: 40,
                        color: colorScheme.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Could not load your profile',
                      textAlign: TextAlign.center,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      error.toString(),
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Retry'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(120, 44),
                        side: BorderSide(
                          color: colorScheme.outline,
                          width: 1.2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        foregroundColor: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MyProfileForm extends ConsumerStatefulWidget {
  final StudentProfileModel profile;
  const _MyProfileForm({required this.profile});

  @override
  ConsumerState<_MyProfileForm> createState() => _MyProfileFormState();
}

class _MyProfileFormState extends ConsumerState<_MyProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _locationController;
  String? _bloodGroup;
  String? _district;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.profile.fullName);
    _phoneController = TextEditingController(text: widget.profile.phone);
    _locationController =
        TextEditingController(text: widget.profile.currentLocation ?? '');
    _bloodGroup = widget.profile.bloodGroup;
    _district = widget.profile.district;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isSaving = true);

    try {
      await ref.read(studentProfileRepositoryProvider).updateMyProfile(
        widget.profile.uid,
        {
          'full_name': _fullNameController.text.trim().toUpperCase(),
          'phone': PhoneValidator.normalize(_phoneController.text) ?? '',
          'blood_group': _bloodGroup ?? '',
          'district': _district ?? '',
          'current_location': _locationController.text.trim(),
        },
      );
      ref.invalidate(myStudentProfileProvider);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile updated.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      final colorScheme = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Could not save: $e',
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
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Form(
      key: _formKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Constrain on tablets / desktop for line-length comfort.
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
                      // ── Identity header chip (visual only) ─────────
                      _ProfileHeaderCard(
                        fullName: widget.profile.fullName,
                        email: widget.profile.email,
                        batch: widget.profile.batch,
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                      ),
                      const SizedBox(height: 28),

                      // ── Section: Editable info ────────────────────
                      _SectionHeader(
                        icon: Icons.person_outline_rounded,
                        label: 'Personal Information',
                        textTheme: textTheme,
                        colorScheme: colorScheme,
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _fullNameController,
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),

                      // Email is not editable — it's the Firebase Auth
                      // identity, not a Sheet field a Student can freely
                      // change from this screen.
                      TextFormField(
                        initialValue: widget.profile.email,
                        enabled: false,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                          helperText: 'Managed by your account',
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        initialValue: widget.profile.batch,
                        enabled: false,
                        // Batch is fixed at signup, matches the verified ID
                        decoration: const InputDecoration(
                          labelText: 'Batch',
                          prefixIcon: Icon(Icons.school_outlined),
                          helperText: 'Locked to your verified ID',
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.telephoneNumber],
                        decoration: const InputDecoration(
                          labelText: 'Contact Number',
                          hintText: '0171XXXXXXX',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                        validator: PhoneValidator.getErrorMessage,
                      ),

                      const SizedBox(height: 28),

                      // ── Section: Additional info ──────────────────
                      _SectionHeader(
                        icon: Icons.badge_outlined,
                        label: 'Additional Details',
                        textTheme: textTheme,
                        colorScheme: colorScheme,
                      ),
                      const SizedBox(height: 16),

                      BloodGroupDropdownField(
                        value: _bloodGroup,
                        onChanged: (v) => setState(() => _bloodGroup = v),
                        validator: (v) => null, // optional, §M.4
                      ),
                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _district,
                        decoration: const InputDecoration(
                          labelText: 'District (optional)',
                          prefixIcon: Icon(Icons.map_outlined),
                        ),
                        items: Districts.all
                            .map((d) => DropdownMenuItem(
                                  value: d,
                                  child: Text(
                                    d,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _district = v),
                        borderRadius: BorderRadius.circular(14),
                        dropdownColor: colorScheme.surfaceContainerHigh,
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _locationController,
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.words,
                        maxLength: 80,
                        decoration: const InputDecoration(
                          labelText: 'Current Location (optional)',
                          hintText: 'e.g. Sher e Bangla Hall, JTEC',
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── Save ─────────────────────────────────────
                      _SaveButton(
                        isSaving: _isSaving,
                        onPressed: _save,
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Changes go live immediately — no approval needed.',
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Presentational helpers (no business logic).
// ─────────────────────────────────────────────────────────────────────

/// Compact header card: avatar + name + email + batch pill.
class _ProfileHeaderCard extends StatelessWidget {
  final String fullName;
  final String email;
  final String batch;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _ProfileHeaderCard({
    required this.fullName,
    required this.email,
    required this.batch,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    final initial =
        fullName.trim().isNotEmpty ? fullName.trim()[0].toUpperCase() : '?';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer.withValues(alpha: 0.7),
            colorScheme.primaryContainer.withValues(alpha: 0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.primary.withValues(alpha: 0.15),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.30),
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: textTheme.titleLarge?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fullName.isNotEmpty ? fullName : 'Student',
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (batch.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      batch,
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Section header — icon chip + label + trailing divider.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.textTheme,
    required this.colorScheme,
  });

  final IconData icon;
  final String label;
  final TextTheme textTheme;
  final ColorScheme colorScheme;

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

/// Elevated Save button with a press-scale micro-interaction.
class _SaveButton extends StatefulWidget {
  const _SaveButton({
    required this.isSaving,
    required this.onPressed,
    required this.colorScheme,
    required this.textTheme,
  });

  final bool isSaving;
  final VoidCallback onPressed;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  State<_SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<_SaveButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: widget.isSaving ? null : widget.onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.colorScheme.primary,
              foregroundColor: widget.colorScheme.onPrimary,
              disabledBackgroundColor:
                  widget.colorScheme.primary.withValues(alpha: 0.5),
              disabledForegroundColor:
                  widget.colorScheme.onPrimary.withValues(alpha: 0.8),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: widget.isSaving
                ? SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: widget.colorScheme.onPrimary,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_rounded,
                        size: 20,
                        color: widget.colorScheme.onPrimary,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'SAVE CHANGES',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: widget.textTheme.labelLarge?.copyWith(
                            color: widget.colorScheme.onPrimary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
