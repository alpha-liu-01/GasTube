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

  /// Queries already sent to the extractor for this profile.
  /// Load-more must not search them again: each YouTube search builds a large
  /// temporary object graph inside the sidecar.
  final Map<String, Set<String>> _issuedQueries = {};

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
      final alreadyIssued = _issuedQueries[profileName]?.length ?? 0;
      final askLimit = onlyNew ? alreadyIssued + queryLimit : queryLimit;

      // Get recommended queries based on user history
      final queriesResult = await userPreferencesService.getRecommendedQueries(
        profileName: profileName,
        limit: askLimit,
      );

      final queries = queriesResult.fold(
        (failure) {
          log('Failed to get recommended queries, using defaults');
          return DefaultTopic.defaultTopics
              .take(askLimit)
              .map((t) => t.keyword)
              .toList();
        },
        (queries) => queries.isEmpty
            ? DefaultTopic.defaultTopics
                .take(askLimit)
                .map((t) => t.keyword)
                .toList()
            : queries,
      );

      final selected = _selectQueries(profileName, queries, queryLimit, onlyNew);
      if (selected.isEmpty) {
        log('[Recommendation] No new queries for $profileName');
        return const Right(<NewPipeSearchItem>[]);
      }

      log('[Recommendation] Fetching personalized feed with ${selected.length} queries in parallel');

      // OPTIMIZATION: Fetch ALL queries in parallel
      final searchResults = await Future.wait(
        selected.map((query) => _searchForQuery(query, serviceType, resultsPerQuery)),
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
      log('[Recommendation] Fetched ${allResults.length} videos in ${stopwatch.elapsedMilliseconds}ms');

      // Smart shuffle: group by source query, then interleave
      _smartShuffle(allResults, searchResults);

      return Right(allResults);
    } catch (e) {
      log('Error in getPersonalizedFeed: $e');
      return const Left(MainFailure.clientFailure());
    }
  }

  /// A fresh load replaces the remembered queries. A load-more keeps them and
  /// returns at most [queryLimit] queries that have not been searched yet.
  List<String> _selectQueries(
    String profileName,
    List<String> queries,
    int queryLimit,
    bool onlyNew,
  ) {
    if (!onlyNew) {
      _issuedQueries[profileName] = {};
    }
    final issued = _issuedQueries.putIfAbsent(profileName, () => {});
    final selected = <String>[];
    for (final query in queries) {
      if (selected.length >= queryLimit) break;
      final key = query.toLowerCase();
      if (issued.contains(key)) continue;
      issued.add(key);
      selected.add(query);
    }
    return selected;
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
