import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/news/news_model.dart';
import '../../data/repositories/news_repository.dart';

final newsRepositoryProvider = Provider<NewsRepository>((ref) {
  return NewsRepository();
});

/// autoDispose: like dashboardStatsProvider (§8.3), don't keep this alive
/// once nothing is watching it (e.g. user navigated away from News).
final newsListProvider =
    FutureProvider.autoDispose<List<NewsModel>>((ref) async {
  final repo = ref.watch(newsRepositoryProvider);
  return repo.getNews();
});

/// Pull-to-refresh and post/edit/delete actions go through this notifier
/// rather than calling the repository directly from a widget, so every
/// call site gets the same "invalidate the list after mutating" behavior
/// with no risk of a screen forgetting to refresh after an edit.
class NewsActionsNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  NewsActionsNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> refresh() async {
    // Force a network re-fetch (bypasses the 6h Hive TTL) — used by
    // pull-to-refresh, where the user is explicitly asking for the latest.
    state = const AsyncValue.loading();
    try {
      await _ref.read(newsRepositoryProvider).getNews(forceRefresh: true);
      _ref.invalidate(newsListProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> post({
    required String title,
    required String body,
    String? imageFileId,
    required String postedByUid,
    required String postedByName,
    required String postedByBatch,
    int autoDeleteDays = 7,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(newsRepositoryProvider).postNews(
            title: title,
            body: body,
            imageFileId: imageFileId,
            postedByUid: postedByUid,
            postedByName: postedByName,
            postedByBatch: postedByBatch,
            autoDeleteDays: autoDeleteDays,
          );
      _ref.invalidate(newsListProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> edit(NewsModel updated) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(newsRepositoryProvider).editNews(updated);
      _ref.invalidate(newsListProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> delete(String id) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(newsRepositoryProvider).deleteNews(id);
      _ref.invalidate(newsListProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final newsActionsProvider =
    StateNotifierProvider<NewsActionsNotifier, AsyncValue<void>>((ref) {
  return NewsActionsNotifier(ref);
});
