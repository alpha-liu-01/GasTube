import 'dart:developer';
import 'dart:math' as math;
import 'package:dartz/dartz.dart';
import 'package:fluxtube/core/enums.dart';
import 'package:fluxtube/domain/core/failure/main_failure.dart';
import 'package:fluxtube/domain/home_recommendation/home_recommendation_service.dart';
import 'package:fluxtube/domain/search/models/newpipe/newpipe_search_resp.dart';
import 'package:fluxtube/domain/search/search_service.dart';
import 'package:fluxtube/domain/user_preferences/models/user_preferences.dart';
import 'package:fluxtube/domain/user_preferences/user_preferences_service.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: HomeRecommendationService)
class HomeRecommendationImpl implements HomeRecommendationService {
  final UserPreferencesService userPreferencesService;
  final SearchService searchService;

  HomeRecommendationImpl(this.userPreferencesService, this.searchService);

  /// Per profile: queries already extracted, videos not yet shown, and the
  /// next-page token. Load-more must not run the first page of a query again.
  final Map<String, _ProfileFeed> _feeds = {};

  @override
  Future<Either<MainFailure, List<NewPipeSearchItem>>> getPersonalizedFeed({
    required String profileName,
    required String serviceType,
    int resultsPerQuery = 5,
    int queryLimit = 10,
    int page = 1,
    bool onlyNew = false,
  }) async {
    try {
      final stopwatch = Stopwatch()..start();
      if (!onlyNew) {
        _feeds.remove(profileName);
      }
      final feed = _feeds.putIfAbsent(profileName, () => _ProfileFeed());

      List<List<NewPipeSearchItem>> groups;
      if (!onlyNew || feed.queries.isEmpty) {
        final queries = await _recommendedQueries(profileName, queryLimit);
        final added = await _addQueries(feed, queries, serviceType, queryLimit);
        groups = _takenGroups(feed, added, resultsPerQuery);
      } else {
        final queries = await _recommendedQueries(
          profileName,
          feed.queries.length + queryLimit,
        );
        final added = await _addQueries(feed, queries, serviceType, queryLimit);
        groups = _takenGroups(feed, added, resultsPerQuery);
        if (groups.isEmpty) {
          groups = await _drawBuffered(
            feed,
            serviceType,
            queryLimit,
            resultsPerQuery,
          );
        }
      }

      if (groups.isEmpty) {
        log('[Recommendation] No further feed items for $profileName');
        return const Right(<NewPipeSearchItem>[]);
      }

      final allResults = <NewPipeSearchItem>[];
      for (final items in groups) {
        allResults.addAll(items);
      }
      stopwatch.stop();
      log('[Recommendation] Fetched ${allResults.length} videos in ${stopwatch.elapsedMilliseconds}ms');
      _smartShuffle(allResults, groups);
      return Right(allResults);
    } catch (e) {
      log('Error in getPersonalizedFeed: $e');
      return const Left(MainFailure.clientFailure());
    }
  }

  Future<List<String>> _recommendedQueries(String profileName, int limit) async {
    final queriesResult = await userPreferencesService.getRecommendedQueries(
      profileName: profileName,
      limit: limit,
    );
    return queriesResult.fold(
      (failure) {
        log('Failed to get recommended queries, using defaults');
        return DefaultTopic.defaultTopics
            .take(limit)
            .map((topic) => topic.keyword)
            .toList();
      },
      (queries) => queries.isEmpty
          ? DefaultTopic.defaultTopics
              .take(limit)
              .map((topic) => topic.keyword)
              .toList()
          : queries,
    );
  }

  Future<List<_FeedQuery>> _addQueries(
    _ProfileFeed feed,
    List<String> queries,
    String serviceType,
    int queryLimit,
  ) async {
    final fresh = <String>[];
    for (final query in queries) {
      if (fresh.length >= queryLimit) break;
      if (feed.keys.contains(query.toLowerCase())) continue;
      fresh.add(query);
    }
    if (fresh.isEmpty) return const [];
    log('[Recommendation] Fetching ${fresh.length} new queries');
    final added = await Future.wait(
      fresh.map((query) => _addQuery(feed, query, serviceType)),
    );
    return added.whereType<_FeedQuery>().toList();
  }

  Future<_FeedQuery?> _addQuery(
    _ProfileFeed feed,
    String query,
    String serviceType,
  ) async {
    final key = query.toLowerCase();
    if (!feed.keys.add(key)) return null;
    final slot = _FeedQuery(query);
    feed.queries.add(slot);
    await _fetchPage(slot, serviceType);
    return slot;
  }

  List<List<NewPipeSearchItem>> _takenGroups(
    _ProfileFeed feed,
    List<_FeedQuery> queries,
    int resultsPerQuery,
  ) {
    final groups = <List<NewPipeSearchItem>>[];
    for (final query in queries) {
      final taken = _take(feed, query, resultsPerQuery);
      if (taken.isNotEmpty) groups.add(taken);
    }
    return groups;
  }

  /// Serves videos already extracted, then one next page for a few queries.
  /// Does not repeat a query's first page.
  Future<List<List<NewPipeSearchItem>>> _drawBuffered(
    _ProfileFeed feed,
    String serviceType,
    int queryLimit,
    int resultsPerQuery,
  ) async {
    final groups = <List<NewPipeSearchItem>>[];
    if (feed.queries.isEmpty) return groups;
    final total = feed.queries.length;
    var index = feed.cursor % total;
    var visited = 0;
    var fetches = 0;
    while (visited < total && groups.length < queryLimit) {
      final query = feed.queries[index];
      var taken = _take(feed, query, resultsPerQuery);
      if (taken.isEmpty && query.nextPage != null && fetches < queryLimit) {
        await _fetchPage(query, serviceType, nextPage: query.nextPage);
        fetches++;
        taken = _take(feed, query, resultsPerQuery);
      }
      if (taken.isNotEmpty) groups.add(taken);
      index = (index + 1) % total;
      visited++;
    }
    feed.cursor = index;
    return groups;
  }

  List<NewPipeSearchItem> _take(
    _ProfileFeed feed,
    _FeedQuery query,
    int resultsPerQuery,
  ) {
    final taken = <NewPipeSearchItem>[];
    while (query.pending.isNotEmpty && taken.length < resultsPerQuery) {
      final item = query.pending.removeAt(0);
      if (feed.shown.add(_extractVideoId(item))) taken.add(item);
    }
    return taken;
  }

  Future<void> _fetchPage(
    _FeedQuery query,
    String serviceType, {
    String? nextPage,
  }) async {
    if (serviceType != YouTubeServices.newpipe.name) {
      query.nextPage = null;
      return;
    }
    final result = nextPage == null
        ? await searchService.getNewPipeSearchResult(
            query: query.text,
            filter: '',
          )
        : await searchService.getMoreNewPipeSearchResult(
            query: query.text,
            filter: '',
            nextPage: nextPage,
          );
    result.fold(
      (failure) {
        log('Search failed for query: ${query.text}');
        query.nextPage = null;
      },
      (searchResp) {
        final items = searchResp.items
                ?.where((item) => item.type == 'STREAM')
                .toList() ??
            const <NewPipeSearchItem>[];
        query.pending.addAll(items);
        final page = searchResp.nextPage;
        query.nextPage = (page == null || page.isEmpty) ? null : page;
      },
    );
  }

  /// Search for a single query - used for parallel execution
  Future<List<NewPipeSearchItem>> _searchForQuery(
      String query, String serviceType, int resultsPerQuery) async {
    try {
      if (serviceType != YouTubeServices.newpipe.name) {
        return [];
      }

      final result = await searchService.getNewPipeSearchResult(
        query: query,
        filter: '',
      );

      return await result.fold(
        (failure) {
          log('Search failed for query: $query');
          return <NewPipeSearchItem>[];
        },
        (searchResp) {
          return searchResp.items
                  ?.where((item) => item.type == "STREAM")
                  .take(resultsPerQuery)
                  .toList() ??
              [];
        },
      );
    } catch (e) {
      log('Error searching for query "$query": $e');
      return [];
    }
  }

  /// Extract video ID from search item
  String _extractVideoId(NewPipeSearchItem item) {
    return item.videoId ??
        item.url?.split('v=').last.split('&').first ??
        '${item.name}_${item.uploaderName}'; // Fallback to title+uploader
  }

  /// Smart shuffle: interleave results from different queries for variety
  void _smartShuffle(
      List<NewPipeSearchItem> allResults, List<List<NewPipeSearchItem>> queryResults) {
    if (allResults.isEmpty || queryResults.isEmpty) return;

    // Create interleaved order
    final interleaved = <NewPipeSearchItem>[];
    final maxLen = queryResults.map((r) => r.length).reduce(math.max);

    for (int i = 0; i < maxLen; i++) {
      for (final queryList in queryResults) {
        if (i < queryList.length) {
          interleaved.add(queryList[i]);
        }
      }
    }

    // Add slight randomization within groups of 3-5
    final random = math.Random();
    for (int i = 0; i < interleaved.length - 1; i += 3) {
      final end = math.min(i + 5, interleaved.length);
      final sublist = interleaved.sublist(i, end);
      sublist.shuffle(random);
      for (int j = 0; j < sublist.length; j++) {
        interleaved[i + j] = sublist[j];
      }
    }

    // Update original list
    allResults.clear();
    // Deduplicate while adding back
    final seen = <String>{};
    for (final item in interleaved) {
      final id = _extractVideoId(item);
      if (!seen.contains(id)) {
        seen.add(id);
        allResults.add(item);
      }
    }
  }

  @override
  Future<Either<MainFailure, List<NewPipeSearchItem>>> getDefaultFeed({
    required String serviceType,
    int limit = 20,
  }) async {
    try {
      final stopwatch = Stopwatch()..start();

      // Use default trending topics
      final topics = DefaultTopic.defaultTopics.take(5).toList();

      log('[Recommendation] Fetching default feed with ${topics.length} topics in parallel');

      // OPTIMIZATION: Fetch ALL topics in parallel
      final searchResults = await Future.wait(
        topics.map((topic) => _searchForQuery(topic.keyword, serviceType, 4)),
        eagerError: false,
      );

      // Combine and deduplicate results
      final allResults = <NewPipeSearchItem>[];
      final seenVideoIds = <String>{};

      for (final items in searchResults) {
        for (final item in items) {
          final videoId = _extractVideoId(item);
          if (!seenVideoIds.contains(videoId)) {
            seenVideoIds.add(videoId);
            allResults.add(item);
          }
        }
      }

      stopwatch.stop();
      log('[Recommendation] Fetched ${allResults.length} default videos in ${stopwatch.elapsedMilliseconds}ms');

      // Smart shuffle for variety
      _smartShuffle(allResults, searchResults);

      return Right(allResults.take(limit).toList());
    } catch (e) {
      log('Error in getDefaultFeed: $e');
      return const Left(MainFailure.clientFailure());
    }
  }
}

class _ProfileFeed {
  final List<_FeedQuery> queries = [];
  final Set<String> keys = {};
  final Set<String> shown = {};
  int cursor = 0;
}

class _FeedQuery {
  _FeedQuery(this.text);

  final String text;
  final List<NewPipeSearchItem> pending = [];
  String? nextPage;
}
