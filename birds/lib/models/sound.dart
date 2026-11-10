
class Sound {
  final int soundId;
  final String? title;
  final String? fileUrl;
  final String? type;
  final String? source;
  final String? recordist;
  final String? description;
  final int? duration;
  final String? externalId;
  final String? license;
  final String? sourceUrl;

  const Sound({
    required this.soundId,
    this.title,
    this.fileUrl,
    this.type,
    this.source,
    this.recordist,
    this.description,
    this.duration,
    this.externalId,
    this.license,
    this.sourceUrl,
  });

  factory Sound.fromJson(Map<String, dynamic> json) {
    return Sound(
      soundId: json['sound_id'] as int,
      title: json['title'] as String?,
      fileUrl: json['file_url'] as String?,
      type: json['type'] as String?,
      source: json['source'] as String?,
      recordist: json['recordist'] as String?,
      description: json['description'] as String?,
      duration: json['duration'] as int?,
      externalId: json['external_id'] as String?,
      license: json['license'] as String?,
      sourceUrl: json['source_url'] as String?,
    );
  }
}
