// lib/presentation/screens/profile/profile_detail_screen.dart
//
// Architecture Appendix F.7.5 — Profile Detail screen wireframe.
//
// ⚠️ Simplification note: Architecture specifies the body overlapping the
// 300px gradient header by exactly 24px via a rounded-top surface panel.
// Implemented here with `Transform.translate(offset: Offset(0, -24))`
// wrapping the body panel — visually matches the spec without needing a
// more complex Stack+Positioned layout.
//
// ⚠️ "First Name | Last Name" from Architecture's original 2-column grid
// is shown as a single "Full Name" cell instead — `ProfileViewData`
// (Phase 6) only exposes `fullName`, since the public-profile path
// (viewing someone else) has no separate first/last name fields in
// `users_public` to begin with (§4.2.B's schema only has combined `n`).
//
// ⚠️ HARDENED for overflow-free rendering at every screen size, font
// scale (0.85 – 1.20 clamped), orientation (portrait + landscape), and
// accessibility setting.
//
// ⚠️ HEADER REDESIGN:
//   • Avatar is centered horizontally with a soft ring + glow.
//   • Name / batch / dept / career chip are all center-aligned.
//   • Header text uses fixed high-contrast whites (NOT colorScheme
//     surface/onSurface, which would flip on light theme and vanish
//     against the navy gradient).
//   • Blood-group badge lives inside the Personal Information grid only.
//
// ⚠️ QUICK ACTIONS REDESIGN:
//   Previously a `Wrap` (left-packs, leftover space on the right).
//   Now a `LayoutBuilder`-driven Row + `spaceEvenly` so all 2–4
//   buttons are distributed evenly across the full width — with an
//   automatic fallback to a wrapped second row if the width can't
//   comfortably fit them all at the current text scale.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_launcher.dart';
import '../../../core/utils/career_status_categories.dart';
import '../../../core/utils/departments_helper.dart';
import '../../../data/models/user/work_experience_model.dart';
import '../../providers/core_providers.dart';
import '../../providers/profile_provider.dart';
import '../../widgets/common/drive_image.dart';
import '../../widgets/common/quick_action_button.dart';
import '../../widgets/common/work_experience_bottom_sheet.dart';
import '../../widgets/common/work_experience_card.dart';
import '../../widgets/skeletons/profile_skeleton.dart';
import 'profile_edit_screen.dart';

class ProfileDetailScreen extends ConsumerWidget {
  final String uid;

  const ProfileDetailScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileViewProvider(uid));

    return Scaffold(
      body: profileAsync.when(
        loading: () => const ProfileSkeleton(),
        error: (e, st) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Could not load this profile: $e',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(profileViewProvider(uid)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (profile) => _ProfileDetailBody(profile: profile),
      ),
    );
  }
}

class _ProfileDetailBody extends ConsumerWidget {
  final ProfileViewData profile;

  const _ProfileDetailBody({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final size = media.size;

    // ⚠️ HARDENED: clamp textScaler tightly. Anyone running the app with
    // a system-wide 200% font is capped at 1.20 here.
    final textScaler = media.textScaler.clamp(
      minScaleFactor: 0.85,
      maxScaleFactor: 1.20,
    );

    // Responsive scale factor — 375 is the design baseline (iPhone SE).
    final shortest = size.width < size.height ? size.width : size.height;
    final scale = (shortest / 375.0).clamp(0.85, 1.15);

    // Landscape? Header height drops.
    final isLandscape = size.width > size.height;
    final headerMinHeight = isLandscape ? 260.0 : 320.0;

    return MediaQuery(
      data: media.copyWith(textScaler: textScaler),
      child: Stack(
        children: [
          SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context, theme,
                    minHeight: headerMinHeight, scale: scale),
                Transform.translate(
                  offset: const Offset(0, -24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    padding: EdgeInsets.all(20 * scale),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildQuickActions(context, scale),
                        SizedBox(height: 20 * scale),
                        _sectionTitle(theme, 'Personal Information'),
                        SizedBox(height: 10 * scale),
                        _buildInfoGrid(theme, scale, [
                          _InfoCell('Full Name', profile.fullName),
                          _InfoCell('Batch', profile.batch),
                          _InfoCell('Blood Group', profile.bloodGroup),
                          _InfoCell('Department',
                              Departments.getShortLabel(profile.department)),
                          _InfoCell('District', profile.district ?? '—'),
                          _InfoCell('Current Location',
                              profile.currentLocation ?? '—'),
                        ]),
                        SizedBox(height: 20 * scale),
                        _sectionTitle(theme, 'Current Job Information'),
                        SizedBox(height: 10 * scale),
                        _buildInfoGrid(theme, scale, [
                          _InfoCell(
                              'Career Status',
                              CareerStatusCategories.getDisplayLabel(
                                  profile.careerStatus)),
                          _InfoCell('Company Type', profile.companyType ?? '—'),
                          _InfoCell('Company', profile.company ?? '—'),
                          _InfoCell('Group', profile.groupOfCompanies ?? '—'),
                          _InfoCell('Designation', profile.designation ?? '—'),
                          _InfoCell(
                              'Job Department', profile.jobDepartment ?? '—'),
                          _InfoCell(
                              'Date of Joining', profile.dateOfJoining ?? '—'),
                          _InfoCell(
                            'Experience',
                            WorkExperienceCalculator.totalExperienceLabel(
                                profile.workExperience),
                          ),
                        ]),
                        SizedBox(height: 20 * scale),
                        _buildWorkExperienceSection(context, ref, theme, scale),
                        if (profile.skills.isNotEmpty) ...[
                          SizedBox(height: 20 * scale),
                          _sectionTitle(theme, 'Skills'),
                          SizedBox(height: 10 * scale),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: profile.skills
                                .map((s) => _SkillChip(label: s))
                                .toList(),
                          ),
                        ],
                        if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                          SizedBox(height: 20 * scale),
                          _sectionTitle(theme, 'About'),
                          SizedBox(height: 10 * scale),
                          _ExpandableBio(bio: profile.bio!),
                        ],
                        SizedBox(height: 32 * scale),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Transparent overlay AppBar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _CircleIconButton(
                    icon: Icons.arrow_back,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  if (profile.isOwnProfile)
                    _CircleIconButton(
                      icon: Icons.edit,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const ProfileEditScreen()),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────
  // HEADER
  // ───────────────────────────────────────────────────────────────────
  Widget _buildHeader(
    BuildContext context,
    ThemeData theme, {
    required double minHeight,
    required double scale,
  }) {
    const headerTop = Color(0xFF1B3A5C);
    const headerBottom = Color(0xFF2E5580);

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [headerTop, headerBottom],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              (60 * scale).clamp(52.0, 72.0),
              20,
              24 * scale,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Avatar (centered) ─────────────────────────
                Center(
                  child: Container(
                    width: 108 * scale,
                    height: 108 * scale,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.08),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.9),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 20 * scale,
                          offset: Offset(0, 8 * scale),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: (profile.photoUrl != null &&
                              profile.photoUrl!.isNotEmpty)
                          ? DriveImage(
                              fileId: profile.photoUrl!,
                              width: 108 * scale,
                              height: 108 * scale,
                            )
                          : Container(
                              color: Colors.white.withValues(alpha: 0.15),
                              alignment: Alignment.center,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(
                                    profile.fullName.isNotEmpty
                                        ? profile.fullName[0]
                                        : '?',
                                    style: const TextStyle(
                                      fontSize: 44,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                ),

                SizedBox(height: 16 * scale),

                // ── Full name ─────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    profile.fullName,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 6 * scale),

                // ── Batch • Department ────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '${profile.batch}'
                    '${profile.department.isNotEmpty ? '  •  ${Departments.getShortLabel(profile.department)}' : ''}',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                SizedBox(height: 12 * scale),

                // ── Career status chip ────────────────────────
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14 * scale,
                    vertical: 6 * scale,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    CareerStatusCategories.getDisplayLabel(
                        profile.careerStatus),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),

                SizedBox(height: 32 * scale),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────
  // QUICK ACTIONS — 2–4 buttons evenly distributed
  // ───────────────────────────────────────────────────────────────────
  Widget _buildQuickActions(BuildContext context, double scale) {
    final actions = <Widget>[];

    if (profile.phone != null && profile.phone!.isNotEmpty) {
      actions.add(QuickActionButton(
        icon: Icons.call,
        label: 'Call',
        onTap: () => AppLauncher.call(context, profile.phone),
      ));
    }
    if (profile.whatsapp != null && profile.whatsapp!.isNotEmpty) {
      actions.add(QuickActionButton(
        icon: Icons.chat,
        label: 'WhatsApp',
        onTap: () => AppLauncher.whatsapp(context, profile.whatsapp),
      ));
    }
    if (profile.linkedIn != null && profile.linkedIn!.isNotEmpty) {
      actions.add(QuickActionButton(
        icon: Icons.business_center,
        label: 'LinkedIn',
        onTap: () => AppLauncher.linkedin(context, profile.linkedIn),
      ));
    }
    if (profile.facebook != null && profile.facebook!.isNotEmpty) {
      actions.add(QuickActionButton(
        icon: Icons.facebook,
        label: 'Facebook',
        onTap: () => AppLauncher.facebook(context, profile.facebook),
      ));
    }

    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    // ⚠️ LayoutBuilder: if the available width can comfortably fit all
    // buttons side-by-side (min ~72dp per button including gap), use a
    // single evenly-distributed Row. If not (narrow device or large
    // font), fall back to a Wrap that flows to a second line.
    return LayoutBuilder(
      builder: (context, constraints) {
        final perButton = 72.0 * scale;
        final fitsInRow = constraints.maxWidth >= perButton * actions.length;

        if (fitsInRow) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: actions,
          );
        }

        return Wrap(
          alignment: WrapAlignment.spaceEvenly,
          spacing: 12 * scale,
          runSpacing: 12 * scale,
          children: actions,
        );
      },
    );
  }

  Widget _buildWorkExperienceSection(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    double scale,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _sectionTitle(theme, 'Work Experience')),
            if (profile.isOwnProfile)
              Flexible(
                child: TextButton.icon(
                  onPressed: () => _openAddExperienceSheet(context, ref),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                ),
              ),
          ],
        ),
        SizedBox(height: 8 * scale),
        if (profile.workExperience.isEmpty)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(24 * scale),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.work_history,
                  size: 48 * scale,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                SizedBox(height: 8 * scale),
                Text(
                  'No work experience added',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                if (profile.isOwnProfile)
                  Text(
                    'Tap Add to add your first job',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          )
        else
          Column(
            children: List.generate(profile.workExperience.length, (i) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom:
                      i == profile.workExperience.length - 1 ? 0 : 12 * scale,
                ),
                child: WorkExperienceCard(
                  experience: profile.workExperience[i],
                  isEditable: profile.isOwnProfile,
                  onEdit: () =>
                      _openEditExperienceSheet(context, ref, index: i),
                  onDelete: () =>
                      _confirmDeleteExperience(context, ref, index: i),
                ),
              );
            }),
          ),
      ],
    );
  }

  void _openAddExperienceSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => WorkExperienceBottomSheet(
        onSave: (newExp) async {
          final updated = [...profile.workExperience, newExp];
          try {
            await ref
                .read(userRepositoryProvider)
                .updateWorkExperience(profile.uid, updated);
            ref.invalidate(profileViewProvider(profile.uid));
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Could not save: $e')),
              );
            }
          }
        },
      ),
    );
  }

  void _openEditExperienceSheet(
    BuildContext context,
    WidgetRef ref, {
    required int index,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => WorkExperienceBottomSheet(
        initialExperience: profile.workExperience[index],
        onSave: (editedExp) async {
          final updated = List.of(profile.workExperience);
          updated[index] = editedExp;
          try {
            await ref
                .read(userRepositoryProvider)
                .updateWorkExperience(profile.uid, updated);
            ref.invalidate(profileViewProvider(profile.uid));
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Could not save: $e')),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _confirmDeleteExperience(
    BuildContext context,
    WidgetRef ref, {
    required int index,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this experience?'),
        content: Text(profile.workExperience[index].companyName),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final updated = List.of(profile.workExperience)..removeAt(index);
    try {
      await ref
          .read(userRepositoryProvider)
          .updateWorkExperience(profile.uid, updated);
      ref.invalidate(profileViewProvider(profile.uid));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete: $e')),
        );
      }
    }
  }

  Widget _sectionTitle(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurface,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildInfoGrid(
    ThemeData theme,
    double scale,
    List<_InfoCell> cells,
  ) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisExtent: 84 * scale,
        crossAxisSpacing: 12 * scale,
        mainAxisSpacing: 12 * scale,
      ),
      itemCount: cells.length,
      itemBuilder: (context, i) {
        final c = cells[i];
        return Container(
          padding: EdgeInsets.all(12 * scale),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                c.label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Flexible(
                child: Text(
                  c.value,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InfoCell {
  final String label;
  final String value;
  const _InfoCell(this.label, this.value);
}

// ─────────────────────────────────────────────────────────────────────
// Skill chip — Material 3 paired container / on-container colours
// ─────────────────────────────────────────────────────────────────────
class _SkillChip extends StatelessWidget {
  final String label;

  const _SkillChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.30),
      shape: const CircleBorder(),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onTap,
        tooltip: icon == Icons.arrow_back ? 'Back' : 'Edit',
      ),
    );
  }
}

class _ExpandableBio extends StatefulWidget {
  final String bio;
  const _ExpandableBio({required this.bio});

  @override
  State<_ExpandableBio> createState() => _ExpandableBioState();
}

class _ExpandableBioState extends State<_ExpandableBio> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.bio,
          maxLines: _expanded ? null : 5,
          overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            child: Text(_expanded ? 'Show less' : 'Read more'),
          ),
        ),
      ],
    );
  }
}
