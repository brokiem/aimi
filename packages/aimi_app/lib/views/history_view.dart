import 'package:aimi_app/models/anime.dart';
import 'package:aimi_app/viewmodels/history_viewmodel.dart';
import 'package:aimi_app/views/detail_view.dart';
import 'package:aimi_app/widgets/anime_grid_tile.dart';
import 'package:aimi_app/widgets/common/error_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:scroll_animator/scroll_animator.dart';

class HistoryView extends StatefulWidget {
  const HistoryView({super.key});

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  final _scrollController = AnimatedScrollController(animationFactory: const ChromiumEaseInOut());

  @override
  void initState() {
    super.initState();
    // Always fetch fresh history when view appears
    // This ensures newly watched anime show up immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = Provider.of<HistoryViewModel>(context, listen: false);
      viewModel.fetchWatchHistory();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _navigateToDetail(BuildContext context, Anime anime) {
    DetailView.open(context, anime);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<HistoryViewModel>(context);
    final isMobile = MediaQuery.of(context).size.width < 640;

    if (viewModel.historyError != null) {
      return ErrorView(message: viewModel.historyError!, onRetry: () => viewModel.fetchWatchHistory());
    }

    if (viewModel.watchedAnime.isEmpty && !viewModel.isLoadingHistory) {
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
                anime: viewModel.watchedAnime[index],
                onTap: (anime) => _navigateToDetail(context, anime),
              ),
              childCount: viewModel.watchedAnime.length,
            ),
          ),
        ),
        if (viewModel.isLoadingHistory && viewModel.watchedAnime.isNotEmpty)
          const SliverToBoxAdapter(
            child: Center(
              child: Padding(padding: EdgeInsets.only(bottom: 38), child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}
