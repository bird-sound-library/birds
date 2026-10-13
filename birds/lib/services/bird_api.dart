import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../models/bird.dart';

class BirdApi {
  static const String baseUrl = 'http://127.0.0.1:8000';

  Future<List<Bird>> getBirds() async {
    final response = await http
        .get(Uri.parse('$baseUrl/birds'))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load birds: HTTP ${response.statusCode}',
      );
    }

    final List<dynamic> jsonList = jsonDecode(response.body);

    return jsonList
        .map((json) => Bird.fromJson(json as Map<String, dynamic>))
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
}