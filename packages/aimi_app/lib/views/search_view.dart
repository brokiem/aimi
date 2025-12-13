import 'package:aimi_app/viewmodels/search_viewmodel.dart';
import 'package:aimi_app/views/detail_view.dart';
import 'package:aimi_app/widgets/anime_grid_tile.dart';
import 'package:aimi_app/widgets/common/error_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:scroll_animator/scroll_animator.dart';

import '../models/anime.dart';

class SearchView extends StatefulWidget {
  const SearchView({super.key});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  // SearchController is required for SearchAnchor
  final SearchController _searchController = SearchController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SearchViewModel>(context, listen: false).clearResults();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch(BuildContext context, String query) {
    if (query.trim().isNotEmpty) {
      Provider.of<SearchViewModel>(context, listen: false).search(query);
      // We don't need to manually unfocus here as SearchAnchor handles view closing
    }
  }

  void _navigateToDetail(BuildContext context, Anime anime) {
    DetailView.open(context, anime);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<SearchViewModel>(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedPrimaryScrollController(
      animationFactory: const ChromiumEaseInOut(),
      child: Scaffold(
        appBar: AppBar(
          // remove the default back button if you want the search bar to take full width,
          // otherwise, keep it. The title spacing adjusts the bar's fit.
          titleSpacing: 0,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          title: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SizedBox(
              width: double.infinity,
              height: 44,
              child: SearchAnchor(
                headerHeight: 44,
                searchController: _searchController,
                viewHintText: 'Search anime...',

                // 1. Handle "Enter" key on keyboard
                viewOnSubmitted: (query) {
                  _performSearch(context, query);
                  _searchController.closeView(query);
                },

                // 2. The Bar visible in the AppBar
                builder: (BuildContext context, SearchController controller) {
                  return SearchBar(
                    controller: controller,
                    hintText: 'Search anime...',
                    padding: const WidgetStatePropertyAll<EdgeInsets>(EdgeInsets.symmetric(horizontal: 16.0)),
                    onTap: () => controller.openView(),
                    leading: const Icon(Icons.search),
                    elevation: const WidgetStatePropertyAll<double>(0),
                    // Optional: Match AppBar background or keep slightly lighter for M3 style
                    backgroundColor: WidgetStatePropertyAll<Color>(colorScheme.surfaceContainerHigh),
                  );
                },

                // 3. The History/Suggestions View
                suggestionsBuilder: (BuildContext context, SearchController controller) {
                  if (viewModel.history.isEmpty) {
                    return [
                      const Padding(
                        padding: EdgeInsets.only(top: 24.0),
                        child: Center(child: Text('No search history')),
                      ),
                    ];
                  }

                  // We map the history to ListTiles
                  return viewModel.history.map((historyItem) {
                    return ListTile(
                      leading: const Icon(Icons.history),
                      title: Text(historyItem),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          // Note: We need to rebuild the suggestions after deletion.
                          // Since viewModel notifies listeners, we might need to trick
                          // the SearchAnchor to rebuild or just rely on the parent rebuild.
                          viewModel.removeFromHistory(historyItem);

                          // Refresh the view to remove the item visually immediately
                          // (Wait one frame or ensure VM notifyListeners triggers UI)
                          controller.closeView(historyItem);
                          controller.openView();
                        },
                      ),
                      onTap: () {
                        // Update controller text, perform search, close view
                        controller.closeView(historyItem);
                        _performSearch(context, historyItem);
                      },
                    );
                  });
                },
              ),
            ),
          ),
        ),
        body: Stack(
          children: [
            Builder(
              builder: (context) {
                if (viewModel.isLoading && !viewModel.hasSearched) {
                  return const SizedBox.shrink();
                }

                if (viewModel.errorMessage != null) {
                  return ErrorView(
                    message: viewModel.errorMessage!,
                    onRetry: () => _performSearch(context, _searchController.text),
                  );
                }

                // Case: Empty State (No search performed yet)
                if (!viewModel.hasSearched) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.movie_filter_outlined, size: 64, color: colorScheme.surfaceContainerHighest),
                        const SizedBox(height: 16),
                        Text(
                          'Search for your favorite anime',
                          style: theme.textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  );
                }

                if (viewModel.isLoading && viewModel.searchResults.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search, size: 64, color: colorScheme.surfaceContainerHighest),
                        const SizedBox(height: 16),
                        Text(
                          'Searching for "${_searchController.text}"...',
                          style: theme.textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  );
                }

                // Case: No Results
                if (viewModel.searchResults.isEmpty) {
                  return Center(child: Text('No results found', style: theme.textTheme.bodyLarge));
                }

                // Case: Results Grid
                return GridView.builder(
                  padding: const EdgeInsets.all(24),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 202,
                    childAspectRatio: 0.55,
                    crossAxisSpacing: 24,
                    mainAxisSpacing: 0,
                  ),
                  itemCount: viewModel.searchResults.length,
                  itemBuilder: (context, index) {
                    return AnimeGridTile(
                      anime: viewModel.searchResults[index],
                      onTap: (anime) => _navigateToDetail(context, anime),
                    );
                  },
                );
              },
            ),
            if (viewModel.isLoading) const Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator()),
          ],
        ),
      ),
    );
  }
}
