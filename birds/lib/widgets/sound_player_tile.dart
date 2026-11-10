
import 'dart:async';

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
  static AudioPlayer? activePlayer;

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

      if (activePlayer != null && activePlayer != player) {
        await activePlayer!.pause();
      }

      activePlayer = player;

      if (player.processingState == ProcessingState.idle) {
        await player.setUrl(url);
      }

      if (player.processingState == ProcessingState.completed) {
        await player.seek(Duration.zero);
      }

      if (!mounted) return;

      setState(() => loading = false);

      unawaited(
        player.play().catchError((Object e) {
          if (mounted) {
            setState(() {
              error = 'Playback failed: $e';
            });
          }
        }),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          error = 'Could not play audio: $e';
        });
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

  Widget buildMetadata(String label, String? value) {
    if (value == null || value.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  @override
  void dispose() {
    if (activePlayer == player) {
      activePlayer = null;
    }

    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sound = widget.sound;

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
                            final state = snapshot.data;
                            final playing = state?.playing ?? false;

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
                        sound.title ?? 'Bird sound',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        [
                          if (sound.type != null) sound.type!,
                          if (sound.source != null) sound.source!,
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

                    final totalMs = duration?.inMilliseconds ?? 0;

                    final currentMs =
                        position.inMilliseconds.clamp(0, totalMs);

                    return Column(
                      children: [
                        Slider(
                          value: totalMs > 0
                              ? currentMs.toDouble()
                              : 0,
                          max: totalMs > 0 ? totalMs.toDouble() : 1,
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

            if (sound.recordist != null)
              buildMetadata('Recorded by', sound.recordist),

            if (sound.description != null)
              buildMetadata('Description', sound.description),

            if (sound.license != null)
              buildMetadata('License', sound.license),

            if (sound.sourceUrl != null &&
                sound.sourceUrl!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: SelectableText(
                  'Source: ${sound.sourceUrl}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ),

            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
