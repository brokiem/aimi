import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;

import '../stream_provider.dart';
import '../../models/media.dart';
import '../../models/episode.dart';
import '../../models/stream_source.dart';
import '../../models/streamable_anime.dart';
import '../../core/exceptions.dart';
import '../../utils/packer.dart';
import '../../utils/string_utils.dart';

import '../../core/config.dart';

/// AnimePahe implementation of stream provider
///
/// Provides streaming links from AnimePahe.si
class AnimePaheProvider implements IStreamProvider {
  static const String _authority = 'animepahe.si';
  static const String _baseUrl = 'https://$_authority';
  static final String _userAgent = const ProviderConfig().userAgent;

  final Dio _dio;
  late final String _cookie;

  @override
  String get name => 'AnimePahe';

  @override
  String get version => '1.0.0';

  AnimePaheProvider({Dio? dio}) : _dio = dio ?? Dio() {
    _cookie = '__ddg2_=${StringUtils.generateRandomString(16)}';
    _setupDio();
  }

  void _setupDio() {
    _dio.options.headers['User-Agent'] = _userAgent;
    _dio.options.headers['Cookie'] = _cookie;
    _dio.options.validateStatus = (status) => status != null && status < 500;
  }

  Future<Response> _get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl$path',
        queryParameters: queryParameters,
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

  Future<Map<String, dynamic>> _getJson(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _get(path, queryParameters: queryParameters);
    return response.data as Map<String, dynamic>;
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
      throw ArgumentError('Query must be a String or Anime object');
    }

    try {
      final data = await _getJson(
        '/api',
        queryParameters: {'m': 'search', 'q': searchQuery},
      );

      if (data['total'] == 0) return [];

      final results = data['data'] as List;
      return results.map((e) => _parseStreamableAnime(e)).toList();
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
    final episodes = <Episode>[];
    int page = 1;
    int lastPage = 1;

    try {
      do {
        final data = await _getJson(
          '/api',
          queryParameters: {
            'm': 'release',
            'id': animeId,
            'sort': 'episode_asc',
            'page': page.toString(),
          },
        );

        lastPage = (data['last_page'] as int?) ?? 1;
        final results = (data['data'] as List?) ?? [];

        episodes.addAll(results.map((e) => _parseEpisode(e, animeId)));
        page++;
      } while (page <= lastPage);

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
        message: 'Episode ID (session) is required for AnimePahe',
        providerName: name,
      );
    }

    final String mode = options?['mode'] ?? 'sub';

    try {
      final response = await _get(
        '/play/${episode.animeId}/${episode.sourceId}',
        headers: {'Referer': _baseUrl},
      );

      final document = html_parser.parse(response.data);
      final buttons = document.querySelectorAll('#resolutionMenu > button');

      final targetAudio = mode == 'dub' ? 'eng' : 'jpn';

      final tasks = buttons
          .where((button) {
            final audio = button.attributes['data-audio'];
            return audio == null || audio == targetAudio;
          })
          .map((button) {
            final src = button.attributes['data-src'];
            final kwik = button.attributes['data-kwik'];
            final resolution =
                button.attributes['data-resolution'] ?? 'unknown';
            final url = src ?? kwik;

            if (url != null) {
              return _processEmbed(url, resolution);
            }
            return null;
          })
          .whereType<Future<StreamSource?>>();

      final results = await Future.wait(tasks);
      return results.whereType<StreamSource>().toList();
    } catch (e, stackTrace) {
      if (e is StreamExtractionException || e is ProviderException) rethrow;
      throw StreamExtractionException(
        message: 'Error getting episode sources',
        providerName: name,
        originalError: e,
      );
    }
  }

  Future<StreamSource?> _processEmbed(String url, String quality) async {
    try {
      final uri = Uri.parse(url);
      final response = await _dio.get(
        uri.toString(),
        options: Options(
          headers: {
            'Referer': _baseUrl,
            'User-Agent': _userAgent,
            'Cookie': _cookie,
          },
        ),
      );

      final body = response.data.toString();

      // Regex to capture the arguments of the packed function
      // eval(function(p,a,c,k,e,d){...}(args))
      final scriptRegex = RegExp(
        r"eval\(function\(p,a,c,k,e,d\).*?\}\((.*?\.split\(['\x22]\|['\x22]\),\d+,.*?)\)\)",
        dotAll: true,
      );

      final matches = scriptRegex.allMatches(body);
      for (final match in matches) {
        final args = match.group(1);
        if (args == null) continue;

        final unpacked = DeanEdwardsPacker.unpack(args);

        // Extract m3u8 link from unpacked code
        final sourceRegex = RegExp(r"source\s*=\s*['\x22](.*?)['\x22]");
        final sourceMatch = sourceRegex.firstMatch(unpacked);

        if (sourceMatch != null) {
          return StreamSource(
            url: sourceMatch.group(1)!,
            quality: quality,
            type: 'hls',
            headers: {'Referer': 'https://kwik.cx/'},
          );
        }
      }
    } catch (e) {
      // Ignore errors for individual sources to allow others to succeed
      return null;
    }
    return null;
  }

  /// Parse StreamableAnime from AnimePahe API response
  StreamableAnime _parseStreamableAnime(Map<String, dynamic> json) {
    return StreamableAnime(
      id: json['session'] as String,
      title: json['title'] as String,
      availableEpisodes: json['episodes'] as int,
    );
  }

  /// Parse Episode from AnimePahe API response
  Episode _parseEpisode(Map<String, dynamic> json, String animeId) {
    return Episode(
      animeId: animeId,
      number: json['episode'].toString(),
      sourceId: json['session'] as String?,
    );
  }

  @override
  void dispose() {
    _dio.close();
  }
}
