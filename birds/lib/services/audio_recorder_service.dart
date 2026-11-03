
import 'dart:io';

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

    final directory = Directory.systemTemp;
    final path =
        '${directory.path}${Platform.pathSeparator}'
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
