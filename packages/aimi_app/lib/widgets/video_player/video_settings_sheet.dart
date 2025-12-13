import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:scroll_animator/scroll_animator.dart';

import '../../models/streaming_source.dart';
import 'track_selection_sheet.dart';

/// Represents a quality option that can be either a streaming source or a video track
class QualityOption {
  final String label;
  final int? sourceIndex;
  final VideoTrack? videoTrack;
  final bool isSelected;

  const QualityOption({required this.label, this.sourceIndex, this.videoTrack, this.isSelected = false});

  bool get isSourceBased => sourceIndex != null;

  bool get isTrackBased => videoTrack != null;
}

class VideoSettingsSheet extends StatelessWidget {
  final List<StreamingSource> sources;
  final StreamingSource currentSource;
  final void Function(int) onQualitySelected;

  final double playbackSpeed;
  final void Function(double) onPlaybackSpeedSelected;

  final Tracks tracks;
  final Track selectedTrack;

  /// External subtitle tracks loaded from the source (e.g., Anizone)
  final List<SubtitleTrack> externalSubtitles;

  final void Function(VideoTrack) onVideoTrackSelected;
  final void Function(AudioTrack) onAudioTrackSelected;
  final void Function(SubtitleTrack) onSubtitleTrackSelected;

  const VideoSettingsSheet({
    super.key,
    required this.sources,
    required this.currentSource,
    required this.onQualitySelected,
    required this.playbackSpeed,
    required this.onPlaybackSpeedSelected,
    required this.tracks,
    required this.selectedTrack,
    this.externalSubtitles = const [],
    required this.onVideoTrackSelected,
    required this.onAudioTrackSelected,
    required this.onSubtitleTrackSelected,
  });

  bool get _isMobile {
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (e) {
      return false;
    }
  }

  /// Build quality options combining sources and video tracks
  List<QualityOption> _buildQualityOptions() {
    final options = <QualityOption>[];

    // Check if sources have meaningful quality labels (not just "default" or empty)
    final hasQualitySources = sources.any(
      (s) => s.quality.isNotEmpty && s.quality.toLowerCase() != 'default' && s.quality.toLowerCase() != 'auto',
    );

    // Check if video tracks have meaningful resolution info
    final videoTracksWithResolution = tracks.video
        .where((t) => t.id != 'auto' && t.id != 'no' && (t.w != null && t.h != null))
        .toList();

    final hasVideoTrackQuality = videoTracksWithResolution.isNotEmpty;

    // Prefer sources if they have quality info, otherwise use video tracks
    if (hasQualitySources || sources.length > 1) {
      // Add source-based options
      for (var i = 0; i < sources.length; i++) {
        final source = sources[i];
        String label = source.quality;
        if (label.isEmpty || label.toLowerCase() == 'default') {
          // Try to use video track resolution as fallback
          if (hasVideoTrackQuality && i < videoTracksWithResolution.length) {
            final track = videoTracksWithResolution[i];
            label = '${track.h}p';
          } else {
            label = 'Quality ${i + 1}';
          }
        }
        options.add(QualityOption(label: label, sourceIndex: i, isSelected: source == currentSource));
      }
    }

    // If sources don't have quality but video tracks do, add track-based options
    if (!hasQualitySources && hasVideoTrackQuality) {
      for (final track in videoTracksWithResolution) {
        final label = _formatVideoTrackQuality(track);
        options.add(QualityOption(label: label, videoTrack: track, isSelected: selectedTrack.video.id == track.id));
      }
    }

    // If we still have no options, at least show Auto
    if (options.isEmpty) {
      options.add(QualityOption(label: 'Auto', videoTrack: VideoTrack.auto(), isSelected: true));
    }

    return options;
  }

  /// Format video track for quality display
  String _formatVideoTrackQuality(VideoTrack track) {
    if (track.id == 'auto') return 'Auto';
    if (track.id == 'no') return 'None';

    final w = track.w;
    final h = track.h;

    // Format as "1080p", "720p", etc.
    if (h != null) {
      return '${h}p';
    }
    if (w != null && h != null) {
      return '${w}x$h';
    }

    final title = track.title;
    if (title != null && title.isNotEmpty) return title;

    return 'Track ${track.id}';
  }

  /// Get the current quality label for display
  String _getCurrentQualityLabel() {
    final options = _buildQualityOptions();
    final selected = options.where((o) => o.isSelected).firstOrNull;
    return selected?.label ?? currentSource.quality;
  }

  /// Format audio track for display
  String _formatAudioTrack(AudioTrack track) {
    if (track.id == 'auto') return 'Auto';
    if (track.id == 'no') return 'None';
    final title = track.title;
    final lang = track.language;
    if (title != null && title.isNotEmpty) return title;
    if (lang != null && lang.isNotEmpty) return _formatLanguage(lang);
    return 'Track ${track.id}';
  }

  /// Format subtitle track for display
  String _formatSubtitleTrack(SubtitleTrack track) {
    if (track.id == 'auto') return 'Auto';
    if (track.id == 'no') return 'None';
    final title = track.title;
    final lang = track.language;
    if (title != null && title.isNotEmpty) return title;
    if (lang != null && lang.isNotEmpty) return _formatLanguage(lang);
    return 'Track ${track.id}';
  }

  /// Format language code to readable name
  String _formatLanguage(String langCode) {
    const langMap = {
      'eng': 'English',
      'en': 'English',
      'jpn': 'Japanese',
      'ja': 'Japanese',
      'spa': 'Spanish',
      'es': 'Spanish',
      'por': 'Portuguese',
      'pt': 'Portuguese',
      'fre': 'French',
      'fr': 'French',
      'ger': 'German',
      'de': 'German',
      'ita': 'Italian',
      'it': 'Italian',
      'rus': 'Russian',
      'ru': 'Russian',
      'kor': 'Korean',
      'ko': 'Korean',
      'chi': 'Chinese',
      'zh': 'Chinese',
      'ara': 'Arabic',
      'ar': 'Arabic',
    };
    return langMap[langCode.toLowerCase()] ?? langCode.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final contentPadding = _isMobile ? const EdgeInsets.symmetric(horizontal: 12, vertical: 4) : null;
    final iconSize = _isMobile ? 20.0 : 24.0;
    final titleStyle = _isMobile ? Theme.of(context).textTheme.bodyMedium : null;
    final subtitleStyle = _isMobile ? Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey) : null;

    // Count real audio tracks (excluding auto/no placeholders)
    final realAudioCount = tracks.audio.where((t) => t.id != 'auto' && t.id != 'no').length;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: _isMobile ? 8 : 12),
            child: Text(
              'Settings',
              style: _isMobile ? Theme.of(context).textTheme.titleMedium : Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const Divider(height: 1),

          // Scrollable content
          Flexible(
            child: AnimatedPrimaryScrollController(
              animationFactory: const ChromiumEaseInOut(),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Quality (combined sources + video tracks)
                    ListTile(
                      contentPadding: contentPadding,
                      leading: Icon(Icons.high_quality, size: iconSize),
                      title: Text('Quality', style: titleStyle),
                      subtitle: Text(_getCurrentQualityLabel(), style: subtitleStyle),
                      dense: _isMobile,
                      onTap: () async => await _showQualitySelector(context),
                    ),

                    // Speed
                    ListTile(
                      contentPadding: contentPadding,
                      leading: Icon(Icons.speed, size: iconSize),
                      title: Text('Playback Speed', style: titleStyle),
                      subtitle: Text('${playbackSpeed}x', style: subtitleStyle),
                      dense: _isMobile,
                      onTap: () async => await _showSpeedSelector(context),
                    ),

                    // Audio Tracks
                    ListTile(
                      contentPadding: contentPadding,
                      leading: Icon(Icons.audiotrack, size: iconSize),
                      title: Text('Audio', style: titleStyle),
                      subtitle: Text(
                        realAudioCount == 0 ? 'Default' : _formatAudioTrack(selectedTrack.audio),
                        style: subtitleStyle,
                      ),
                      dense: _isMobile,
                      onTap: tracks.audio.isNotEmpty
                          ? () async => await _showTrackSelector<AudioTrack>(
                              context,
                              'Audio Track',
                              tracks.audio,
                              selectedTrack.audio,
                              onAudioTrackSelected,
                              _formatAudioTrack,
                            )
                          : null,
                    ),

                    // Subtitle Tracks (combine player tracks with external subtitles)
                    Builder(
                      builder: (context) {
                        // Combine player subtitle tracks with external subtitles
                        final List<SubtitleTrack> allSubtitles = [...tracks.subtitle, ...externalSubtitles];

                        // Remove duplicates (by id)
                        final seen = <String>{};
                        final uniqueSubtitles = allSubtitles.where((s) {
                          if (seen.contains(s.id)) return false;
                          seen.add(s.id);
                          return true;
                        }).toList();

                        return ListTile(
                          contentPadding: contentPadding,
                          leading: Icon(Icons.subtitles, size: iconSize),
                          title: Text('Subtitles', style: titleStyle),
                          subtitle: Text(_formatSubtitleTrack(selectedTrack.subtitle), style: subtitleStyle),
                          dense: _isMobile,
                          onTap: uniqueSubtitles.isNotEmpty
                              ? () async => await _showTrackSelector<SubtitleTrack>(
                                  context,
                                  'Subtitle Track',
                                  uniqueSubtitles,
                                  selectedTrack.subtitle,
                                  onSubtitleTrackSelected,
                                  _formatSubtitleTrack,
                                )
                              : null,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showQualitySelector(BuildContext context) async {
    final options = _buildQualityOptions();

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        padding: EdgeInsets.symmetric(vertical: _isMobile ? 8 : 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: _isMobile ? 4 : 8),
              child: Row(
                children: [
                  const BackButton(),
                  const SizedBox(width: 8),
                  Text(
                    'Quality',
                    style: _isMobile ? Theme.of(context).textTheme.titleMedium : Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: AnimatedPrimaryScrollController(
                animationFactory: const ChromiumEaseInOut(),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final option = options[index];
                    return ListTile(
                      dense: _isMobile,
                      title: Text(option.label),
                      trailing: option.isSelected ? const Icon(Icons.check) : null,
                      onTap: () {
                        if (option.isSourceBased) {
                          onQualitySelected(option.sourceIndex!);
                        } else if (option.isTrackBased) {
                          onVideoTrackSelected(option.videoTrack!);
                        }
                        Navigator.pop(context, true);
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (result == true && context.mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _showSpeedSelector(BuildContext context) async {
    final speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        padding: EdgeInsets.symmetric(vertical: _isMobile ? 8 : 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: _isMobile ? 4 : 8),
              child: Row(
                children: [
                  const BackButton(),
                  const SizedBox(width: 8),
                  Text(
                    'Playback Speed',
                    style: _isMobile ? Theme.of(context).textTheme.titleMedium : Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: AnimatedPrimaryScrollController(
                animationFactory: const ChromiumEaseInOut(),
                child: ListView(
                  shrinkWrap: true,
                  children: speeds
                      .map(
                        (speed) => ListTile(
                          dense: _isMobile,
                          title: Text('${speed}x'),
                          trailing: speed == playbackSpeed ? const Icon(Icons.check) : null,
                          onTap: () {
                            onPlaybackSpeedSelected(speed);
                            Navigator.pop(context, true);
                          },
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (result == true && context.mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _showTrackSelector<T>(
    BuildContext context,
    String title,
    List<T> tracks,
    T currentTrack,
    Function(T) onSelected,
    String Function(T) labelBuilder,
  ) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => TrackSelectionSheet<T>(
        title: title,
        tracks: tracks,
        currentTrack: currentTrack,
        onTrackSelected: onSelected,
        trackLabelBuilder: labelBuilder,
      ),
    );

    if (result == true && context.mounted) {
      Navigator.pop(context);
    }
  }
}
