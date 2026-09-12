// lib/presentation/providers/directory_provider.dart
//
// Architecture §7.3 (Alumni Directory: search, composite filter,
// district-priority sort, cursor pagination) + Appendix L.1.3/L.1.4
// (search box matching Group/Job Department/Work Experience, Company
// Type + Job Department filter dropdowns).
//
// ⚠️ Two filtering mechanisms, by design, matching what each field
// actually supports:
//   - Department/Batch/District/Career Status → live Firestore composite
//     queries (§7.3's own composite indexes exist for exactly these 4).
//     Replaces the loaded list and disables further pagination for that
//     filtered view (Architecture doesn't specify cursor pagination for
//     filtered result sets — treated as a bounded lookup, capped at 50).
//   - Company Type/Job Department + free-text search → applied
//     client-side over whatever's already loaded (Appendix L.1.3: "so
//     typing in the search box costs zero network reads").

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/user/role_model.dart';
import '../../data/models/user/user_public_model.dart';
import '../../data/repositories/directory_repository.dart';
import 'auth_provider.dart';
import 'core_providers.dart';
import 'dashboard_provider.dart';
import 'role_provider.dart';

const _unset = Object();

class DirectoryState {
  final List<UserPublicModel> items;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final Object? error;
  final bool isServerFiltered;
  final String? myDistrict;

  final String searchQuery;
  final String? companyTypeFilter;
  final String? jobDepartmentFilter;
  final String? careerStatusFilter;
  final String? departmentFilter;
  final String? batchFilter;
  final String? districtFilter;

  const DirectoryState({
    this.items = const [],
    this.cursor,
    this.hasMore = true,
    this.isLoading = true,
    this.isLoadingMore = false,
    this.error,
    this.isServerFiltered = false,
    this.myDistrict,
    this.searchQuery = '',
    this.companyTypeFilter,
    this.jobDepartmentFilter,
    this.careerStatusFilter,
    this.departmentFilter,
    this.batchFilter,
    this.districtFilter,
  });

  bool get hasActiveFilters =>
      companyTypeFilter != null ||
      jobDepartmentFilter != null ||
      careerStatusFilter != null ||
      departmentFilter != null ||
      batchFilter != null ||
      districtFilter != null;

  /// Client-side search + Company Type/Job Department filter, plus
  /// district-priority sort (§7.3) — applied last, and only when the
  /// viewer isn't already looking at one specific district.
  List<UserPublicModel> get filtered {
    final q = searchQuery.trim().toLowerCase();

    var list = items.where((a) {
      if (companyTypeFilter != null && a.companyType != companyTypeFilter) {
        return false;
      }
      if (jobDepartmentFilter != null &&
          a.jobDepartment != jobDepartmentFilter) {
        return false;
      }
      if (q.isEmpty) {
        return true;
      }

      final haystacks = <String?>[
        a.fullName,
        a.company,
        a.groupOfCompanies,
        a.jobDepartment,
        a.district,
        ...a.workExperience.map((w) => w.companyName),
        ...a.workExperience.map((w) => w.designation),
      ];
      return haystacks.any((h) => h != null && h.toLowerCase().contains(q));
    }).toList();

    if (districtFilter == null && myDistrict != null) {
      list = List.of(list)
        ..sort((a, b) {
          final aMatch = a.district == myDistrict;
          final bMatch = b.district == myDistrict;
          if (aMatch == bMatch) {
            return 0;
          }
          return aMatch ? -1 : 1;
        });
    }
    return list;
  }

  DirectoryState copyWith({
    List<UserPublicModel>? items,
    Object? cursor = _unset,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    Object? error = _unset,
    bool? isServerFiltered,
    Object? myDistrict = _unset,
    String? searchQuery,
    Object? companyTypeFilter = _unset,
    Object? jobDepartmentFilter = _unset,
    Object? careerStatusFilter = _unset,
    Object? departmentFilter = _unset,
    Object? batchFilter = _unset,
    Object? districtFilter = _unset,
  }) {
    return DirectoryState(
      items: items ?? this.items,
      cursor: cursor == _unset
          ? this.cursor
          : cursor as DocumentSnapshot<Map<String, dynamic>>?,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error == _unset ? this.error : error,
      isServerFiltered: isServerFiltered ?? this.isServerFiltered,
      myDistrict:
          myDistrict == _unset ? this.myDistrict : myDistrict as String?,
      searchQuery: searchQuery ?? this.searchQuery,
      companyTypeFilter: companyTypeFilter == _unset
          ? this.companyTypeFilter
          : companyTypeFilter as String?,
      jobDepartmentFilter: jobDepartmentFilter == _unset
          ? this.jobDepartmentFilter
          : jobDepartmentFilter as String?,
      careerStatusFilter: careerStatusFilter == _unset
          ? this.careerStatusFilter
          : careerStatusFilter as String?,
      departmentFilter: departmentFilter == _unset
          ? this.departmentFilter
          : departmentFilter as String?,
      batchFilter:
          batchFilter == _unset ? this.batchFilter : batchFilter as String?,
      districtFilter: districtFilter == _unset
          ? this.districtFilter
          : districtFilter as String?,
    );
  }
}

class DirectoryNotifier extends StateNotifier<DirectoryState> {
  final DirectoryRepository _repository;

  DirectoryNotifier(this._repository) : super(const DirectoryState()) {
    loadFirstPage();
  }

  Future<void> loadFirstPage() async {
    state =
        state.copyWith(isLoading: true, error: null, isServerFiltered: false);
    try {
      final page = await _repository.getFirstPage();
      state = state.copyWith(
        items: page.alumni,
        cursor: page.lastDocument,
        hasMore: page.hasMore,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> loadNextPage() async {
    if (state.isLoadingMore ||
        !state.hasMore ||
        state.isServerFiltered ||
        state.cursor == null) {
      return;
    }
    state = state.copyWith(isLoadingMore: true);
    try {
      final page = await _repository.getNextPage(after: state.cursor!);
      state = state.copyWith(
        items: [...state.items, ...page.alumni],
        cursor: page.lastDocument,
        hasMore: page.hasMore,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e);
    }
  }

  void setSearchQuery(String q) => state = state.copyWith(searchQuery: q);

  void setCompanyTypeFilter(String? v) =>
      state = state.copyWith(companyTypeFilter: v);

  void setJobDepartmentFilter(String? v) =>
      state = state.copyWith(jobDepartmentFilter: v);

  void setMyDistrict(String? d) => state = state.copyWith(myDistrict: d);

  /// §7.3 composite server-side filter — Department/Batch/District/
  /// Career Status. Any combination may be passed; `null` means "no
  /// constraint on this dimension".
  Future<void> applyServerFilters({
    String? department,
    String? batch,
    String? district,
    String? careerStatus,
  }) async {
    state = state.copyWith(
      isLoading: true,
      error: null,
      departmentFilter: department,
      batchFilter: batch,
      districtFilter: district,
      careerStatusFilter: careerStatus,
    );
    try {
      final results = await _repository.filterAlumni(
        department: department,
        batch: batch,
        district: district,
        careerStatus: careerStatus,
        limit: 50,
      );
      state = state.copyWith(
        items: results,
        isLoading: false,
        hasMore: false,
        isServerFiltered: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  /// "Clear All" in the filter bottom sheet — resets every filter
  /// dimension (server-side and client-side) and reloads the default
  /// paginated feed.
  void clearFilters() {
    state = state.copyWith(
      departmentFilter: null,
      batchFilter: null,
      districtFilter: null,
      careerStatusFilter: null,
      companyTypeFilter: null,
      jobDepartmentFilter: null,
    );
    loadFirstPage();
  }
}

final directoryNotifierProvider =
    StateNotifierProvider.autoDispose<DirectoryNotifier, DirectoryState>((ref) {
  final notifier = DirectoryNotifier(ref.watch(directoryRepositoryProvider));

  // Resolve "my district" once for priority sorting (§7.3) — works for
  // both roles, since Students also have an optional `district` (§M.4).
  Future<void> resolveMyDistrict() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) {
      return;
    }
    final role = ref.read(myRoleProvider).valueOrNull;
    try {
      if (role == SignupRole.student) {
        final profile =
            await ref.read(studentProfileRepositoryProvider).getMyProfile(uid);
        notifier.setMyDistrict(profile.district);
      } else {
        final profile =
            await ref.read(userRepositoryProvider).getMyProfile(uid);
        notifier.setMyDistrict(profile.district);
      }
    } catch (_) {
      // District priority sort is a nice-to-have — silently skip it if
      // "my profile" can't be resolved for any reason, rather than
      // surfacing an error for a non-essential sort tweak.
    }
  }

  resolveMyDistrict();

  // ⚠️ Appendix F.6.O hand-off (Phase 4's forward-looking mechanism): if
  // the Home Dashboard's Donut Chart stashed a career-status filter
  // before navigating here, apply it once and clear the slot so it
  // doesn't re-apply on every subsequent visit to this tab.
  final pending = ref.read(pendingDirectoryFilterProvider);
  if (pending != null) {
    notifier.applyServerFilters(careerStatus: pending);
    ref.read(pendingDirectoryFilterProvider.notifier).state = null;
  }

  return notifier;
});
