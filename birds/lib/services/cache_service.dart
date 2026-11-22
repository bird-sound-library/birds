import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Centralized persistent cache for bird images and audio recordings.
class BirdCacheService {
  BirdCacheService._();

  static final BirdCacheService instance = BirdCacheService._();

  static final CacheManager imageCache = CacheManager(
    Config(
      'bird_images',
      stalePeriod: const Duration(days: 365),
      maxNrOfCacheObjects: 500,
    ),
  );

  Future<Directory> _audioDirectory() async {
    final supportDirectory = await getApplicationSupportDirectory();
    final directory = Directory(
      '${supportDirectory.path}${Platform.pathSeparator}bird_audio_cache',
    );

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  /// Returns an existing cached recording or downloads and stores it.
  Future<File> getAudioFile(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const FormatException('Invalid audio URL');
    }

    final directory = await _audioDirectory();
    final extensionMatch =
        RegExp(r'\.([a-zA-Z0-9]{2,5})$').firstMatch(uri.path);
    final extension = extensionMatch?.group(1)?.toLowerCase() ?? 'mp3';
    final filename = '${sha256.convert(url.codeUnits)}.$extension';
    final file = File(
      '${directory.path}${Platform.pathSeparator}$filename',
    );

    if (await file.exists() && await file.length() > 0) {
      return file;
    }

    final temporaryFile = File('${file.path}.part');

    try {
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 90));

      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Audio download failed (HTTP ${response.statusCode})',
          uri: uri,
        );
      }
      if (response.bodyBytes.isEmpty) {
        throw const FormatException('Downloaded audio file is empty');
      }

      await temporaryFile.writeAsBytes(response.bodyBytes, flush: true);
      if (await file.exists()) {
        await file.delete();
      }
      return await temporaryFile.rename(file.path);
    } catch (_) {
      if (await temporaryFile.exists()) {
        await temporaryFile.delete();
      }
      rethrow;
    }
  }

  Future<int> getAudioCacheSize() async {
    final directory = await _audioDirectory();
    var total = 0;

    await for (final entity in directory.list()) {
      if (entity is File && !entity.path.endsWith('.part')) {
        total += await entity.length();
      }
    }
    return total;
  }

  Future<int> getTotalCacheSize() async {
    final audioSize = await getAudioCacheSize();
    final imageSize = await _getDirectorySize(
      await getTemporaryDirectory(),
      'bird_images',
    );
    return audioSize + imageSize;
  }

  Future<int> _getDirectorySize(Directory parent, String name) async {
    // flutter_cache_manager stores its files in the app's temporary cache.
    // The cache database may use a platform-specific directory, so the
    // image cache size is best-effort and the audio size is exact.
    final directory = Directory(
      '${parent.path}${Platform.pathSeparator}$name',
    );
    if (!await directory.exists()) return 0;

    var total = 0;
    await for (final entity in directory.list(recursive: true)) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  Future<void> clearCache() async {
    await imageCache.emptyCache();

    final audioDirectory = await _audioDirectory();
    if (await audioDirectory.exists()) {
      await audioDirectory.delete(recursive: true);
    }
  }

  String formatBytes(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var unit = 0;

    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit++;
    }

    return '${size.toStringAsFixed(unit == 0 ? 0 : 1)} ${units[unit]}';
  }
}
