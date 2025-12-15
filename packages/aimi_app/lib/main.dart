import 'dart:io';

import 'package:aimi_app/services/anime_service.dart';
import 'package:aimi_app/services/caching_service.dart';
import 'package:aimi_app/services/preferences_service.dart';
import 'package:aimi_app/services/stream_provider_registry.dart';
import 'package:aimi_app/services/streaming_service.dart';
import 'package:aimi_app/services/thumbnail_service.dart';
import 'package:aimi_app/services/watch_history_service.dart';
import 'package:aimi_app/viewmodels/home_viewmodel.dart';
import 'package:aimi_app/viewmodels/search_viewmodel.dart';
import 'package:aimi_app/views/home_view.dart';
import 'package:aimi_lib/aimi_lib.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:media_kit/media_kit.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:scroll_animator/scroll_animator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isAndroid) {
    final deviceInfo = await DeviceInfoPlugin().androidInfo;
    if (deviceInfo.version.sdkInt >= 33 /* Android 13 or higher. */ ) {
      // Video permissions.
      if (await Permission.videos.isDenied || await Permission.videos.isPermanentlyDenied) {
        final state = await Permission.videos.request();
        if (!state.isGranted) {
          await SystemNavigator.pop();
        }
      }
      // Audio permissions.
      if (await Permission.audio.isDenied || await Permission.audio.isPermanentlyDenied) {
        final state = await Permission.audio.request();
        if (!state.isGranted) {
          await SystemNavigator.pop();
        }
      }
    } else {
      if (await Permission.storage.isDenied || await Permission.storage.isPermanentlyDenied) {
        final state = await Permission.storage.request();
        if (!state.isGranted) {
          await SystemNavigator.pop();
        }
      }
    }
  }

  // Initialize media_kit
  MediaKit.ensureInitialized();

  runApp(const AimiApp());
}

class AimiApp extends StatelessWidget {
  const AimiApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Instantiate services
    final cachingService = CachingService();
    final animeService = AnimeService([AniListProvider()], cachingService);
    final preferencesService = PreferencesService();
    final watchHistoryService = WatchHistoryService(cachingService);
    final thumbnailService = ThumbnailService();

    // Create stream provider registry with all available providers
    final streamProviderRegistry = StreamProviderRegistry([AnimePaheProvider(), AnizoneProvider()]);

    // Create streaming service with the first provider as default
    final streamingService = StreamingService();

    return MultiProvider(
      providers: [
        Provider<AnimeService>.value(value: animeService),
        Provider<StreamingService>.value(value: streamingService),
        Provider<StreamProviderRegistry>.value(value: streamProviderRegistry),
        Provider<CachingService>.value(value: cachingService),
        Provider<PreferencesService>.value(value: preferencesService),
        Provider<WatchHistoryService>.value(value: watchHistoryService),
        Provider<ThumbnailService>.value(value: thumbnailService),
        ChangeNotifierProvider(create: (_) => HomeViewModel(animeService, watchHistoryService)),
        ChangeNotifierProvider(create: (_) => SearchViewModel(animeService)),
      ],
      child: MaterialApp(
        title: 'Aimi',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.teal,
            brightness: .dark,
            dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
          ),
          textTheme: GoogleFonts.interTextTheme(
            ThemeData.from(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.teal,
                brightness: .dark,
                dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
              ),
            ).textTheme,
          ),
          progressIndicatorTheme: const ProgressIndicatorThemeData(year2023: false),
          sliderTheme: const SliderThemeData(year2023: false),
          useMaterial3: true,
        ),
        shortcuts: {
          ...WidgetsApp.defaultShortcuts,
          const SingleActivator(LogicalKeyboardKey.arrowUp): const ScrollIntent(direction: AxisDirection.up),
          const SingleActivator(LogicalKeyboardKey.arrowDown): const ScrollIntent(direction: AxisDirection.down),
          const SingleActivator(LogicalKeyboardKey.arrowLeft): const ScrollIntent(direction: AxisDirection.left),
          const SingleActivator(LogicalKeyboardKey.arrowRight): const ScrollIntent(direction: AxisDirection.right),
        },
        actions: {...WidgetsApp.defaultActions, ScrollIntent: AnimatedScrollAction()},
        home: const HomeView(),
      ),
    );
  }
}
