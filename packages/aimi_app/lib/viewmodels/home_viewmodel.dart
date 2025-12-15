import 'package:flutter/foundation.dart';

import '../models/anime.dart';
import '../services/anime_service.dart';

class HomeViewModel extends ChangeNotifier {
  final AnimeService _animeService;

  HomeViewModel(this._animeService);

  final List<Anime> _trendingAnime = [];

  List<Anime> get trendingAnime => _trendingAnime;

  int _currentPage = 1;

  int get currentPage => _currentPage;

  bool _isLoading = false;

  bool get isLoading => _isLoading;

  String? _errorMessage;

  String? get errorMessage => _errorMessage;

  Future<void> fetchTrending() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      _trendingAnime.clear();

      final animeList = await _animeService.fetchTrending(page: 1);
      _trendingAnime.addAll(animeList);

      _currentPage = 1;
    } catch (e) {
      _errorMessage = 'Failed to load trending anime: ${e.toString()}';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreTrendingAnime() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      _currentPage++;

      final animeList = await _animeService.fetchTrending(page: _currentPage, forceRefresh: true);
      _trendingAnime.addAll(animeList);
    } catch (e) {
      _errorMessage = 'Failed to load more trending anime: ${e.toString()}';
      _currentPage--; // Revert page increment on error
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
