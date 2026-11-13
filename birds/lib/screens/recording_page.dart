import 'dart:async';

import 'package:flutter/material.dart';

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

  bool isRecording = false;
  bool isUploading = false;

  String? recordedPath;
  String? resultMessage;
  String? errorMessage;

  final Stopwatch stopwatch = Stopwatch();
  Timer? timer;

  Duration duration = Duration.zero;

  Future<void> startRecording() async {
    try {
      await recorder.startRecording();

      if (!mounted) return;

      setState(() {
        isRecording = true;
        recordedPath = null;
        resultMessage = null;
        errorMessage = null;
        duration = Duration.zero;
      });

      stopwatch
        ..reset()
        ..start();

      timer = Timer.periodic(
        const Duration(seconds: 1),
        (_) {
          if (!mounted) return;

          setState(() {
            duration = stopwatch.elapsed;
          });
        },
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = e.toString();
      });
    }
  }

  Future<void> stopRecording() async {
    try {
      timer?.cancel();
      stopwatch.stop();

      final path = await recorder.stopRecording();

      if (!mounted) return;

      setState(() {
        isRecording = false;
        recordedPath = path;
        duration = stopwatch.elapsed;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isRecording = false;
        errorMessage = e.toString();
      });
    }
  }

  Future<void> uploadRecording() async {
    final path = recordedPath;

    if (path == null) return;

    setState(() {
      isUploading = true;
      errorMessage = null;
      resultMessage = null;
    });

    try {
      final result = await api.uploadRecording(path);

      if (!mounted) return;

      setState(() {
        resultMessage =
            'Recording uploaded successfully!\n'
            'ID: ${result['recording_id']}\n'
            'Status: ${result['status']}';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          isUploading = false;
        });
      }
    }
  }

  String formatDuration(Duration value) {
    final minutes = value.inMinutes;
    final seconds = value.inSeconds.remainder(60);

    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    timer?.cancel();
    stopwatch.stop();
    recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bird Recording'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isRecording ? Icons.mic : Icons.mic_none,
                size: 90,
                color: isRecording ? Theme.of(context).colorScheme.error : null,
              ),

              const SizedBox(height: 20),

              Text(
                formatDuration(duration),
                style: Theme.of(context).textTheme.displayMedium,
              ),

              const SizedBox(height: 24),

              FilledButton.icon(
                onPressed: isUploading
                    ? null
                    : isRecording
                        ? stopRecording
                        : startRecording,
                icon: Icon(
                  isRecording ? Icons.stop : Icons.fiber_manual_record,
                ),
                label: Text(
                  isRecording ? 'Stop recording' : 'Start recording',
                ),
              ),

              const SizedBox(height: 12),

              if (recordedPath != null)
                FilledButton.icon(
                  onPressed: isUploading ? null : uploadRecording,
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text('Upload recording'),
                ),

              if (isUploading) ...[
                const SizedBox(height: 20),
                const CircularProgressIndicator(),
                const Text('Uploading audio...'),
              ],

              if (resultMessage != null) ...[
                const SizedBox(height: 20),
                Text(
                  resultMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],

              if (errorMessage != null) ...[
                const SizedBox(height: 20),
                Text(
                  errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}