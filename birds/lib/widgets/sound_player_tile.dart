
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../models/sound.dart';

class SoundPlayerTile extends StatefulWidget {
  final Sound sound;

  const SoundPlayerTile({
    super.key,
    required this.sound,
  });

  @override
  State<SoundPlayerTile> createState() => _SoundPlayerTileState();
}

class _SoundPlayerTileState extends State<SoundPlayerTile> {
  late final AudioPlayer player;

  bool loading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    player = AudioPlayer();
  }

  Future<void> togglePlayback() async {
    if (loading) return;

    if (player.playing) {
      await player.pause();
      return;
    }

    final url = widget.sound.fileUrl;

    if (url == null || url.isEmpty) {
      setState(() => error = 'Audio URL is missing');
      return;
    }

    final uri = Uri.tryParse(url);

    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      setState(() => error = 'Invalid audio URL');
      return;
    }

    try {
      setState(() {
        loading = true;
        error = null;
      });

      if (player.processingState == ProcessingState.idle) {
        await player.setUrl(url);
      }

      await player.play();
    } catch (e) {
      if (mounted) {
        setState(() => error = 'Could not play audio');
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  String formatDuration(Duration? duration) {
    if (duration == null) return '--:--';

    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);

    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: loading ? null : togglePlayback,
                  icon: loading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : StreamBuilder<PlayerState>(
                          stream: player.playerStateStream,
                          builder: (context, snapshot) {
                            final playing =
                                snapshot.data?.playing ?? false;

                            return Icon(
                              playing
                                  ? Icons.pause_circle
                                  : Icons.play_circle,
                              size: 36,
                            );
                          },
                        ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.sound.title ?? 'Bird sound',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium,
                      ),
                      Text(
                        [
                          if (widget.sound.type != null)
                            widget.sound.type!,
                          if (widget.sound.source != null)
                            widget.sound.source!,
                        ].join(' • '),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            StreamBuilder<Duration?>(
              stream: player.durationStream,
              builder: (context, durationSnapshot) {
                final duration = durationSnapshot.data;

                return StreamBuilder<Duration>(
                  stream: player.positionStream,
                  builder: (context, positionSnapshot) {
                    final position =
                        positionSnapshot.data ?? Duration.zero;

                    final totalMs =
                        duration?.inMilliseconds ?? 0;

                    final currentMs =
                        position.inMilliseconds.clamp(0, totalMs);

                    return Column(
                      children: [
                        Slider(
                          value: totalMs > 0
                              ? currentMs.toDouble()
                              : 0,
                          max: totalMs > 0
                              ? totalMs.toDouble()
                              : 1,
                          onChanged: totalMs > 0
                              ? (value) {
                                  player.seek(
                                    Duration(
                                      milliseconds: value.round(),
                                    ),
                                  );
                                }
                              : null,
                        ),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(formatDuration(position)),
                            Text(formatDuration(duration)),
                          ],
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            if (error != null)
              Text(
                error!,
                style: const TextStyle(color: Colors.red),
              ),
            if (widget.sound.license != null)
              Text(
                'License: ${widget.sound.license}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}
