import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:scroll_animator/scroll_animator.dart';

import '../../models/streaming_source.dart';

/// Video settings sheet with quality, speed, audio, and subtitle options.
class VideoSettingsSheet extends StatelessWidget {
  final List<StreamingSource> sources;
  final StreamingSource currentSource;
  final void Function(int) onQualitySelected;
  final double playbackSpeed;
  final void Function(double) onPlaybackSpeedSelected;
  final Tracks tracks;
  final Track selectedTrack;
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
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final qualityOptions = _buildQualityOptions();
    final subtitleOptions = _buildSubtitleOptions();
    final audioCount = tracks.audio.where((t) => t.id != 'auto' && t.id != 'no').length;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: _isMobile ? 8 : 12),
            child: Text(
              'Settings',
              style: _isMobile ? Theme.of(context).textTheme.titleMedium : Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: AnimatedPrimaryScrollController(
              animationFactory: const ChromiumEaseInOut(),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SettingsTile(
                      icon: Icons.high_quality,
                      title: 'Quality',
                      subtitle: qualityOptions
                          .firstWhere((o) => o.isSelected, orElse: () => qualityOptions.first)
                          .label,
                      isMobile: _isMobile,
                      onTap: () => _showOptionSheet(
                        context,
                        title: 'Quality',
                        options: qualityOptions,
                        onSelected: (opt) {
                          if (opt.sourceIndex != null) {
                            onQualitySelected(opt.sourceIndex!);
                          }
                          if (opt.videoTrack != null) {
                            onVideoTrackSelected(opt.videoTrack!);
                          }
                        },
                      ),
                    ),
                    _SettingsTile(
                      icon: Icons.speed,
                      title: 'Playback Speed',
                      subtitle: '${playbackSpeed}x',
                      isMobile: _isMobile,
                      onTap: () => _showOptionSheet(
                        context,
                        title: 'Playback Speed',
                        options: [
                          0.25,
                          0.5,
                          0.75,
                          1.0,
                          1.25,
                          1.5,
                          2.0,
                        ].map((s) => _Option(label: '${s}x', value: s, isSelected: s == playbackSpeed)).toList(),
                        onSelected: (opt) => onPlaybackSpeedSelected(opt.value as double),
                      ),
                    ),
                    _SettingsTile(
                      icon: Icons.audiotrack,
                      title: 'Audio',
                      subtitle: audioCount == 0 ? 'Default' : _formatTrack(selectedTrack.audio),
                      isMobile: _isMobile,
                      onTap: tracks.audio.isEmpty
                          ? null
                          : () => _showOptionSheet(
                              context,
                              title: 'Audio Track',
                              options: tracks.audio
                                  .map(
                                    (t) => _Option(
                                      label: _formatTrack(t),
                                      value: t,
                                      isSelected: t.id == selectedTrack.audio.id,
                                    ),
                                  )
                                  .toList(),
                              onSelected: (opt) => onAudioTrackSelected(opt.value as AudioTrack),
                            ),
                    ),
                    _SettingsTile(
                      icon: Icons.subtitles,
                      title: 'Subtitles',
                      subtitle: _formatTrack(selectedTrack.subtitle),
                      isMobile: _isMobile,
                      onTap: subtitleOptions.isEmpty
                          ? null
                          : () => _showOptionSheet(
                              context,
                              title: 'Subtitle Track',
                              options: subtitleOptions,
                              onSelected: (opt) => onSubtitleTrackSelected(opt.value as SubtitleTrack),
                            ),
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

  List<_Option> _buildQualityOptions() {
    final options = <_Option>[];

    final hasQualitySources = sources.any(
      (s) => s.quality.isNotEmpty && s.quality.toLowerCase() != 'default' && s.quality.toLowerCase() != 'auto',
    );

    final videoTracksWithRes = tracks.video.where((t) => t.id != 'auto' && t.id != 'no' && t.h != null).toList();

    if (hasQualitySources || sources.length > 1) {
      for (var i = 0; i < sources.length; i++) {
        final source = sources[i];
        var label = source.quality;
        if (label.isEmpty || label.toLowerCase() == 'default') {
          label = (i < videoTracksWithRes.length) ? '${videoTracksWithRes[i].h}p' : 'Quality ${i + 1}';
        }
        options.add(_Option(label: label, sourceIndex: i, isSelected: source == currentSource));
      }
    }

    if (!hasQualitySources && videoTracksWithRes.isNotEmpty) {
      for (final track in videoTracksWithRes) {
        options.add(_Option(label: '${track.h}p', videoTrack: track, isSelected: selectedTrack.video.id == track.id));
      }
    }

    if (options.isEmpty) {
      options.add(_Option(label: 'Auto', videoTrack: VideoTrack.auto(), isSelected: true));
    }

    return options;
  }

  List<_Option> _buildSubtitleOptions() {
    final seen = <String>{};
    final allSubs = [...tracks.subtitle, ...externalSubtitles];
    return allSubs
        .where((s) => seen.add(s.id))
        .map((s) => _Option(label: _formatTrack(s), value: s, isSelected: s.id == selectedTrack.subtitle.id))
        .toList();
  }

  String _formatTrack(dynamic track) {
    if (track is AudioTrack) {
      if (track.id == 'auto') return 'Auto';
      if (track.id == 'no') return 'None';
      return track.title ?? _formatLang(track.language) ?? 'Track ${track.id}';
    } else if (track is SubtitleTrack) {
      if (track.id == 'auto') return 'Auto';
      if (track.id == 'no') return 'None';
      return track.title ?? _formatLang(track.language) ?? 'Track ${track.id}';
    }
    return track.toString();
  }

  String? _formatLang(String? code) {
    if (code == null) return null;
    const map = {
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
    return map[code.toLowerCase()] ?? code.toUpperCase();
  }

  Future<void> _showOptionSheet(
    BuildContext context, {
    required String title,
    required List<_Option> options,
    required void Function(_Option) onSelected,
  }) async {
    final result = await showModalBottomSheet<_Option>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _OptionSheet(title: title, options: options, isMobile: _isMobile),
    );

    if (result != null && context.mounted) {
      onSelected(result);
      Navigator.pop(context);
    }
  }
}

/// Single option for selection
class _Option {
  final String label;
  final dynamic value;
  final int? sourceIndex;
  final VideoTrack? videoTrack;
  final bool isSelected;

  const _Option({required this.label, this.value, this.sourceIndex, this.videoTrack, this.isSelected = false});
}

/// Reusable settings tile
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isMobile;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isMobile,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: isMobile ? const EdgeInsets.symmetric(horizontal: 12, vertical: 4) : null,
      leading: Icon(icon, size: isMobile ? 20.0 : 24.0),
      title: Text(title, style: isMobile ? Theme.of(context).textTheme.bodyMedium : null),
      subtitle: Text(
        subtitle,
        style: isMobile ? Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey) : null,
      ),
      dense: isMobile,
      onTap: onTap,
    );
  }
}

/// Generic option sheet for all selectors
class _OptionSheet extends StatelessWidget {
  final String title;
  final List<_Option> options;
  final bool isMobile;

  const _OptionSheet({required this.title, required this.options, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      padding: EdgeInsets.symmetric(vertical: isMobile ? 8 : 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: isMobile ? 4 : 8),
            child: Row(
              children: [
                const BackButton(),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: isMobile ? Theme.of(context).textTheme.titleMedium : Theme.of(context).textTheme.titleLarge,
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
                    dense: isMobile,
                    title: Text(option.label),
                    trailing: option.isSelected ? const Icon(Icons.check) : null,
                    onTap: () => Navigator.pop(context, option),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
