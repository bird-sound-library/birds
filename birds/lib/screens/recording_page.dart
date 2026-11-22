import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../models/bird.dart';
import '../screens/bird_details_page.dart';
import '../services/audio_recorder_service.dart';
import '../services/bird_api.dart';

class RecordingPage extends StatefulWidget {
  const RecordingPage({super.key});

  @override
  State<RecordingPage> createState() => _RecordingPageState();
}

class _RecordingPageState extends State<RecordingPage> {
  final AudioRecorderService recorder = AudioRecorderService();
  final BirdApi api = BirdApi();
  final AudioPlayer audioPlayer = AudioPlayer();

  bool isRecording = false;
  bool isAudioLoading = false;
  String? audioError;
  bool isUploading = false;

  String? recordedPath;
  Map<String, dynamic>? recordingResult;
  String? errorMessage;

  static const Duration maxRecordingDuration = Duration(seconds: 15);

  final Stopwatch stopwatch = Stopwatch();
  Timer? timer;
  Duration duration = Duration.zero;
  bool isStopping = false;
  final Map<int, Future<Bird>> birdDetailFutures = {};

  Duration get remainingDuration {
    final remaining = maxRecordingDuration - duration;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Future<void> startRecording() async {
    if (isRecording || isUploading || isStopping) return;

    try {
      await recorder.startRecording();
      if (!mounted) return;

      setState(() {
        isRecording = true;
        recordedPath = null;
        recordingResult = null;
        errorMessage = null;
        duration = Duration.zero;
      });

      stopwatch
        ..reset()
        ..start();

      timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (!mounted || !isRecording || isStopping) return;

        final elapsed = stopwatch.elapsed;
        final reachedLimit = elapsed >= maxRecordingDuration;

        setState(() {
          duration = reachedLimit ? maxRecordingDuration : elapsed;
        });

        if (reachedLimit) {
          stopRecording();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => errorMessage = e.toString());
    }
  }

  Future<void> stopRecording() async {
    if (!isRecording || isStopping) return;

    isStopping = true;
    timer?.cancel();
    stopwatch.stop();

    try {
      final path = await recorder.stopRecording();
      if (!mounted) return;

      setState(() {
        isRecording = false;
        recordedPath = path;
        duration = stopwatch.elapsed > maxRecordingDuration
            ? maxRecordingDuration
            : stopwatch.elapsed;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isRecording = false;
        errorMessage = e.toString();
      });
    } finally {
      isStopping = false;
    }
  }

  Future<void> uploadRecording() async {
    final path = recordedPath;
    if (path == null || isUploading) return;

    setState(() {
      isUploading = true;
      errorMessage = null;
      recordingResult = null;
    });

    try {
      final result = await api.uploadRecording(path);
      if (!mounted) return;

      setState(() {
        recordingResult = result;
        audioError = null;
      });

      final fileUrl = result['file_url']?.toString();
      if (fileUrl != null && fileUrl.isNotEmpty) {
        await loadUploadedAudio(fileUrl);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => isUploading = false);
    }
  }

  Future<void> loadUploadedAudio(String fileUrl) async {
    setState(() {
      isAudioLoading = true;
      audioError = null;
    });

    try {
      final audioUri = Uri.parse(BirdApi.baseUrl).resolve(fileUrl);
      await audioPlayer.setUrl(audioUri.toString());
    } catch (e) {
      if (!mounted) return;
      setState(() => audioError = 'Could not load recording: $e');
    } finally {
      if (mounted) setState(() => isAudioLoading = false);
    }
  }

  void tryAgain() {
    audioPlayer.stop();
    setState(() {
      recordingResult = null;
      recordedPath = null;
      errorMessage = null;
      audioError = null;
      duration = Duration.zero;
    });
  }

  String _formatPlayerTime(Duration value) {
    final minutes = value.inMinutes;
    final seconds = value.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildAudioPlayer(ThemeData theme, ColorScheme colors) {
    if (isAudioLoading) {
      return Card(
        color: colors.surface.withValues(alpha: 0.88),
        child: const Padding(
          padding: EdgeInsets.all(18),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Loading recorded audio...'),
            ],
          ),
        ),
      );
    }

    if (audioError != null) {
      return Card(
        color: colors.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Text(
            audioError!,
            style: TextStyle(color: colors.onErrorContainer),
          ),
        ),
      );
    }

    return Card(
      color: colors.surface.withValues(alpha: 0.88),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.headphones, color: colors.primary),
                const SizedBox(width: 8),
                Text(
                  'Your recording',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                StreamBuilder<PlayerState>(
                  stream: audioPlayer.playerStateStream,
                  builder: (context, snapshot) {
                    final isPlaying = snapshot.data?.playing ?? false;
                    final processing = snapshot.data?.processingState;
                    final isEnded = processing == ProcessingState.completed;

                    return IconButton.filledTonal(
                      tooltip: isPlaying ? 'Pause' : 'Play',
                      onPressed: isAudioLoading
                          ? null
                          : () async {
                              if (isPlaying) {
                                await audioPlayer.pause();
                              } else {
                                if (isEnded) await audioPlayer.seek(Duration.zero);
                                await audioPlayer.play();
                              }
                            },
                      icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                    );
                  },
                ),
              ],
            ),
            StreamBuilder<Duration?>(
              stream: audioPlayer.durationStream,
              builder: (context, durationSnapshot) {
                final total = durationSnapshot.data ?? Duration.zero;
                return StreamBuilder<Duration>(
                  stream: audioPlayer.positionStream,
                  builder: (context, positionSnapshot) {
                    final position = positionSnapshot.data ?? Duration.zero;
                    final maxMs = total.inMilliseconds;
                    final currentMs = position.inMilliseconds
                        .clamp(0, maxMs > 0 ? maxMs : 0);

                    return Column(
                      children: [
                        Slider(
                          value: maxMs > 0 ? currentMs.toDouble() : 0,
                          max: maxMs > 0 ? maxMs.toDouble() : 1,
                          onChanged: maxMs <= 0
                              ? null
                              : (value) => audioPlayer.seek(
                                    Duration(milliseconds: value.round()),
                                  ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_formatPlayerTime(position)),
                              Text(_formatPlayerTime(total)),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> openBirdDetails(int birdId) async {
    try {
      final Bird bird = await api.getBird(birdId);
      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BirdDetailsPage(bird: bird),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open bird details: $e')),
      );
    }
  }

  String formatDuration(Duration value) {
    final minutes = value.inMinutes;
    final seconds = value.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String _valueAsString(dynamic value, {String fallback = '—'}) {
    if (value == null || value.toString().isEmpty) return fallback;
    return value.toString();
  }

  String _confidence(dynamic value) {
    if (value == null) return '—';
    final number = double.tryParse(value.toString());
    if (number == null) return value.toString();
    return '${(number * 100).toStringAsFixed(1)}%';
  }

  Widget _buildIdentificationCard(
    Map<String, dynamic> identification,
    ThemeData theme,
    ColorScheme colors,
  ) {
    final bird = identification['bird'] is Map
        ? Map<String, dynamic>.from(identification['bird'] as Map)
        : <String, dynamic>{};

    final intervals = identification['intervals'] is List
        ? identification['intervals'] as List
        : const [];

    final birdId = bird['bird_id'] is int
        ? bird['bird_id'] as int
        : int.tryParse('${bird['bird_id']}');

    return Card(
      color: colors.surface.withValues(alpha: 0.88),
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Large bird photograph at the top.
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: double.infinity,
                height: 240,
                child: birdId == null
                    ? _birdImageFallback(colors)
                    : FutureBuilder<Bird>(
                        future: birdDetailFutures.putIfAbsent(
                          birdId,
                          () => api.getBird(birdId),
                        ),
                        builder: (context, snapshot) {
                          final imageUrl = snapshot.data?.imageUrl;
                          if (snapshot.hasData &&
                              imageUrl != null &&
                              imageUrl.isNotEmpty) {
                            return Image.network(
                              imageUrl,
                              width: double.infinity,
                              height: 240,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  _birdImageFallback(colors),
                            );
                          }
                          return _birdImageFallback(colors);
                        },
                      ),
              ),
            ),
            const SizedBox(height: 18),

            // All bird information is placed below the photograph.
            Text(
              _valueAsString(
                bird['common_name'],
                fallback: 'Unknown bird',
              ),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _valueAsString(
                bird['scientific_name'],
                fallback: 'Scientific name unavailable',
              ),
              style: theme.textTheme.titleMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _metricChip(
                  colors,
                  'Confidence',
                  _confidence(identification['max_confidence']),
                ),
                _metricChip(
                  colors,
                  'Average',
                  _confidence(identification['avg_confidence']),
                ),
                _metricChip(
                  colors,
                  'Detections',
                  _valueAsString(identification['detections']),
                ),
              ],
            ),
            if (intervals.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                'Detection intervals',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...intervals.map((item) {
                final interval = item is Map
                    ? Map<String, dynamic>.from(item)
                    : <String, dynamic>{};
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 16,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_valueAsString(interval['start_time'])} s'
                        ' – ${_valueAsString(interval['end_time'])} s',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                );
              }),
            ],
            if (birdId != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => openBirdDetails(birdId),
                  icon: const Icon(Icons.info_outline),
                  label: const Text('View bird details'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _birdImageFallback(ColorScheme colors) {
    return Container(
      color: colors.primaryContainer,
      child: Icon(
        Icons.flutter_dash,
        size: 34,
        color: colors.primary,
      ),
    );
  }

  Widget _metricChip(ColorScheme colors, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: colors.onSurface,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildRecognitionResult(
    ThemeData theme,
    ColorScheme colors,
  ) {
    final result = recordingResult!;
    final status = _valueAsString(result['status'], fallback: 'unknown');
    final identifications = result['identifications'] is List
        ? result['identifications'] as List
        : const [];

    //final isCompleted = status == 'completed';
    final isNoMatch = status == 'no_match';

    return Card(
      color: colors.surface.withValues(alpha: 0.88),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAudioPlayer(theme, colors),
            const SizedBox(height: 14),
            if (identifications.isNotEmpty) ...[
              ...identifications.map((item) {
                final identification = item is Map
                    ? Map<String, dynamic>.from(item)
                    : <String, dynamic>{};
                return _buildIdentificationCard(
                  identification,
                  theme,
                  colors,
                );
              }),
            ] else if (isNoMatch) ...[
              Row(
                children: [
                  Icon(Icons.search_off, color: colors.error),
                  const SizedBox(width: 10),
                  Text(
                    'No birds detected',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'The model did not find a bird species in this recording. '
                'Try recording again in a quieter place, closer to the sound.',
              ),
            ] else if (status == 'completed') ...[
              const Text(
                'The recording was processed, but no matching species '
                'were returned from the bird catalog.',
              ),
            ] else ...[
              Row(
                children: [
                  Icon(Icons.error_outline, color: colors.error),
                  const SizedBox(width: 10),
                  Text(
                    'Recognition failed',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'The recording was uploaded, but recognition did not '
                'finish successfully. You can try again.',
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: tryAgain,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    stopwatch.stop();
    recorder.dispose();
    audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Stack(
      children: [
        // Keep the same blurred gradient background as the Library tab.
        Positioned.fill(
          child: IgnorePointer(
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? const [
                              Color(0xFF1E2158),
                              Color(0xFF30266B),
                              Color(0xFF171638),
                            ]
                          : const [
                              Color(0xFFE2E5FB),
                              Color(0xFFC8C9F0),
                              Color(0xFFF3F0FF),
                            ],
                    ),
                  ),
                ),
                Positioned(
                  top: -100,
                  right: -80,
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? const Color(0xFF777FC1).withValues(alpha: 0.55)
                            : const Color(0xFF929CEB).withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 100,
                  left: -100,
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                    child: Container(
                      width: 350,
                      height: 350,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? const Color(0xFF514078).withValues(alpha: 0.6)
                            : const Color(0xFFC0C7F6).withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 35,
          right: 25,
          child: IgnorePointer(
            child: Icon(
              Icons.flutter_dash,
              size: 170,
              color: colorScheme.primary.withValues(alpha: 0.045),
            ),
          ),
        ),
        Positioned(
          bottom: 80,
          left: 10,
          child: IgnorePointer(
            child: Icon(
              Icons.eco_outlined,
              size: 130,
              color: colorScheme.primary.withValues(alpha: 0.04),
            ),
          ),
        ),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (recordingResult == null) ...[
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 176,
                      height: 176,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isRecording
                              ? colorScheme.error
                              : colorScheme.primary.withValues(alpha: 0.65),
                          width: 3,
                        ),
                        color: colorScheme.surface.withValues(alpha: 0.35),
                        boxShadow: [
                          BoxShadow(
                            color: (isRecording
                                    ? colorScheme.error
                                    : colorScheme.primary)
                                .withValues(alpha: 0.12),
                            blurRadius: 28,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(
                        isRecording ? Icons.mic : Icons.graphic_eq,
                        size: 64,
                        color: isRecording
                            ? colorScheme.error
                            : colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      formatDuration(duration),
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isRecording
                          ? 'Recording bird sounds... '
                              '${formatDuration(remainingDuration)} remaining'
                          : 'Maximum recording time: '
                              '${formatDuration(maxRecordingDuration)}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.textTheme.bodyMedium?.color
                            ?.withValues(alpha: 0.75),
                      ),
                    ),
                    if (isRecording) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: 220,
                        child: LinearProgressIndicator(
                          value: duration.inMilliseconds /
                              maxRecordingDuration.inMilliseconds,
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    SizedBox(
                      width: 220,
                      child: OutlinedButton.icon(
                        onPressed: isUploading || isStopping
                            ? null
                            : isRecording
                                ? stopRecording
                                : startRecording,
                        icon: Icon(isRecording ? Icons.stop : Icons.mic),
                        label: Text(
                          isRecording ? 'Stop recording' : 'Start recording',
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    if (recordedPath != null && !isRecording) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: 220,
                        child: FilledButton.icon(
                          onPressed: isUploading ? null : uploadRecording,
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('Recognize bird'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                        ),
                      ),
                    ],
                    if (isUploading) ...[
                      const SizedBox(height: 24),
                      const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      const Text('Uploading and analyzing audio...'),
                    ],
                    ],
                    if (recordingResult != null) ...[
                      _buildRecognitionResult(theme, colorScheme),
                    ],
                    if (errorMessage != null) ...[
                      const SizedBox(height: 24),
                      Card(
                        color: colorScheme.errorContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: colorScheme.error,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  errorMessage!,
                                  style: TextStyle(
                                    color: colorScheme.onErrorContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
