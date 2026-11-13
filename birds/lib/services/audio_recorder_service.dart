import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:record/record.dart';

class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();

  Future<bool> get isRecording async {
    return await _recorder.isRecording();
  }

  Future<bool> requestPermission() async {
    return await _recorder.hasPermission();
  }

  Future<void> startRecording() async {
    final hasPermission = await requestPermission();

    if (!hasPermission) {
      throw Exception('Microphone permission denied');
    }

    // On web the recorder ignores the path (it records into a blob),
    // but on Windows/desktop it needs a real file path.
    final path = kIsWeb
        ? ''
        : '${Directory.systemTemp.path}${Platform.pathSeparator}'
            'bird_${DateTime.now().millisecondsSinceEpoch}.wav';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 48000,
        numChannels: 1,
      ),
      path: path,
    );
  }

  Future<String?> stopRecording() async {
    return await _recorder.stop();
  }

  Future<void> dispose() async {
    await _recorder.dispose();
  }
}