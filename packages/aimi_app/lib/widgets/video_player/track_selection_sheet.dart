import 'package:flutter/material.dart';
import 'package:scroll_animator/scroll_animator.dart';

class TrackSelectionSheet<T> extends StatelessWidget {
  final String title;
  final List<T> tracks;
  final T currentTrack;
  final Function(T) onTrackSelected;
  final String Function(T) trackLabelBuilder;

  const TrackSelectionSheet({
    super.key,
    required this.title,
    required this.tracks,
    required this.currentTrack,
    required this.onTrackSelected,
    required this.trackLabelBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const BackButton(),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
          ),
          const Divider(),
          Flexible(
            child: AnimatedPrimaryScrollController(
              animationFactory: const ChromiumEaseInOut(),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: tracks.length,
                itemBuilder: (context, index) {
                  final track = tracks[index];
                  final isSelected = track == currentTrack;
                  return ListTile(
                    title: Text(trackLabelBuilder(track)),
                    trailing: isSelected ? const Icon(Icons.check) : null,
                    onTap: () {
                      onTrackSelected(track);
                      Navigator.pop(context, true);
                    },
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
