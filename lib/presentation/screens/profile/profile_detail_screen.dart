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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_launcher.dart';
import '../../../core/utils/career_status_categories.dart';
import '../../../core/utils/departments_helper.dart';
import '../../../data/models/user/work_experience_model.dart'; // ⚠️ NEW — WorkExperienceCalculator
import '../../providers/core_providers.dart';
import '../../providers/profile_provider.dart';
import '../../widgets/common/blood_group_badge.dart';
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
                Text('Could not load this profile: $e',
                    textAlign: TextAlign.center),
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

    return Stack(
      children: [
        SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(context, theme),
              Transform.translate(
                offset: const Offset(0, -24),
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildQuickActions(context),
                      const SizedBox(height: 24),
                      _sectionTitle(theme, 'Personal Information'),
                      const SizedBox(height: 12),
                      _buildInfoGrid(theme, [
                        _InfoCell('Full Name', profile.fullName),
                        _InfoCell('Batch', profile.batch),
                        _InfoCell('Blood Group', profile.bloodGroup),
                        _InfoCell('Department',
                            Departments.getShortLabel(profile.department)),
                        _InfoCell('District', profile.district ?? '—'),
                        _InfoCell(
                            'Current Location', profile.currentLocation ?? '—'),
                      ]),
                      const SizedBox(height: 24),
                      _sectionTitle(theme, 'Current Job Information'),
                      const SizedBox(height: 12),
                      _buildInfoGrid(theme, [
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
                        // ⚠️ Date of Joining only ever has a value on the
                        // OWN-profile path (see file header) — showing
                        // "—" for someone else's profile rather than
                        // omitting the cell keeps the grid's 2-column
                        // layout stable regardless of whose profile this is.
                        _InfoCell(
                            'Date of Joining', profile.dateOfJoining ?? '—'),
                        // ⚠️ FIX (root cause): this used to read the raw
                        // `experienceYears` field, which nothing in the
                        // app ever sets or edits — it was always null,
                        // so this cell showed "—" even when real Work
                        // Experience entries existed below. Appendix
                        // L.1.5's whole point is computing total
                        // experience FROM those entries — using
                        // WorkExperienceCalculator here (already used on
                        // the Directory Card's badge) instead of the
                        // dead `experienceYears` field.
                        _InfoCell(
                          'Experience',
                          WorkExperienceCalculator.totalExperienceLabel(
                              profile.workExperience),
                        ),
                      ]),
                      const SizedBox(height: 24),
                      _buildWorkExperienceSection(context, ref, theme),
                      if (profile.skills.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _sectionTitle(theme, 'Skills'),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: profile.skills
                              .map((s) => Chip(
                                    label: Text(s),
                                    backgroundColor:
                                        theme.colorScheme.primaryContainer,
                                  ))
                              .toList(),
                        ),
                      ],
                      if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _sectionTitle(theme, 'About'),
                        const SizedBox(height: 12),
                        _ExpandableBio(bio: profile.bio!),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Transparent overlay AppBar (Architecture: "overlay on header").
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _CircleIconButton(
                    icon: Icons.arrow_back,
                    onTap: () => Navigator.of(context).maybePop()),
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
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Container(
      height: 300,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.85)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          if (profile.bloodGroup.isNotEmpty)
            Positioned(
              top: 56,
              right: 16,
              child: BloodGroupBadge(bloodGroup: profile.bloodGroup),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: ClipOval(
                      child: (profile.photoUrl != null &&
                              profile.photoUrl!.isNotEmpty)
                          ? DriveImage(
                              fileId: profile.photoUrl!,
                              width: 100,
                              height: 100)
                          : Container(
                              color: Colors.white24,
                              alignment: Alignment.center,
                              child: Text(
                                profile.fullName.isNotEmpty
                                    ? profile.fullName[0]
                                    : '?',
                                style: const TextStyle(
                                    fontSize: 36,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    profile.fullName,
                    style: theme.textTheme.headlineMedium
                        ?.copyWith(color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${profile.batch} • ${Departments.getShortLabel(profile.department)}',
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(color: Colors.white.withValues(alpha: 0.8)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      CareerStatusCategories.getDisplayLabel(
                          profile.careerStatus),
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: Colors.white),
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

  Widget _buildQuickActions(BuildContext context) {
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
    return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: actions);
  }

  Widget _buildWorkExperienceSection(
      BuildContext context, WidgetRef ref, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _sectionTitle(theme, 'Work Experience')),
            if (profile.isOwnProfile)
              TextButton.icon(
                onPressed: () => _openAddExperienceSheet(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (profile.workExperience.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(Icons.work_history,
                    size: 48, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(height: 8),
                Text('No work experience added',
                    style: theme.textTheme.bodyMedium),
                if (profile.isOwnProfile)
                  Text(
                    'Tap Add to add your first job',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: profile.workExperience.length,
              itemBuilder: (context, i) => WorkExperienceCard(
                experience: profile.workExperience[i],
                // ⚠️ CHANGED: own-profile entries are now editable
                // directly from Profile Detail (Edit + Delete), not just
                // read-only with a separate "+Add" — matches the same
                // immediate-persist pattern as adding a new entry.
                isEditable: profile.isOwnProfile,
                onEdit: () => _openEditExperienceSheet(context, ref, index: i),
                onDelete: () =>
                    _confirmDeleteExperience(context, ref, index: i),
              ),
            ),
          ),
      ],
    );
  }

  void _openAddExperienceSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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

  /// ⚠️ NEW — edits one existing entry in place, persisting immediately
  /// (same pattern as _openAddExperienceSheet), rather than requiring a
  /// trip through the full Profile Edit screen just to fix one job entry.
  void _openEditExperienceSheet(BuildContext context, WidgetRef ref,
      {required int index}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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

  /// ⚠️ NEW — delete with confirmation, persisting immediately.
  Future<void> _confirmDeleteExperience(BuildContext context, WidgetRef ref,
      {required int index}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this experience?'),
        content: Text(profile.workExperience[index].companyName),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
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
    return Text(title,
        style:
            theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600));
  }

  Widget _buildInfoGrid(ThemeData theme, List<_InfoCell> cells) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.6,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: cells.map((c) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                c.label,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                c.value,
                style: theme.textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _InfoCell {
  final String label;
  final String value;
  const _InfoCell(this.label, this.value);
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black26,
      shape: const CircleBorder(),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onTap,
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
      children: [
        Text(
          widget.bio,
          maxLines: _expanded ? null : 5,
          overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge,
        ),
        TextButton(
          onPressed: () => setState(() => _expanded = !_expanded),
          child: Text(_expanded ? 'Show less' : 'Read more'),
        ),
      ],
    );
  }
}
