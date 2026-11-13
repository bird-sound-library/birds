import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/sound.dart';
import 'auth_service.dart';

import '../models/bird.dart';
import '../config/api_config.dart';

class BirdApi {
  static const String baseUrl = ApiConfig.baseUrl;

  Future<List<Bird>> getBirds() async {
  final response = await http
      .get(Uri.parse('$baseUrl/birds'))
      .timeout(const Duration(seconds: 15));
  if (response.statusCode != 200) {
    throw Exception(
      'Failed to load birds: HTTP ${response.statusCode}',
    );
  }

  final List<dynamic> jsonList =
      jsonDecode(response.body) as List<dynamic>;

  return jsonList
      .map(
        (json) => Bird.fromJson(
          json as Map<String, dynamic>,
        ),
      )
      .toList();
  }

  Future<Bird> getBird(int birdId) async {
    final response = await http
        .get(Uri.parse('$baseUrl/birds/$birdId'))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 404) {
      throw Exception('Bird not found');
    }

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load bird: HTTP ${response.statusCode}',
      );
    }

    return Bird.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

Future<List<Sound>> getBirdSounds(int birdId) async {
  final response = await http
      .get(Uri.parse('$baseUrl/birds/$birdId/sounds'))
      .timeout(const Duration(seconds: 15));

  if (response.statusCode != 200) {
    throw Exception(
      'Failed to load sounds: HTTP ${response.statusCode}',
    );
  }

  final List<dynamic> jsonList = jsonDecode(response.body);

  return jsonList
      .map((json) => Sound.fromJson(json as Map<String, dynamic>))
      .toList();
}


Future<Map<String, dynamic>> uploadRecording(
  String filePath, {
  String? location,
}) async {
  final auth = AuthService.instance;

  if (auth.accessToken == null) {
    throw Exception('Please sign in before uploading a recording');
  }

  Future<http.Response> sendUpload() async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/recordings'),
    );

    request.headers['Authorization'] =
        'Bearer ${auth.accessToken}';

    request.files.add(
      await http.MultipartFile.fromPath('file', filePath),
    );

    if (location != null && location.isNotEmpty) {
      request.fields['location'] = location;
    }

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 60),
    );

    return http.Response.fromStream(streamedResponse);
  }

  var response = await sendUpload();

  if (response.statusCode == 401) {
    final refreshed = await auth.refreshSession();

    if (!refreshed) {
      throw Exception('Session expired. Please sign in again.');
    }

    response = await sendUpload();
  }

  if (response.statusCode != 201) {
    throw Exception(
      'Upload failed (${response.statusCode}): ${response.body}',
    );
  }

  return jsonDecode(response.body) as Map<String, dynamic>;
}
}