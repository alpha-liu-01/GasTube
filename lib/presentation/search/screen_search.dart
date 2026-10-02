import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxtube/application/application.dart';
import 'package:fluxtube/core/colors.dart';
import 'package:fluxtube/core/constants.dart';
import 'package:fluxtube/core/enums.dart';
import 'package:fluxtube/core/ubuntu_touch.dart';
import 'package:fluxtube/domain/search/models/search_history.dart';
import 'package:fluxtube/generated/l10n.dart';
import 'package:fluxtube/presentation/search/widgets/newpipe/search_result_section.dart';
import 'package:fluxtube/presentation/search/widgets/newpipe/search_suggestion_section.dart';
import 'package:fluxtube/widgets/widgets.dart';

import 'widgets/widgets.dart';

class ScreenSearch extends StatefulWidget {
  const ScreenSearch({super.key});

  @override
  State<ScreenSearch> createState() => _ScreenSearchState();
}

class _ScreenSearchState extends State<ScreenSearch> {
  final TextEditingController _textEditingController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _selectedFilter = 'all';
  bool _showSearchHistory = true;

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
    _searchFocusNode.addListener(_onFocusChange);
    if (UbuntuTouch.enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    _searchFocusNode.removeListener(_onFocusChange);
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_searchFocusNode.hasFocus && _textEditingController.text.isEmpty) {
      setState(() {
        _showSearchHistory = true;
      });
    }
  }

  void _loadSearchHistory() {
    final currentProfile = context.read<SettingsBloc>().state.currentProfile;
    BlocProvider.of<SearchBloc>(context).add(
      SearchEvent.getSearchHistory(profileName: currentProfile),
    );
  }

  void _onFilterChanged(String filter, String serviceType) {
    setState(() {
      _selectedFilter = filter;
    });
    if (_textEditingController.text.isNotEmpty) {
      BlocProvider.of<SearchBloc>(context).add(SearchEvent.getSearchResult(
        query: _textEditingController.text,
        filter: filter,
        serviceType: serviceType,
      ));
    }
  }

  void _performSearch(String query, String serviceType) {
    if (query.trim().isEmpty) return;

    setState(() {
      _showSearchHistory = false;
    });

    final settingsState = context.read<SettingsBloc>().state;
    final currentProfile = settingsState.currentProfile;

    // Save search query to history if enabled
    if (settingsState.isSearchHistoryEnabled) {
      BlocProvider.of<SearchBloc>(context).add(
        SearchEvent.saveSearchQuery(query: query, profileName: currentProfile),
      );
    }

    // Track search for personalized recommendations
    BlocProvider.of<SavedBloc>(context).add(
      SavedEvent.trackSearch(query: query),
    );

    BlocProvider.of<SearchBloc>(context).add(SearchEvent.getSearchResult(
      query: query,
      filter: _selectedFilter,
      serviceType: serviceType,
    ));
  }

  void _onSearchQueryChanged(String value, String serviceType) {
    if (value.isEmpty) {
      setState(() {
        _showSearchHistory = true;
      });
      return;
    }

    setState(() {
      _showSearchHistory = false;
    });

    EasyDebounce.debounce(
      'suggestions',
      const Duration(milliseconds: 500),
      () => BlocProvider.of<SearchBloc>(context).add(
        SearchEvent.getSearchSuggestion(
          query: value,
          serviceType: serviceType,
        ),
      ),
    );
  }

  void _clearSearch() {
    _textEditingController.clear();
    setState(() {
      _showSearchHistory = true;
    });
  }

  void _deleteSearchHistoryItem(String query) {
    final currentProfile = context.read<SettingsBloc>().state.currentProfile;
    BlocProvider.of<SearchBloc>(context).add(
      SearchEvent.deleteSearchQuery(query: query, profileName: currentProfile),
    );
  }

  void _clearAllSearchHistory() {
    final currentProfile = context.read<SettingsBloc>().state.currentProfile;
    BlocProvider.of<SearchBloc>(context).add(
      SearchEvent.clearSearchHistory(profileName: currentProfile),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final locals = S.of(context);

    return BlocBuilder<SettingsBloc, SettingsState>(
      buildWhen: (previous, current) =>
          previous.ytService != current.ytService ||
          previous.isSearchHistoryEnabled != current.isSearchHistoryEnabled ||
          previous.isSearchHistoryVisible != current.isSearchHistoryVisible,
      builder: (context, settingsState) {
        return Scaffold(
          backgroundColor:
              isDark ? AppColors.backgroundDark : AppColors.background,
          body: SafeArea(
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                // App Bar with title
                SliverAppBar(
                  floating: true,
                  snap: true,
                  toolbarHeight: 60,
                  backgroundColor:
                      isDark ? AppColors.backgroundDark : AppColors.background,
                  elevation: 0,
                  surfaceTintColor: kWhiteColor,
                  title: Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFFFF4444), Color(0xFFCC0000)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds),
                      child: Text(
                        locals.search,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 24,
                          letterSpacing: -0.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),

                // Search Bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.sm,
                    ),
                    child: SizedBox(
                      height: 40,
                      child: TextField(
                        controller: _textEditingController,
                        focusNode: _searchFocusNode,
                        style:
                            theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
                        textInputAction: TextInputAction.search,
                        onSubmitted: (value) {
                          if (value.isNotEmpty) {
                            EasyDebounce.cancel('suggestions');
                            _performSearch(value, settingsState.ytService);
                          }
                        },
                        onChanged: (value) => _onSearchQueryChanged(
                            value, settingsState.ytService),
                        decoration: InputDecoration(
                          hintText: locals.searchYouTube,
                          hintStyle: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 14,
                            color: isDark
                                ? AppColors.onSurfaceVariantDark
                                : AppColors.onSurfaceVariant,
                          ),
                          prefixIcon:
                              const Icon(CupertinoIcons.search, size: 18),
                          suffixIcon: _textEditingController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                      CupertinoIcons.xmark_circle_fill,
                                      size: 16),
                                  onPressed: _clearSearch,
                                )
                              : null,
                          filled: true,
                          fillColor: isDark
                              ? AppColors.surfaceVariantDark
                              : AppColors.surfaceVariant,
                          border: OutlineInputBorder(
                            borderRadius: AppRadius.borderMd,
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Filter Chips
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: settingsState.ytService ==
                                YouTubeServices.invidious.name
                            ? [
                                _buildFilterChip(locals.filterAll, 'all',
                                    settingsState.ytService),
                                const SizedBox(width: 8),
                                _buildFilterChip(locals.filterVideos, 'video',
                                    settingsState.ytService),
                                const SizedBox(width: 8),
                                _buildFilterChip(locals.filterChannels,
                                    'channel', settingsState.ytService),
                                const SizedBox(width: 8),
                                _buildFilterChip(locals.filterPlaylists,
                                    'playlist', settingsState.ytService),
                              ]
                            : settingsState.ytService ==
                                    YouTubeServices.newpipe.name
                                ? [
                                    _buildFilterChip(locals.filterAll, 'all',
                                        settingsState.ytService),
                                    const SizedBox(width: 8),
                                    _buildFilterChip(locals.filterVideos,
                                        'videos', settingsState.ytService),
                                    const SizedBox(width: 8),
                                    _buildFilterChip(locals.filterChannels,
                                        'channels', settingsState.ytService),
                                    const SizedBox(width: 8),
                                    _buildFilterChip(locals.filterPlaylists,
                                        'playlists', settingsState.ytService),
                                    const SizedBox(width: 8),
                                    _buildFilterChip(locals.filterMusic,
                                        'music_songs', settingsState.ytService),
                                  ]
                                : [
                                    _buildFilterChip(locals.filterAll, 'all',
                                        settingsState.ytService),
                                    const SizedBox(width: 8),
                                    _buildFilterChip(locals.filterVideos,
                                        'videos', settingsState.ytService),
                                    const SizedBox(width: 8),
                                    _buildFilterChip(locals.filterChannels,
                                        'channels', settingsState.ytService),
                                    const SizedBox(width: 8),
                                    _buildFilterChip(locals.filterPlaylists,
                                        'playlists', settingsState.ytService),
                                    const SizedBox(width: 8),
                                    _buildFilterChip(locals.filterMusic,
                                        'music_songs', settingsState.ytService),
                                  ],
                      ),
                    ),
                  ),
                ),
              ],
              body: BlocBuilder<SearchBloc, SearchState>(
                builder: (context, state) {
                  // Show search history when text is empty and history is enabled
                  if (_showSearchHistory &&
                      _textEditingController.text.isEmpty &&
                      settingsState.isSearchHistoryVisible &&
                      settingsState.isSearchHistoryEnabled) {
                    return _buildSearchHistorySection(
                        state.searchHistory, isDark);
                  }

                  // NEWPIPE
                  if (settingsState.ytService == YouTubeServices.newpipe.name) {
                    return _buildNewPipeContent(state, settingsState, locals);
                  }
                  // INVIDIOUS
                  else if (settingsState.ytService ==
                      YouTubeServices.invidious.name) {
                    return _buildInvidiousContent(state, settingsState, locals);
                  }
                  // PIPED
                  else {
                    return _buildPipedContent(state, settingsState, locals);
                  }
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchHistorySection(
      List<LocalSearchHistory> history, bool isDark) {
    final theme = Theme.of(context);
    final locals = S.of(context);

    if (history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.surfaceVariantDark
                    : AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons.search,
                size: AppIconSize.xxxl,
                color: AppColors.disabled,
              ),
            ),
            AppSpacing.height24,
            Text(
              locals.searchYouTube,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            AppSpacing.height8,
            Text(
              locals.searchForVideosChannels,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark
                    ? AppColors.onSurfaceVariantDark
                    : AppColors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                locals.recentSearches,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.onSurfaceVariantDark
                      : AppColors.onSurfaceVariant,
                ),
              ),
              TextButton(
                onPressed: _clearAllSearchHistory,
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  locals.clearAll,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            itemCount: history.length,
            itemBuilder: (context, index) {
              final item = history[index];
              final settingsState = context.read<SettingsBloc>().state;

              return ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                leading: Icon(
                  CupertinoIcons.time,
                  size: 18,
                  color: isDark
                      ? AppColors.onSurfaceVariantDark
                      : AppColors.onSurfaceVariant,
                ),
                title: Text(
                  item.query,
                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: Icon(
                    CupertinoIcons.xmark,
                    size: 16,
                    color: isDark
                        ? AppColors.onSurfaceVariantDark
                        : AppColors.onSurfaceVariant,
                  ),
                  onPressed: () => _deleteSearchHistoryItem(item.query),
                ),
                onTap: () {
                  _textEditingController.text = item.query;
                  _performSearch(item.query, settingsState.ytService);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNewPipeContent(
      SearchState state, SettingsState settingsState, S locals) {
    if (state.isSuggestionDisplay == true &&
        state.fetchNewPipeSuggestionStatus == ApiStatus.loaded &&
        (state.fetchNewPipeSearchResultStatus == ApiStatus.initial ||
            state.fetchNewPipeSearchResultStatus == ApiStatus.loading ||
            state.fetchNewPipeSearchResultStatus == ApiStatus.loaded) &&
        state.newPipeSuggestionResult.isNotEmpty &&
        _textEditingController.text.isNotEmpty) {
      return NewPipeSearchSuggestionSection(
        textEditingController: _textEditingController,
        state: state,
        onSearch: (query) => _performSearch(query, settingsState.ytService),
      );
    } else if (state.fetchNewPipeSearchResultStatus == ApiStatus.loading ||
        (_textEditingController.text.trim().isNotEmpty &&
            state.fetchNewPipeSearchResultStatus == ApiStatus.initial)) {
      return cIndicator(context);
    } else if (_textEditingController.text.trim().isEmpty &&
        state.fetchNewPipeSearchResultStatus == ApiStatus.initial) {
      return const SizedBox();
    } else if (state.isSuggestionDisplay ||
        _textEditingController.text.isEmpty) {
      return Container();
    } else if (state.fetchNewPipeSearchResultStatus == ApiStatus.error ||
        state.newPipeSearchResult == null ||
        (state.newPipeSearchResult?.items?.isEmpty ?? true)) {
      return ErrorRetryWidget(
        lottie: 'assets/cup.zip',
        customMessage: UbuntuTouch.enabled
            ? 'NewPipe extractor is not in this Ubuntu Touch build.'
            : null,
        onTap: UbuntuTouch.enabled
            ? null
            : () => BlocProvider.of<SearchBloc>(context).add(
                SearchEvent.getSearchResult(
                    query: _textEditingController.text,
                    filter: _selectedFilter,
                    serviceType: settingsState.ytService)),
      );
    } else {
      return NewPipeSearchResultSection(
        locals: locals,
        state: state,
        searchQuery: _textEditingController.text,
        filter: _selectedFilter,
      );
    }
  }

  Widget _buildInvidiousContent(
      SearchState state, SettingsState settingsState, S locals) {
    if (state.isSuggestionDisplay == true &&
        state.fetchSuggestionStatus == ApiStatus.loaded &&
        (state.fetchSearchResultStatus == ApiStatus.loading ||
            state.fetchSearchResultStatus == ApiStatus.loaded) &&
        state.suggestions.isNotEmpty &&
        _textEditingController.text.isNotEmpty) {
      return SearchSuggestionSection(
        textEditingController: _textEditingController,
        state: state,
        onSearch: (query) => _performSearch(query, settingsState.ytService),
      );
    } else if (state.fetchSearchResultStatus == ApiStatus.loading ||
        state.fetchSearchResultStatus == ApiStatus.initial) {
      return cIndicator(context);
    } else if (state.isSuggestionDisplay ||
        _textEditingController.text.isEmpty) {
      return Container();
    } else if (state.fetchSearchResultStatus == ApiStatus.error ||
        state.result == null ||
        state.result!.items.isEmpty) {
      return ErrorRetryWidget(
        lottie: 'assets/cup.zip',
        onTap: () => BlocProvider.of<SearchBloc>(context).add(
            SearchEvent.getSearchResult(
                query: _textEditingController.text,
                filter: _selectedFilter,
                serviceType: settingsState.ytService)),
      );
    } else {
      return SearcheResultSection(
        locals: locals,
        state: state,
        searchQuery: _textEditingController.text,
        filter: _selectedFilter,
      );
    }
  }

  Widget _buildPipedContent(
      SearchState state, SettingsState settingsState, S locals) {
    if (state.isSuggestionDisplay == true &&
        state.fetchSuggestionStatus == ApiStatus.loaded &&
        (state.fetchSearchResultStatus == ApiStatus.initial ||
            state.fetchSearchResultStatus == ApiStatus.loading ||
            state.fetchSearchResultStatus == ApiStatus.loaded) &&
        state.suggestions.isNotEmpty &&
        _textEditingController.text.isNotEmpty) {
      return SearchSuggestionSection(
        textEditingController: _textEditingController,
        state: state,
        onSearch: (query) => _performSearch(query, settingsState.ytService),
      );
    } else if (state.fetchSearchResultStatus == ApiStatus.loading ||
        (_textEditingController.text.trim().isNotEmpty &&
            state.fetchSearchResultStatus == ApiStatus.initial)) {
      return cIndicator(context);
    } else if (_textEditingController.text.trim().isEmpty &&
        state.fetchSearchResultStatus == ApiStatus.initial) {
      return const SizedBox();
    } else if (state.isSuggestionDisplay ||
        _textEditingController.text.isEmpty) {
      return Container();
    } else if (state.fetchSearchResultStatus == ApiStatus.error ||
        state.result == null ||
        state.result!.items.isEmpty) {
      return ErrorRetryWidget(
        lottie: 'assets/cup.zip',
        onTap: () => BlocProvider.of<SearchBloc>(context).add(
            SearchEvent.getSearchResult(
                query: _textEditingController.text,
                filter: _selectedFilter,
                serviceType: settingsState.ytService)),
      );
    } else {
      return SearcheResultSection(
        locals: locals,
        state: state,
        searchQuery: _textEditingController.text,
        filter: _selectedFilter,
      );
    }
  }

  Widget _buildFilterChip(String label, String filter, String serviceType) {
    final isSelected = _selectedFilter == filter;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isSelected
                ? (isDarkMode ? kWhiteColor : kWhiteColor)
                : (isDarkMode
                    ? kWhiteColor.withValues(alpha: 0.8)
                    : kBlackColor),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        onSelected: (_) => _onFilterChanged(filter, serviceType),
        backgroundColor:
            isDarkMode ? kWhiteColor.withValues(alpha: 0.1) : kGreyOpacityColor,
        selectedColor: kRedColor,
        checkmarkColor: kWhiteColor,
        side: BorderSide(
          color: isSelected
              ? kRedColor
              : (isDarkMode
                  ? kWhiteColor.withValues(alpha: 0.3)
                  : kGreyColor!.withValues(alpha: 0.3)),
          width: 1,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        showCheckmark: false,
      ),
    );
  }
}
