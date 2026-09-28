// lib/presentation/screens/directory/directory_screen.dart
//
// Architecture §7.3 (Alumni Directory) + Appendix F.7.4 (screen wireframe)
// + L.1.3/L.1.4 (search/filter upgrade).
//
// ⚠️ PREMIUM FILTER SHEET (this revision):
//   Restructured the filter sheet for a cleaner, more premium look:
//     • Grouped fields under section headers ("Basic Filters",
//       "Job Information") — makes the 6 dropdowns scannable.
//     • Filled-style dropdowns (surfaceContainerHighest) with no
//       outline — reads as tap-able rows rather than form inputs.
//     • Extra vertical rhythm (16dp between fields, 24dp between
//       sections) so nothing feels cramped.
//     • Active filter highlight — a coloured left border + tinted
//       background on any dropdown whose value is non-null, so a
//       user can see at a glance which filters are set.
//     • Footer buttons promoted to 48dp tall with a filled Apply
//       and tonal Clear All — matches Material 3 button guidelines
//       and clears the home indicator via SafeArea bottom.
//     • Sheet height raised to 0.85 so more of the list is visible
//       before scrolling; the field list itself scrolls.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/career_status_categories.dart';
import '../../../core/utils/company_types.dart';
import '../../../core/utils/departments_helper.dart';
import '../../../core/utils/districts.dart';
import '../../../core/utils/job_departments.dart';
import '../../providers/directory_provider.dart';
import '../../widgets/common/alumni_directory_card.dart';
import '../../widgets/common/batch_dropdown_field.dart';
import '../../widgets/skeletons/directory_skeleton.dart';
import '../profile/profile_detail_screen.dart';

class DirectoryScreen extends ConsumerStatefulWidget {
  const DirectoryScreen({super.key});

  @override
  ConsumerState<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends ConsumerState<DirectoryScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        ref.read(directoryNotifierProvider.notifier).loadNextPage();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(directoryNotifierProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alumni Directory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Filter',
            onPressed: () => _openFilterSheet(context, state),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SizedBox(
              height: 48,
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                maxLines: 1,
                onChanged: (v) => ref
                    .read(directoryNotifierProvider.notifier)
                    .setSearchQuery(v),
                decoration: InputDecoration(
                  hintText: 'Search by name, company, group...',
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onPrimaryContainer
                        .withValues(alpha: 0.65),
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.primaryContainer,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                ),
                style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (state.hasActiveFilters) _buildActiveFiltersRow(context, state),
          Expanded(child: _buildBody(context, state)),
        ],
      ),
    );
  }

  Widget _buildActiveFiltersRow(BuildContext context, DirectoryState state) {
    final theme = Theme.of(context);
    final notifier = ref.read(directoryNotifierProvider.notifier);
    final chips = <Widget>[];

    void addChip(String? value, VoidCallback onRemove) {
      if (value == null) return;
      chips.add(Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Chip(
          label: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          backgroundColor: theme.colorScheme.secondaryContainer,
          deleteIconColor: theme.colorScheme.onSecondaryContainer,
          side: BorderSide(
            color: theme.colorScheme.secondary.withValues(alpha: 0.35),
            width: 0.8,
          ),
          onDeleted: onRemove,
        ),
      ));
    }

    addChip(
      state.departmentFilter != null
          ? Departments.getShortLabel(state.departmentFilter)
          : null,
      () => notifier.applyServerFilters(
        batch: state.batchFilter,
        district: state.districtFilter,
        careerStatus: state.careerStatusFilter,
      ),
    );
    addChip(
      state.batchFilter,
      () => notifier.applyServerFilters(
        department: state.departmentFilter,
        district: state.districtFilter,
        careerStatus: state.careerStatusFilter,
      ),
    );
    addChip(
      state.districtFilter,
      () => notifier.applyServerFilters(
        department: state.departmentFilter,
        batch: state.batchFilter,
        careerStatus: state.careerStatusFilter,
      ),
    );
    addChip(
      state.careerStatusFilter != null
          ? CareerStatusCategories.getDisplayLabel(state.careerStatusFilter!)
          : null,
      () => notifier.applyServerFilters(
        department: state.departmentFilter,
        batch: state.batchFilter,
        district: state.districtFilter,
      ),
    );
    addChip(state.companyTypeFilter, () => notifier.setCompanyTypeFilter(null));
    addChip(
        state.jobDepartmentFilter, () => notifier.setJobDepartmentFilter(null));

    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: chips,
      ),
    );
  }

  Widget _buildBody(BuildContext context, DirectoryState state) {
    if (state.isLoading && state.items.isEmpty) {
      return const DirectorySkeleton();
    }
    if (state.error != null && state.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Could not load the directory: ${state.error}',
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => ref
                    .read(directoryNotifierProvider.notifier)
                    .loadFirstPage(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final visible = state.filtered;
    if (visible.isEmpty) {
      final theme = Theme.of(context);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off,
                  size: 64, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text('No alumni found', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Try adjusting your search or filters',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(directoryNotifierProvider.notifier).loadFirstPage(),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: visible.length + (state.isLoadingMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= visible.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return AlumniDirectoryCard(
            alumni: visible[i],
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => ProfileDetailScreen(uid: visible[i].uid)),
            ),
          );
        },
      ),
    );
  }

  void _openFilterSheet(BuildContext context, DirectoryState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.85,
        child: _FilterSheet(initialState: state),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// FILTER SHEET — premium redesign
// ─────────────────────────────────────────────────────────────────────
class _FilterSheet extends ConsumerStatefulWidget {
  final DirectoryState initialState;
  const _FilterSheet({required this.initialState});

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  String? _department;
  String? _batch;
  String? _district;
  String? _companyType;
  String? _jobDepartment;
  String? _careerStatus;

  @override
  void initState() {
    super.initState();
    _department = widget.initialState.departmentFilter;
    _batch = widget.initialState.batchFilter;
    _district = widget.initialState.districtFilter;
    _companyType = widget.initialState.companyTypeFilter;
    _jobDepartment = widget.initialState.jobDepartmentFilter;
    _careerStatus = widget.initialState.careerStatusFilter;
  }

  bool get _hasAnySelection =>
      _department != null ||
      _batch != null ||
      _district != null ||
      _companyType != null ||
      _jobDepartment != null ||
      _careerStatus != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final bottomInset = media.viewInsets.bottom;
    final safeBottom = media.padding.bottom;

    return Column(
      children: [
        // ── Grab handle ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),

        // ── Title row ───────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Filter Alumni',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Narrow down by any field below',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (_hasAnySelection)
                IconButton(
                  icon: const Icon(Icons.restart_alt),
                  tooltip: 'Reset',
                  onPressed: () {
                    setState(() {
                      _department = null;
                      _batch = null;
                      _district = null;
                      _companyType = null;
                      _jobDepartment = null;
                      _careerStatus = null;
                    });
                  },
                ),
            ],
          ),
        ),

        // Divider under the header
        Divider(
          height: 1,
          thickness: 1,
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),

        // ── Scrollable fields ───────────────────────────────────
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            children: [
              // Section: Basic Filters
              _SectionHeader(label: 'Basic Filters', theme: theme),
              const SizedBox(height: 12),

              _PremiumDropdown<String>(
                label: 'Department',
                icon: Icons.school_outlined,
                value: _department,
                placeholder: 'All Departments',
                items: Departments.all
                    .map((d) => DropdownMenuItem(
                          value: d,
                          child: Text(
                            Departments.getShortLabel(d),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _department = v),
              ),
              const SizedBox(height: 16),

              BatchDropdownField(
                value: _batch,
                onChanged: (v) => setState(() => _batch = v),
                validator: (_) => null,
              ),
              const SizedBox(height: 16),

              _PremiumDropdown<String>(
                label: 'District',
                icon: Icons.location_on_outlined,
                value: _district,
                placeholder: 'All Districts',
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
              ),

              const SizedBox(height: 24),
              _SectionHeader(label: 'Job Information', theme: theme),
              const SizedBox(height: 12),

              _PremiumDropdown<String>(
                label: 'Company Type',
                icon: Icons.business_outlined,
                value: _companyType,
                placeholder: 'All Company Types',
                items: CompanyTypes.all
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(
                            t,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _companyType = v),
              ),
              const SizedBox(height: 16),

              _PremiumDropdown<String>(
                label: 'Job Department',
                icon: Icons.work_outline,
                value: _jobDepartment,
                placeholder: 'All Job Departments',
                items: JobDepartments.all
                    .map((d) => DropdownMenuItem(
                          value: d,
                          child: Text(
                            d,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _jobDepartment = v),
              ),
              const SizedBox(height: 16),

              _PremiumDropdown<String>(
                label: 'Career Status',
                icon: Icons.trending_up_outlined,
                value: _careerStatus,
                placeholder: 'All Career Statuses',
                items: CareerStatusCategories.all
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(
                            CareerStatusCategories.getDisplayLabel(c),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _careerStatus = v),
              ),
            ],
          ),
        ),

        // ── Sticky footer ───────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                bottomInset > 0 ? 12 : 12 + safeBottom * 0.5,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _department = null;
                          _batch = null;
                          _district = null;
                          _companyType = null;
                          _jobDepartment = null;
                          _careerStatus = null;
                        });
                        ref
                            .read(directoryNotifierProvider.notifier)
                            .clearFilters();
                        Navigator.of(context).pop();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color:
                              theme.colorScheme.outline.withValues(alpha: 0.6),
                          width: 1,
                        ),
                        foregroundColor: theme.colorScheme.onSurface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Clear All',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final notifier =
                            ref.read(directoryNotifierProvider.notifier);
                        notifier.setCompanyTypeFilter(_companyType);
                        notifier.setJobDepartmentFilter(_jobDepartment);
                        if (_department != null ||
                            _batch != null ||
                            _district != null ||
                            _careerStatus != null) {
                          notifier.applyServerFilters(
                            department: _department,
                            batch: _batch,
                            district: _district,
                            careerStatus: _careerStatus,
                          );
                        } else if (widget.initialState.isServerFiltered) {
                          notifier.loadFirstPage();
                        }
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text(
                        'Apply Filters',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Section header (small caps label + divider line)
// ─────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;
  final ThemeData theme;

  const _SectionHeader({required this.label, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Divider(
            height: 1,
            thickness: 1,
            color: theme.colorScheme.primary.withValues(alpha: 0.20),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Premium filled dropdown — reads as a tappable row, not a form input
// ─────────────────────────────────────────────────────────────────────
class _PremiumDropdown<T> extends StatelessWidget {
  final String label;
  final IconData icon;
  final T? value;
  final String placeholder;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _PremiumDropdown({
    required this.label,
    required this.icon,
    required this.value,
    required this.placeholder,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasValue = value != null;

    // Tinted background when a value is set — the user can see at a
    // glance which filters are active.
    final bgColor = hasValue
        ? theme.colorScheme.primaryContainer
            .withValues(alpha: isDark ? 0.55 : 0.65)
        : theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: isDark ? 0.55 : 0.85);

    final borderColor = hasValue
        ? theme.colorScheme.primary.withValues(alpha: 0.55)
        : theme.colorScheme.outlineVariant.withValues(alpha: 0.6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Field label
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // Filled dropdown row
        Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Theme(
            data: theme.copyWith(
              inputDecorationTheme: const InputDecorationTheme(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: DropdownButton<T>(
                  value: value,
                  isExpanded: true,
                  isDense: false,
                  borderRadius: BorderRadius.circular(14),
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  hint: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          placeholder,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.85),
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  items: items,
                  onChanged: onChanged,
                  selectedItemBuilder: (context) {
                    return items.map((item) {
                      final selectedLabel = ((item.child as Text).data) ?? '';
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icon,
                            size: 20,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              selectedLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: theme.colorScheme.onPrimaryContainer,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList();
                  },
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
