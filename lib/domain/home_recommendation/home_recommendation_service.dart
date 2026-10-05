import 'package:dartz/dartz.dart';
import 'package:fluxtube/domain/core/failure/main_failure.dart';
import 'package:fluxtube/domain/search/models/newpipe/newpipe_search_resp.dart';

abstract class HomeRecommendationService {
  /// Get personalized home feed based on user preferences
  /// Returns mixed video results from multiple search queries
  /// Supports pagination via page parameter for each query
  Future<Either<MainFailure, List<NewPipeSearchItem>>> getPersonalizedFeed({
    required String profileName,
    required String serviceType,
    int resultsPerQuery = 5,
    int queryLimit = 10,
    int page = 1,
    bool onlyNew = false,
  });

  /// Get default/trending topics for new users
  Future<Either<MainFailure, List<NewPipeSearchItem>>> getDefaultFeed({
    required String serviceType,
    int limit = 20,
  });
}
