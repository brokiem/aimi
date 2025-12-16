import 'package:aimi_app/models/anime.dart';
import 'package:aimi_app/viewmodels/home_viewmodel.dart';
import 'package:aimi_app/views/detail_view.dart';
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
  bool _fetchHasError = false;

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
    super.dispose();
  }

  void _navigateToDetail(BuildContext context, Anime anime) {
    DetailView.open(context, anime, heroTagPrefix: 'home');
  }

  @override
  Widget build(BuildContext context) {
    final homeViewModel = Provider.of<HomeViewModel>(context);
    final isMobile = MediaQuery.of(context).size.width < 640;

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
                heroTagPrefix: 'home',
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
}
