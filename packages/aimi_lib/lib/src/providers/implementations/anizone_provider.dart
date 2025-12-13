import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;

import '../stream_provider.dart';
import '../../models/media.dart';
import '../../models/episode.dart';
import '../../models/stream_source.dart';
import '../../models/streamable_anime.dart';
import '../../models/subtitle.dart';
import '../../core/exceptions.dart';

import '../../core/config.dart';

/// Anizone implementation of stream provider
///
/// Provides streaming links from Anizone.to
class AnizoneProvider implements IStreamProvider {
  static const String _baseUrl = 'https://anizone.to';
  static final String _userAgent = const ProviderConfig().userAgent;

  final Dio _dio;

  @override
  String get name => 'Anizone';

  @override
  String get version => '1.0.0';

  AnizoneProvider({Dio? dio}) : _dio = dio ?? Dio() {
    _setupDio();
  }

  void _setupDio() {
    _dio.options.headers['User-Agent'] = _userAgent;
    _dio.options.headers['Accept'] =
        'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8';
    _dio.options.validateStatus = (status) => status != null && status < 500;
  }

  Future<Response> _get(String url, {Map<String, String>? headers}) async {
    try {
      final response = await _dio.get(
        url,
        options: Options(
          headers: headers,
          validateStatus: (status) => status == 200,
        ),
      );

      if (response.statusCode != 200) {
        throw ProviderException(
          message: 'Request failed with status: ${response.statusCode}',
          providerName: name,
        );
      }
      return response;
    } catch (e, stackTrace) {
      if (e is ProviderException) rethrow;
      throw ProviderException(
        message: 'Network error',
        providerName: name,
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<List<StreamableAnime>> search(dynamic query) async {
    String searchQuery;
    if (query is Media) {
      searchQuery =
          query.title.english ?? query.title.romaji ?? query.title.native;
    } else if (query is String) {
      searchQuery = query;
    } else {
      throw ArgumentError('Query must be a String or Media object');
    }

    final uri = '$_baseUrl/anime?search=$searchQuery';

    try {
      final response = await _get(uri);
      final document = html_parser.parse(response.data);
      List<StreamableAnime> results = [];

      var items = document.querySelectorAll(
        'div.grid > div.relative.overflow-hidden',
      );

      for (var item in items) {
        var titleElement = item.querySelector('a[title]');
        var infoElement = item.querySelector('.text-xs');

        if (titleElement != null) {
          String href = titleElement.attributes['href'] ?? '';
          String title = titleElement.attributes['title'] ?? '';
          String info =
              infoElement?.text.trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';

          int? episodeCount;
          // Try to extract episode count from info string like "TV • 2016 • 1 Eps"
          final epsMatch = RegExp(r'(\d+)\s*Eps').firstMatch(info);
          if (epsMatch != null) {
            episodeCount = int.tryParse(epsMatch.group(1) ?? '');
          }

          results.add(
            StreamableAnime(
              id: href,
              title: title,
              availableEpisodes: episodeCount ?? 0,
            ),
          );
        }
      }
      return results;
    } catch (e, stackTrace) {
      if (e is ProviderException) rethrow;
      throw ProviderException(
        message: 'Error searching anime',
        providerName: name,
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<List<Episode>> getEpisodes(StreamableAnime anime) async {
    final animeId = anime.id;

    try {
      final response = await _get(animeId);
      final document = html_parser.parse(response.data);
      List<Episode> episodes = [];

      var episodeList = document.querySelectorAll('ul.grid li a');

      for (var element in episodeList) {
        String href = element.attributes['href'] ?? '';
        var titleEl = element.querySelector('h3');
        String title = titleEl?.text.trim() ?? 'Unknown';

        String number = title;
        // Extract number from "Episode 1"
        final numMatch = RegExp(r'Episode\s+(\d+(\.\d+)?)').firstMatch(title);
        if (numMatch != null) {
          number = numMatch.group(1)!;
        }

        episodes.add(
          Episode(
            animeId: animeId,
            number: number,
            sourceId: href,
            title: title,
          ),
        );
      }

      return episodes;
    } catch (e, stackTrace) {
      if (e is ProviderException) rethrow;
      throw ProviderException(
        message: 'Error getting episodes',
        providerName: name,
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<List<StreamSource>> getSources(
    Episode episode, {
    Map<String, dynamic>? options,
  }) async {
    if (episode.sourceId == null) {
      throw StreamExtractionException(
        message: 'Episode source ID is required for Anizone',
        providerName: name,
      );
    }

    try {
      final response = await _get(episode.sourceId!);
      final document = html_parser.parse(response.data);
      List<StreamSource> sources = [];

      var player = document.querySelector('media-player');

      if (player != null) {
        String streamUrl = player.attributes['src'] ?? '';
        if (streamUrl.isNotEmpty) {
          String type = 'hls';
          if (streamUrl.endsWith('.mp4')) {
            type = 'mp4';
          }

          // Extract subtitle tracks
          List<Subtitle> subtitles = [];

          // Look for track elements with src attribute (the ones after the video element)
          var trackElements = document.querySelectorAll(
            'track[src][kind="subtitles"]',
          );

          for (var track in trackElements) {
            final src = track.attributes['src'];
            final label = track.attributes['label'];
            final srclang = track.attributes['srclang'];
            final dataType = track.attributes['data-type'];

            if (src != null && src.isNotEmpty && label != null) {
              // Determine format from data-type or URL extension
              String format = dataType ?? '';
              if (format.isEmpty) {
                if (src.endsWith('.ass')) {
                  format = 'ass';
                } else if (src.endsWith('.srt')) {
                  format = 'srt';
                } else if (src.endsWith('.vtt')) {
                  format = 'vtt';
                } else {
                  format = 'unknown';
                }
              }

              subtitles.add(
                Subtitle(
                  label: label,
                  language: srclang ?? 'und',
                  url: src,
                  format: format,
                ),
              );
            }
          }

          sources.add(
            StreamSource(
              url: streamUrl,
              quality: 'default',
              type: type,
              headers: {'User-Agent': _userAgent, 'Referer': _baseUrl},
              subtitles: subtitles,
            ),
          );
        }
      }

      return sources;
    } catch (e) {
      if (e is StreamExtractionException || e is ProviderException) rethrow;
      throw StreamExtractionException(
        message: 'Error getting episode sources',
        providerName: name,
        originalError: e,
      );
    }
  }

  @override
  void dispose() {
    _dio.close();
  }
}
