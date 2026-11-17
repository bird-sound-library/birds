// Unit tests for parsing backend JSON into app models.
// They don't need a running backend or database, so they can run in CI.

import 'package:flutter_test/flutter_test.dart';

import 'package:birds/models/bird.dart';

void main() {
  group('Bird.fromJson', () {
    test('parses main fields and nested sounds', () {
      final bird = Bird.fromJson({
        'bird_id': 1,
        'common_name': 'House Sparrow',
        'scientific_name': 'Passer domesticus',
        'image_url': 'https://example.com/sparrow.jpg',
        'sounds': [
          {
            'sound_id': 10,
            'title': 'Song',
            'file_url': 'https://example.com/song.mp3',
            'duration': 12,
          },
        ],
      });

      expect(bird.birdId, 1);
      expect(bird.commonName, 'House Sparrow');
      expect(bird.scientificName, 'Passer domesticus');
      expect(bird.sounds, hasLength(1));
      expect(bird.sounds.first.soundId, 10);
      expect(bird.sounds.first.fileUrl, 'https://example.com/song.mp3');
      expect(bird.sounds.first.duration, 12);
    });

    test('handles missing optional fields', () {
      final bird = Bird.fromJson({'bird_id': 2});

      expect(bird.birdId, 2);
      expect(bird.commonName, isNull);
      expect(bird.description, isNull);
      expect(bird.categories, isEmpty);
      expect(bird.sounds, isEmpty);
    });
  });
}