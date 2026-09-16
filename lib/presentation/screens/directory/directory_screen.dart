// lib/presentation/screens/directory/directory_screen.dart
//
// Architecture §7.3 (Alumni Directory) + Appendix F.7.4 (screen wireframe)
// + L.1.3/L.1.4 (search/filter upgrade).
//
// ⚠️ Appendix §M.6: "Reused as-is inside student_shell.dart for the
// Student role — no separate Student version needed." This screen has no
// role-specific branching anywhere in it for that exact reason.
//
// ⚠️ Interaction-model note: Architecture Appendix F.7.4's filter sheet
// describes a staged "Clear All / Apply" footer (nothing takes effect
// until Apply is tapped), while Appendix L.1.4's own code applies Company
// Type/Job Department instantly on change. Mixing an instant-apply
// interaction for 2 fields with a staged one for the other 4 inside the
// same sheet would be confusing, so every filter here is staged locally
// and committed together on "Apply" — a deliberate synthesis favoring one
// consistent interaction pattern.

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
import '../profile/profile_detail_screen.dart'; // ⚠️ NEW (Phase 6)

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
    // §7.3 infinite scroll: load the next page once the user is within
    // 200px of the bottom, rather than waiting for them to hit the
    // literal end (which would show a visible pause).
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
                onChanged: (v) => ref
                    .read(directoryNotifierProvider.notifier)
                    .setSearchQuery(v),
                decoration: InputDecoration(
                  hintText: 'Search by name, company, group, department...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: theme.colorScheme.primaryContainer,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                ),
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
    final notifier = ref.read(directoryNotifierProvider.notifier);
    final chips = <Widget>[];

    void addChip(String? value, VoidCallback onRemove) {
      if (value == null) {
        return;
      }
      chips.add(Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Chip(
          label: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
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
      height: 48,
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
            // ⚠️ NEW (Phase 6) — was unwired (no onTap at all), so tapping
            // a card previously did nothing.
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.7,
        child: _FilterSheet(initialState: state),
      ),
    );
  }
}

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: theme.colorScheme.outline,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text('Filter Alumni', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _department,
                  decoration: const InputDecoration(labelText: 'Department'),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('All Departments')),
                    ...Departments.all.map(
                      (d) => DropdownMenuItem(
                        value: d,
                        child: Text(Departments.getShortLabel(d),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _department = v),
                ),
                const SizedBox(height: 12),
                BatchDropdownField(
                  value: _batch,
                  onChanged: (v) => setState(() => _batch = v),
                  validator: (_) => null, // optional in this context
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _district,
                  decoration: const InputDecoration(labelText: 'District'),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('All Districts')),
                    ...Districts.all
                        .map((d) => DropdownMenuItem(value: d, child: Text(d))),
                  ],
                  onChanged: (v) => setState(() => _district = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _companyType,
                  decoration: const InputDecoration(labelText: 'Company Type'),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('All Company Types')),
                    ...CompanyTypes.all.map(
                      (t) => DropdownMenuItem(
                          value: t,
                          child: Text(t,
                              maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ),
                  ],
                  onChanged: (v) => setState(() => _companyType = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _jobDepartment,
                  decoration:
                      const InputDecoration(labelText: 'Job Department'),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('All Job Departments')),
                    ...JobDepartments.all.map(
                      (d) => DropdownMenuItem(
                          value: d,
                          child: Text(d,
                              maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ),
                  ],
                  onChanged: (v) => setState(() => _jobDepartment = v),
                ),
                const SizedBox(height: 12),
                // ⚠️ CHANGED: was a Wrap of ChoiceChips — converted to a
                // DropdownButtonFormField for consistency with every
                // other filter in this sheet (Department/Batch/District/
                // Company Type/Job Department are all dropdowns; having
                // Career Status alone be chip-based was inconsistent UI).
                DropdownButtonFormField<String>(
                  initialValue: _careerStatus,
                  decoration: const InputDecoration(labelText: 'Career Status'),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('All Career Statuses')),
                    ...CareerStatusCategories.all.map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(
                          CareerStatusCategories.getDisplayLabel(c),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _careerStatus = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
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
                    ref.read(directoryNotifierProvider.notifier).clearFilters();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Clear All'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
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
                      // All server-side filters were cleared this time —
                      // fall back to the default paginated feed instead
                      // of leaving stale server-filtered results on screen.
                      notifier.loadFirstPage();
                    }
                    Navigator.of(context).pop();
                  },
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
