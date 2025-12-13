import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;

import '../../core/exceptions.dart';
import '../../models/media.dart';
import '../metadata_provider.dart';

/// AniList implementation of metadata provider
///
/// Provides anime metadata from AniList's GraphQL API
class AniListProvider implements IMetadataProvider {
  final Dio _dio;

  @override
  String get name => 'AniList';

  @override
  String get version => '1.0.0';

  AniListProvider({Dio? dio}) : _dio = dio ?? Dio();

  @override
  Future<List<Media>> fetchTrending({int page = 1}) async {
    const trendingQuery =
        r'''query ( $page: Int = 1 $id: Int $type: MediaType $isAdult: Boolean = false $search: String $format: [MediaFormat] $status: MediaStatus $countryOfOrigin: CountryCode $source: MediaSource $season: MediaSeason $seasonYear: Int $year: String $onList: Boolean $yearLesser: FuzzyDateInt $yearGreater: FuzzyDateInt $episodeLesser: Int $episodeGreater: Int $durationLesser: Int $durationGreater: Int $chapterLesser: Int $chapterGreater: Int $volumeLesser: Int $volumeGreater: Int $licensedBy: [Int] $isLicensed: Boolean $genres: [String] $excludedGenres: [String] $tags: [String] $excludedTags: [String] $minimumTagRank: Int $sort: [MediaSort] = [POPULARITY_DESC, SCORE_DESC]) { Page(page: $page, perPage: 50) { pageInfo { total perPage currentPage lastPage hasNextPage } media( id: $id type: $type season: $season format_in: $format status: $status countryOfOrigin: $countryOfOrigin source: $source search: $search onList: $onList seasonYear: $seasonYear startDate_like: $year startDate_lesser: $yearLesser startDate_greater: $yearGreater episodes_lesser: $episodeLesser episodes_greater: $episodeGreater duration_lesser: $durationLesser duration_greater: $durationGreater chapters_lesser: $chapterLesser chapters_greater: $chapterGreater volumes_lesser: $volumeLesser volumes_greater: $volumeGreater licensedById_in: $licensedBy isLicensed: $isLicensed genre_in: $genres genre_not_in: $excludedGenres tag_in: $tags tag_not_in: $excludedTags minimumTagRank: $minimumTagRank sort: $sort isAdult: $isAdult ) { id idMal title { userPreferred romaji english native } coverImage { extraLarge large } bannerImage startDate { year month day } endDate { year month day } description season seasonYear type format status(version: 2) episodes duration chapters volumes genres synonyms source(version: 3) isAdult isLocked meanScore averageScore popularity favourites isFavouriteBlocked hashtag countryOfOrigin isLicensed isFavourite isRecommendationBlocked isFavouriteBlocked isReviewBlocked nextAiringEpisode { airingAt timeUntilAiring episode } relations { edges { id relationType(version: 2) node { id title { userPreferred } format type status(version: 2) bannerImage coverImage { large } } } } characterPreview: characters(perPage: 6, sort: [ROLE, RELEVANCE, ID]) { edges { id role name voiceActors(language: JAPANESE, sort: [RELEVANCE, ID]) { id name { userPreferred } language: languageV2 image { large } } node { id name { userPreferred } image { large } } } } staffPreview: staff(perPage: 8, sort: [RELEVANCE, ID]) { edges { id role node { id name { userPreferred } language: languageV2 image { large } } } } studios { edges { isMain node { id name } } } reviewPreview: reviews(perPage: 2, sort: [RATING_DESC, ID]) { pageInfo { total } nodes { id summary rating ratingAmount user { id name avatar { large } } } } recommendations(perPage: 7, sort: [RATING_DESC, ID]) { pageInfo { total } nodes { id rating userRating mediaRecommendation { id title { userPreferred } format type status(version: 2) bannerImage coverImage { large } } user { id name avatar { large } } } } externalLinks { id site url type language color icon notes isDisabled } streamingEpisodes { site title thumbnail url } trailer { id site thumbnail } rankings { id rank type format year season allTime context } updatedAt tags { id name category description rank isMediaSpoiler isGeneralSpoiler userId } mediaListEntry { id status score } stats { statusDistribution { status amount } scoreDistribution { score amount } } siteUrl } }}''';

    try {
      var headers = {'Content-Type': 'application/json', 'Accept': 'application/json'};
      var data = json.encode({
        "query": trendingQuery,
        "variables": {
          "page": page,
          "type": "ANIME",
          "sort": ["TRENDING_DESC", "POPULARITY_DESC"],
        },
      });

      var response = await _dio.request(
        'https://graphql.anilist.co',
        options: Options(method: 'POST', headers: headers),
        data: data,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = response.data;
        final pageJson = body['data']?['Page'];
        if (pageJson == null) {
          throw ProviderException(message: 'No Page in response', providerName: name);
        }
        final mediaJsonList = pageJson['media'] as List<dynamic>;
        return mediaJsonList.map((mediaJson) => _parseAnime(mediaJson)).toList();
      } else {
        throw ProviderException(message: 'Failed to load trending anime: ${response.statusCode}', providerName: name);
      }
    } catch (e, stackTrace) {
      if (e is ProviderException) rethrow;
      throw ProviderException(
        message: 'Error fetching trending anime',
        providerName: name,
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<Media> fetchAnimeById(int id) async {
    try {
      var headers = {'Content-Type': 'application/json', 'Accept': 'application/json'};
      var data = json.encode({
        "query":
            "query (\$id: Int){ Media(id:\$id,type:ANIME){ id idMal title{ romaji english native } type format status description startDate{ year month day } endDate{ year month day } season seasonYear episodes duration countryOfOrigin source hashtag trailer{ id site thumbnail } updatedAt coverImage{ extraLarge large } bannerImage genres synonyms averageScore tags{ id name category } siteUrl nextAiringEpisode { airingAt timeUntilAiring episode } characterPreview: characters(perPage: 6, sort: [ROLE, RELEVANCE, ID]) { edges { id role name voiceActors(language: JAPANESE, sort: [RELEVANCE, ID]) { id name { userPreferred } language: languageV2 image { large } } node { id name { userPreferred } image { large } } } } staffPreview: staff(perPage: 8, sort: [RELEVANCE, ID]) { edges { id role node { id name { userPreferred } language: languageV2 image { large } } } } studios { edges { isMain node { id name } } } } }",
        "variables": {"id": id},
      });

      var response = await _dio.request(
        'https://graphql.anilist.co',
        options: Options(method: 'POST', headers: headers),
        data: data,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = response.data;
        final mediaJson = body['data']?['Media'];
        if (mediaJson == null) {
          throw ProviderException(message: 'No Media in response', providerName: name);
        }
        return _parseAnime(mediaJson);
      } else {
        throw ProviderException(message: 'Failed to load anime: ${response.statusCode}', providerName: name);
      }
    } catch (e, stackTrace) {
      if (e is ProviderException) rethrow;
      throw ProviderException(
        message: 'Error fetching anime by ID',
        providerName: name,
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<List<Media>> searchAnime(String query, {int page = 1}) async {
    const searchQuery =
        r'''query ($page: Int, $search: String) { Page(page: $page, perPage: 10) { media(search: $search, type: ANIME) { id idMal title { userPreferred romaji english native } coverImage { extraLarge large } bannerImage startDate { year month day } endDate { year month day } description season seasonYear type format status(version: 2) episodes duration chapters volumes genres synonyms source(version: 3) isAdult isLocked meanScore averageScore popularity favourites isFavouriteBlocked hashtag countryOfOrigin isLicensed isFavourite isRecommendationBlocked isFavouriteBlocked isReviewBlocked nextAiringEpisode { airingAt timeUntilAiring episode } relations { edges { id relationType(version: 2) node { id title { userPreferred } format type status(version: 2) bannerImage coverImage { large } } } } characterPreview: characters(perPage: 6, sort: [ROLE, RELEVANCE, ID]) { edges { id role name voiceActors(language: JAPANESE, sort: [RELEVANCE, ID]) { id name { userPreferred } language: languageV2 image { large } } node { id name { userPreferred } image { large } } } } staffPreview: staff(perPage: 8, sort: [RELEVANCE, ID]) { edges { id role node { id name { userPreferred } language: languageV2 image { large } } } } studios { edges { isMain node { id name } } } reviewPreview: reviews(perPage: 2, sort: [RATING_DESC, ID]) { pageInfo { total } nodes { id summary rating ratingAmount user { id name avatar { large } } } } recommendations(perPage: 7, sort: [RATING_DESC, ID]) { pageInfo { total } nodes { id rating userRating mediaRecommendation { id title { userPreferred } format type status(version: 2) bannerImage coverImage { large } } user { id name avatar { large } } } } externalLinks { id site url type language color icon notes isDisabled } streamingEpisodes { site title thumbnail url } trailer { id site thumbnail } rankings { id rank type format year season allTime context } updatedAt tags { id name category description rank isMediaSpoiler isGeneralSpoiler userId } mediaListEntry { id status score } stats { statusDistribution { status amount } scoreDistribution { score amount } } siteUrl } }}''';

    try {
      var headers = {'Content-Type': 'application/json', 'Accept': 'application/json'};
      var data = json.encode({
        "query": searchQuery,
        "variables": {"page": page, "search": query},
      });

      var response = await _dio.request(
        'https://graphql.anilist.co',
        options: Options(method: 'POST', headers: headers),
        data: data,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = response.data;
        final pageJson = body['data']?['Page'];
        if (pageJson == null) {
          throw ProviderException(message: 'No Page in response', providerName: name);
        }
        final mediaJsonList = pageJson['media'] as List<dynamic>;
        return mediaJsonList.map((mediaJson) => _parseAnime(mediaJson)).toList();
      } else {
        throw ProviderException(message: 'Failed to search anime: ${response.statusCode}', providerName: name);
      }
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

  /// Parse anime from AniList API response
  Media _parseAnime(Map<String, dynamic> mediaJson) {
    final titleJson = mediaJson['title'];
    final title = AnimeTitle(romaji: titleJson['romaji'], english: titleJson['english'], native: titleJson['native']);

    final startDateJson = mediaJson['startDate'];
    final startDate = startDateJson != null
        ? AnimeDate(year: startDateJson['year'], month: startDateJson['month'], day: startDateJson['day'])
        : null;

    final endDateJson = mediaJson['endDate'];
    final endDate = endDateJson != null
        ? AnimeDate(year: endDateJson['year'], month: endDateJson['month'], day: endDateJson['day'])
        : null;

    final coverImageJson = mediaJson['coverImage'];
    final coverImage = CoverImage(extraLarge: coverImageJson['extraLarge'] ?? '', large: coverImageJson['large'] ?? '');

    final trailerJson = mediaJson['trailer'];
    final trailer = trailerJson != null
        ? Trailer(id: trailerJson['id'], site: trailerJson['site'], thumbnail: trailerJson['thumbnail'])
        : null;

    final tags =
        (mediaJson['tags'] as List?)?.map((e) => Tag(id: e['id'], name: e['name'], category: e['category'])).toList() ??
        [];

    final nextAiringEpisode = mediaJson["nextAiringEpisode"] != null
        ? NextAiringEpisode(
            airingAt: mediaJson["nextAiringEpisode"]["airingAt"],
            timeUntilAiring: mediaJson["nextAiringEpisode"]["timeUntilAiring"],
            episode: mediaJson["nextAiringEpisode"]["episode"],
          )
        : null;

    final characterPreview =
        (mediaJson['characterPreview']?['edges'] as List?)?.map((edge) {
          final voiceActors = ((edge['voiceActors'] as List?) ?? []).map((va) {
            return VoiceActor(
              id: va['id'],
              name: va['name']['userPreferred'],
              image: va['image']['large'],
              language: va['language'],
            );
          }).toList();

          final nodeJson = edge['node'];
          final characterNode = VoiceActor(
            id: nodeJson['id'],
            name: nodeJson['name']['userPreferred'],
            image: nodeJson['image']['large'],
          );

          return CharacterPreview(
            id: edge['id'],
            role: edge['role'],
            name: edge['name'],
            voiceActors: voiceActors,
            node: characterNode,
          );
        }).toList() ??
        [];

    final staffPreview =
        (mediaJson["staffPreview"]?["edges"] as List?)?.map((edge) {
          return StaffPreview(
            id: edge["id"],
            role: edge["role"],
            node: VoiceActor(
              id: edge["node"]["id"],
              name: edge["node"]["name"]["userPreferred"],
              image: edge["node"]["image"]["large"],
              language: edge["node"]["language"],
            ),
          );
        }).toList() ??
        [];

    final studios =
        (mediaJson["studios"]?["edges"] as List?)?.map((edge) {
          return Studio(isMain: edge["isMain"], id: edge["node"]["id"], name: edge["node"]["name"]);
        }).toList() ??
        [];

    return Media(
      id: mediaJson['id'],
      idMal: mediaJson['idMal'],
      title: title,
      type: mediaJson['type'] ?? '',
      format: mediaJson['format'],
      status: mediaJson['status'] ?? '',
      description: _stripHtmlIfNeeded(mediaJson['description']),
      startDate: startDate,
      endDate: endDate,
      season: mediaJson['season'],
      seasonYear: mediaJson['seasonYear'],
      episodes: mediaJson['episodes'],
      duration: mediaJson['duration'],
      countryOfOrigin: mediaJson['countryOfOrigin'] ?? '',
      nextAiringEpisode: nextAiringEpisode,
      characterPreview: characterPreview,
      staffPreview: staffPreview,
      studios: studios,
      source: mediaJson['source'],
      hashtag: mediaJson['hashtag'],
      trailer: trailer,
      updatedAt: mediaJson['updatedAt'] ?? 0,
      coverImage: coverImage,
      bannerImage: mediaJson['bannerImage'],
      genres: List<String>.from(mediaJson['genres'] ?? []),
      synonyms: List<String>.from(mediaJson['synonyms'] ?? []),
      averageScore: mediaJson['averageScore'],
      tags: tags,
      siteUrl: mediaJson['siteUrl'] ?? '',
    );
  }

  /// Strip HTML tags from description
  String _stripHtmlIfNeeded(String? text) {
    if (text == null) return '';

    // Remove newlines from the API, then replace <br> with a newline
    final textWithNewlines = text.replaceAll('\n', '').replaceAll(RegExp(r'<br\s*/?>'), '\n');

    // Parse the HTML
    final document = html_parser.parse(textWithNewlines);

    // Return the text content
    return document.body?.text ?? '';
  }

  @override
  void dispose() {
    _dio.close();
  }
}
