
import 'category.dart';
import 'sound.dart';

class Bird {
  final int birdId;
  final String? commonName;
  final String? scientificName;
  final String? wikipediaUrl;
  final String? imageUrl;
  final String? description;

  final List<Category> categories;
  final List<Sound> sounds;

  const Bird({
    required this.birdId,
    this.commonName,
    this.scientificName,
    this.wikipediaUrl,
    this.imageUrl,
    this.description,
    this.categories = const [],
    this.sounds = const [],
  });

  factory Bird.fromJson(Map<String, dynamic> json) {
    return Bird(
      birdId: json['bird_id'] as int,
      commonName: json['common_name'] as String?,
      scientificName: json['scientific_name'] as String?,
      wikipediaUrl: json['wikipedia_url'] as String?,
      imageUrl: json['image_url'] as String?,
      description: json['description'] as String?,

      categories: (json['categories'] as List<dynamic>? ?? [])
          .map((item) => Category.fromJson(
                item as Map<String, dynamic>,
              ))
          .toList(),

      sounds: (json['sounds'] as List<dynamic>? ?? [])
          .map((item) => Sound.fromJson(
                item as Map<String, dynamic>,
              ))
          .toList(),
    );
  }
}
