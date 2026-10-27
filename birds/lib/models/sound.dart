
class Sound {
  final int soundId;
  final String? title;
  final String? fileUrl;
  final String? type;
  final String? source;
  final int? duration;
  final String? license;
  final String? sourceUrl;

  const Sound({
    required this.soundId,
    this.title,
    this.fileUrl,
    this.type,
    this.source,
    this.duration,
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
      duration: json['duration'] as int?,
      license: json['license'] as String?,
      sourceUrl: json['source_url'] as String?,
    );
  }
}
