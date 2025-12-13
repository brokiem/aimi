import 'package:aimi_app/models/anime.dart';
import 'package:aimi_app/viewmodels/home_viewmodel.dart';
import 'package:aimi_app/views/detail_view.dart';
import 'package:aimi_app/views/search_view.dart';
import 'package:aimi_app/widgets/anime_grid_tile.dart';
import 'package:aimi_app/widgets/common/error_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:scroll_animator/scroll_animator.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final _scrollController = AnimatedScrollController(animationFactory: const ChromiumEaseInOut());
  final _historyScrollController = AnimatedScrollController(animationFactory: const ChromiumEaseInOut());
  bool _fetchHasError = false;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    final homeViewModel = Provider.of<HomeViewModel>(context, listen: false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (homeViewModel.trendingAnime.isEmpty) {
        homeViewModel.fetchTrending().catchError((e) {
          if (mounted) {
            setState(() => _fetchHasError = true);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
          }
        });
      }
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300 &&
          !homeViewModel.isLoading) {
        homeViewModel.loadMoreTrendingAnime().catchError((e) => homeViewModel.loadMoreTrendingAnime());
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _historyScrollController.dispose();
    super.dispose();
  }

  void _onDestinationSelected(int index) {
    setState(() => _selectedIndex = index);

    // Fetch history when switching to history tab
    if (index == 1) {
      final homeViewModel = Provider.of<HomeViewModel>(context, listen: false);
      homeViewModel.fetchWatchHistory();
    }
  }

  void _navigateToDetail(BuildContext context, Anime anime) {
    DetailView.open(context, anime);
  }

  @override
  Widget build(BuildContext context) {
    final homeViewModel = Provider.of<HomeViewModel>(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 640;

        final destinations = const <NavigationRailDestination>[
          NavigationRailDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: Text("Home"),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: Text("History"),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.settings),
            selectedIcon: Icon(Icons.settings),
            label: Text("Settings"),
          ),
        ];

        final navigationDestinations = const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: "Home"),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: "History",
          ),
          NavigationDestination(icon: Icon(Icons.settings), selectedIcon: Icon(Icons.settings), label: "Settings"),
        ];

        // Build the current page based on selected index
        Widget body = _buildCurrentPage(homeViewModel, isMobile);

        if (isMobile) {
          return Scaffold(
            appBar: AppBar(
              title: Text(_getPageTitle()),
              bottom: _getLoadingIndicator(homeViewModel),
              shadowColor: Theme.of(context).colorScheme.shadow,
            ),
            body: body,
            bottomNavigationBar: NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onDestinationSelected,
              destinations: navigationDestinations,
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SearchView())),
              child: const Icon(Icons.search),
            ),
          );
        } else {
          return Row(
            children: [
              NavigationRail(
                selectedIndex: _selectedIndex,
                groupAlignment: 0,
                onDestinationSelected: _onDestinationSelected,
                labelType: NavigationRailLabelType.all,
                leading: FloatingActionButton(
                  elevation: 0,
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SearchView())),
                  child: const Icon(Icons.search),
                ),
                backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                destinations: destinations,
              ),
              Expanded(
                child: Scaffold(
                  appBar: AppBar(
                    title: Text(_getPageTitle()),
                    bottom: _getLoadingIndicator(homeViewModel),
                    shadowColor: Theme.of(context).colorScheme.shadow,
                  ),
                  body: body,
                ),
              ),
            ],
          );
        }
      },
    );
  }

  String _getPageTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Aimi';
      case 1:
        return 'Watch History';
      case 2:
        return 'Settings';
      default:
        return 'Aimi';
    }
  }

  PreferredSizeWidget? _getLoadingIndicator(HomeViewModel homeViewModel) {
    if (_selectedIndex == 0 && homeViewModel.isLoading && homeViewModel.trendingAnime.isEmpty) {
      return const PreferredSize(preferredSize: Size.fromHeight(4.0), child: LinearProgressIndicator());
    }
    if (_selectedIndex == 1 && homeViewModel.isLoadingHistory && homeViewModel.watchedAnime.isEmpty) {
      return const PreferredSize(preferredSize: Size.fromHeight(4.0), child: LinearProgressIndicator());
    }
    return null;
  }

  Widget _buildCurrentPage(HomeViewModel homeViewModel, bool isMobile) {
    return IndexedStack(
      index: _selectedIndex,
      children: [
        _buildHomePage(homeViewModel, isMobile),
        _buildHistoryPage(homeViewModel, isMobile),
        _buildSettingsPage(),
      ],
    );
  }

  Widget _buildHomePage(HomeViewModel homeViewModel, bool isMobile) {
    if (_fetchHasError) {
      return ErrorView(
        message: "Failed to fetch trending anime.",
        onRetry: () {
          setState(() => _fetchHasError = false);
          homeViewModel.fetchTrending().catchError((e) {
            if (mounted) setState(() => _fetchHasError = true);
          });
        },
      );
    }

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 202,
              childAspectRatio: 0.55,
              crossAxisSpacing: 24,
              mainAxisSpacing: isMobile ? 24 : 0,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => AnimeGridTile(
                anime: homeViewModel.trendingAnime[index],
                onTap: (anime) => _navigateToDetail(context, anime),
              ),
              childCount: homeViewModel.trendingAnime.length,
            ),
          ),
        ),
        if (homeViewModel.isLoading && homeViewModel.trendingAnime.isNotEmpty)
          const SliverToBoxAdapter(
            child: Center(
              child: Padding(padding: EdgeInsets.only(bottom: 38), child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  Widget _buildHistoryPage(HomeViewModel homeViewModel, bool isMobile) {
    if (homeViewModel.historyError != null) {
      return ErrorView(message: homeViewModel.historyError!, onRetry: () => homeViewModel.fetchWatchHistory());
    }

    if (homeViewModel.watchedAnime.isEmpty && !homeViewModel.isLoadingHistory) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'No watch history yet',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              'Start watching anime to see your history here',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    return CustomScrollView(
      controller: _historyScrollController,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 202,
              childAspectRatio: 0.55,
              crossAxisSpacing: 24,
              mainAxisSpacing: isMobile ? 24 : 0,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => AnimeGridTile(
                anime: homeViewModel.watchedAnime[index],
                onTap: (anime) => _navigateToDetail(context, anime),
              ),
              childCount: homeViewModel.watchedAnime.length,
            ),
          ),
        ),
        if (homeViewModel.isLoadingHistory && homeViewModel.watchedAnime.isNotEmpty)
          const SliverToBoxAdapter(
            child: Center(
              child: Padding(padding: EdgeInsets.only(bottom: 38), child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  Widget _buildSettingsPage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.settings, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            'Settings',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(
            'Coming soon',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
