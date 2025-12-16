import 'package:aimi_app/services/settings_service.dart';
import 'package:aimi_app/utils/title_helper.dart';
import 'package:aimi_app/viewmodels/detail_viewmodel.dart';
import 'package:aimi_app/widgets/anime_characters_card.dart';
import 'package:aimi_app/widgets/anime_cover.dart';
import 'package:aimi_app/widgets/anime_header.dart';
import 'package:aimi_app/widgets/anime_info_card.dart';
import 'package:aimi_app/widgets/anime_provider_sheet.dart';
import 'package:aimi_app/widgets/anime_staff_card.dart';
import 'package:aimi_app/widgets/detail_banner.dart';
import 'package:aimi_app/widgets/mobile_anime_info.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:scroll_animator/scroll_animator.dart';
import 'package:side_sheet/side_sheet.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/anime.dart';
import '../models/anime_episode.dart';
import '../services/anime_service.dart';
import '../services/storage_service.dart';
import '../services/stream_provider_registry.dart';
import '../services/streaming_service.dart';
import 'video_player_view.dart';

class DetailView extends StatefulWidget {
  final String? heroTagPrefix;

  const DetailView({super.key, this.heroTagPrefix});

  static void open(BuildContext context, Anime anime, {String? heroTagPrefix}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          final streamingService = Provider.of<StreamingService>(context, listen: false);
          final providerRegistry = Provider.of<StreamProviderRegistry>(context, listen: false);
          return ChangeNotifierProvider(
            create: (context) => DetailViewModel(anime, streamingService, providerRegistry),
            child: DetailView(heroTagPrefix: heroTagPrefix),
          );
        },
      ),
    );
  }

  @override
  State<DetailView> createState() => _DetailViewState();
}

class _DetailViewState extends State<DetailView> with TickerProviderStateMixin {
  late final ScrollController _scrollController;
  late final TabController _tabController;
  bool _isDescriptionExpanded = false;

  @override
  void initState() {
    super.initState();

    _scrollController = AnimatedScrollController(animationFactory: const ChromiumEaseInOut());
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _onEpisodeTap(BuildContext context, DetailViewModel viewModel, AnimeEpisode episode) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading sources...', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
    );

    try {
      await viewModel
          .loadSources(episode)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Request timed out. Please try again.');
            },
          );

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      final sources = viewModel.sources;

      if (sources.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No sources available for this episode'), duration: Duration(seconds: 3)),
          );
        }
        return;
      }

      if (context.mounted) {
        final storageService = context.read<StorageService>();
        // Import AnimeService is already visible via provider
        final animeService = context.read<AnimeService>();

        // Store the anime data permanently for watch history
        await storageService.saveDynamic(
          key: StorageKey.animeDetails,
          dynamicKey: viewModel.anime.id.toString(),
          data: viewModel.anime.toJson(),
          providerName: animeService.providerName,
        );

        if (context.mounted) {
          await Navigator.of(context).push(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) {
                return VideoPlayerView(
                  sources: sources,
                  episodeTitle: 'Episode ${episode.number}',
                  animeTitle: _getPreferredTitle(context, viewModel.anime),
                  detailViewModel: viewModel,
                  animeId: viewModel.anime.id,
                  episodeId: episode.id,
                  episodeNumber: episode.number,
                  streamProviderName: viewModel.currentProviderName,
                  metadataProviderName: animeService.providerName,
                );
              },
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                const begin = Offset(0.0, 1.0);
                const end = Offset.zero;
                const curve = Curves.easeOutCubic;

                var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

                return SlideTransition(position: animation.drive(tween), child: child);
              },
              transitionDuration: const Duration(milliseconds: 300),
              reverseTransitionDuration: const Duration(milliseconds: 300),
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog if open
      if (context.mounted) {
        Navigator.of(context).pop();

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Failed to load episode sources:'),
                  const SizedBox(height: 8),
                  Text(e.toString(), style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
          ),
        );
      }
    }
  }

  void _openWatchSheet(BuildContext context) {
    final detailViewModel = context.read<DetailViewModel>();
    final anime = detailViewModel.anime;

    // Trigger search if not initialized or if needed
    detailViewModel.loadAllProviders();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return ChangeNotifierProvider.value(
          value: detailViewModel,
          child: Consumer<DetailViewModel>(
            builder: (context, vm, child) {
              return DraggableScrollableSheet(
                initialChildSize: 0.9,
                minChildSize: 0.5,
                maxChildSize: 1.0,
                expand: false,
                builder: (context, scrollController) {
                  return AnimeProviderSheet(
                    anime: anime,
                    availableProviders: vm.availableProviders,
                    currentProvider: vm.currentProviderName,
                    getEpisodes: (p) => vm.getEpisodesForProvider(p) ?? [],
                    isProviderLoading: vm.isProviderLoading,
                    getEpisodeCount: vm.getEpisodeCountForProvider,
                    onProviderSelected: vm.switchProvider,
                    errorMessage: vm.errorMessage,
                    onRetry: () => vm.loadAnime(forceRefresh: true),
                    onEpisodeTap: (episode) => _onEpisodeTap(context, vm, episode),
                    scrollController: scrollController,
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use read instead of watch - anime data is static after navigation
    // The sidebar/bottom sheet has its own Consumer for reactive updates
    final detailViewModel = context.read<DetailViewModel>();
    final anime = detailViewModel.anime;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 640;

        if (isDesktop) {
          return _buildDesktopScaffold(context, anime);
        } else {
          return _buildMobileScaffold(context, anime);
        }
      },
    );
  }

  Widget _buildMobileScaffold(BuildContext context, Anime anime) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        surfaceTintColor: Theme.of(context).colorScheme.surfaceContainerLowest,
        actions: [
          IconButton(
            style: const ButtonStyle(backgroundColor: WidgetStatePropertyAll(Colors.black45)),
            onPressed: () async {
              if (!await launchUrl(Uri.parse(anime.siteUrl))) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Could not launch source site')));
                }
              }
            },
            icon: const Icon(Icons.open_in_new),
            tooltip: "View source",
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Stack(
          children: [
            // Background Layer
            DetailBanner(pictureUrl: anime.bannerImage ?? anime.coverImage.extraLarge, height: 240),
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 241,
              // 240 + 1 to cover potential sub-pixel gaps
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black45, Colors.transparent, Colors.black54, Colors.black87],
                    stops: [0.0, 0.4, 0.8, 1.0],
                  ),
                ),
              ),
            ),
            // Content Layer
            Padding(padding: const EdgeInsets.only(top: 200), child: _buildMobileContent(context, anime)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'watch_now_fab',
        onPressed: () => _openWatchSheet(context),
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('Watch Now'),
      ),
    );
  }

  Widget _buildMobileContent(BuildContext context, Anime anime) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 85.0), // Bottom padding for FAB
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cover Image
                    _buildHeroCover(context, anime, width: 115, height: 170),
                    const SizedBox(width: 16),
                    // Title and Summary Info
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 36.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getPreferredTitle(context, anime),
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (anime.title.native.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                anime.title.native,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                if (anime.averageScore != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.star_rounded,
                                          size: 14,
                                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${anime.averageScore}%',
                                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${anime.seasonYear ?? '?'} • ${anime.format ?? 'TV'}',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Synopsis
                GestureDetector(
                  onTap: () {
                    // Only toggle if the description is long enough to be toggled
                    if (anime.description.length > 150) {
                      setState(() => _isDescriptionExpanded = !_isDescriptionExpanded);
                    }
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _cleanHtml(anime.description),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.5,
                          color: Theme.of(context).colorScheme.onSurface.withAlpha(230),
                        ),
                        maxLines: _isDescriptionExpanded ? 1000 : 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (anime.description.length > 150)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            _isDescriptionExpanded ? 'Read Less' : 'Read More',
                            style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 48),

          // Mobile Info Widget
          MobileAnimeInfo(anime: anime),

          const Divider(height: 48),

          // Characters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: AnimeCharactersCard(anime: anime),
          ),
          const SizedBox(height: 24),
          // Staff
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: AnimeStaffCard(anime: anime),
          ),
        ],
      ),
    );
  }

  // Helper to remove HTML tags typically returned by AniList
  String _cleanHtml(String htmlString) {
    if (htmlString.isEmpty) return "";
    final RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
    return htmlString.replaceAll(exp, '').replaceAll('&br&', '\n');
  }

  /// Builds cover image with optional Hero animation based on settings.
  Widget _buildHeroCover(BuildContext context, Anime anime, {double width = 202, double height = 285}) {
    final settingsService = context.watch<SettingsService>();
    final cover = AnimeCover(pictureUrl: anime.coverImage.large, width: width, height: height);

    if (settingsService.enableHeroAnimation) {
      final tagPrefix = widget.heroTagPrefix ?? 'default';
      return Hero(tag: 'anime_cover_${tagPrefix}_${anime.id}', child: cover);
    }
    return cover;
  }

  /// Get the preferred title based on user settings.
  String _getPreferredTitle(BuildContext context, Anime anime) {
    final settingsService = context.watch<SettingsService>();
    final pref = settingsService.titleLanguagePreference;

    switch (pref) {
      case TitleLanguage.english:
        return anime.title.english ?? anime.title.romaji ?? anime.title.native;
      case TitleLanguage.romaji:
        return anime.title.romaji ?? anime.title.english ?? anime.title.native;
      case TitleLanguage.native:
        return anime.title.native.isNotEmpty ? anime.title.native : (anime.title.romaji ?? anime.title.english ?? '');
    }
  }

  Widget _buildDesktopScaffold(BuildContext context, Anime anime) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 8),
        actions: <Widget>[
          IconButton(
            onPressed: () async {
              if (!await launchUrl(Uri.parse(anime.siteUrl))) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Could not launch source site')));
                }
              }
            },
            icon: const Icon(Icons.open_in_new),
            tooltip: "View source",
          ),
          const SizedBox(width: 2),
          IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert), tooltip: "More"),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'watch_now_fab',
        onPressed: () {
          // Trigger search if not initialized or if needed
          final vm = context.read<DetailViewModel>();
          vm.loadAllProviders();

          SideSheet.right(
            body: ChangeNotifierProvider.value(
              value: vm,
              child: Consumer<DetailViewModel>(
                builder: (context, vm, child) {
                  return AnimeProviderSheet(
                    anime: anime,
                    availableProviders: vm.availableProviders,
                    currentProvider: vm.currentProviderName,
                    getEpisodes: (p) => vm.getEpisodesForProvider(p) ?? [],
                    isProviderLoading: vm.isProviderLoading,
                    getEpisodeCount: vm.getEpisodeCountForProvider,
                    onProviderSelected: vm.switchProvider,
                    errorMessage: vm.errorMessage,
                    onRetry: () => vm.loadAnime(forceRefresh: true),
                    onEpisodeTap: (episode) => _onEpisodeTap(context, vm, episode),
                  );
                },
              ),
            ),
            width: (MediaQuery.of(context).size.width * 0.32).clamp(330, double.infinity),
            context: context,
            sheetColor: Theme.of(context).colorScheme.surface,
          );
        },
        icon: const Icon(Icons.play_arrow),
        label: const Text('Watch Now'),
        tooltip: 'Watch anime',
      ),
      body: DefaultTabController(
        length: 6,
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  // Banner Image
                  DetailBanner(pictureUrl: anime.bannerImage ?? anime.coverImage.extraLarge),
                  // Content
                  Padding(
                    padding: const EdgeInsets.only(top: 200, left: 64, right: 64),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [_buildDesktopLayout(context, anime)],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, Anime anime) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: Cover + Buttons
            _buildHeroCover(context, anime),
            const SizedBox(width: 28),
            // Right Column: Title + Description
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 100.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimeHeader(anime: anime),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TabBar(
          controller: _tabController,
          splashBorderRadius: const BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(10)),
          tabs: const <Widget>[
            Tab(text: 'Summary'),
            Tab(text: 'Trailers'),
            Tab(text: 'Reviews'),
          ],
        ),
        _buildDesktopTabContent(anime),
      ],
    );
  }

  Widget _buildDesktopTabContent(Anime anime) {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, child) {
        switch (_tabController.index) {
          case 0: // Summary
            return Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimeInfoCard(anime: anime),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      children: [
                        AnimeCharactersCard(anime: anime),
                        const SizedBox(height: 24),
                        AnimeStaffCard(anime: anime),
                      ],
                    ),
                  ),
                ],
              ),
            );
          case 1: // Trailers
            return Card(
              margin: const EdgeInsets.only(top: 16, bottom: 16),
              child: const Center(child: Text('Trailers tab')),
            );
          case 2: // Reviews
            return Card(
              margin: const EdgeInsets.only(top: 16, bottom: 16),
              child: const Center(child: Text('Reviews tab')),
            );
          default:
            return const SizedBox.shrink();
        }
      },
    );
  }
}
