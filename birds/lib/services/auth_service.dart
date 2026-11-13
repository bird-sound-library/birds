import '../config/api_config.dart';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'token_storage.dart';

class AuthService extends ChangeNotifier {
  AuthService._();

  static final AuthService instance = AuthService._();

  static const String baseUrl = ApiConfig.baseUrl;

  final TokenStorage _storage = TokenStorage();

  String? accessToken;
  String? refreshToken;
  Map<String, dynamic>? currentUser;

  bool initialized = false;

  Future<bool>? _refreshFuture;

  bool get isAuthenticated =>
      accessToken != null && currentUser != null;

  Future<void> initialize() async {
  try {
    refreshToken = await _storage.getRefreshToken();

    if (refreshToken != null) {
      final refreshed = await refreshSession();

      if (refreshed) {
        await loadCurrentUser();
      }
    }
  } catch (e) {
    debugPrint('Session initialization failed: $e');
    accessToken = null;
    currentUser = null;
  } finally {
    initialized = true;
    notifyListeners();
  }
}

  Future<void> register(
    String email,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email.trim(),
        'password': password,
      }),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 201) {
      throw Exception(_errorMessage(response));
    }

    await login(email, password);
  }

  Future<void> login(
    String email,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email.trim(),
        'password': password,
      }),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response));
    }

    final data =
        jsonDecode(response.body) as Map<String, dynamic>;

    await _saveTokens(data);

    await loadCurrentUser();

    notifyListeners();
  }

  Future<void> _saveTokens(
    Map<String, dynamic> data,
  ) async {
    accessToken = data['access_token'] as String;
    refreshToken = data['refresh_token'] as String;

    await _storage.saveTokens(
      accessToken: accessToken!,
      refreshToken: refreshToken!,
    );
  }

  Future<bool> refreshSession() {
    if (_refreshFuture != null) {
      return _refreshFuture!;
    }

    final future = _refreshSessionInternal();
    _refreshFuture = future;

    return future.whenComplete(() {
      _refreshFuture = null;
    });
  }

  Future<bool> _refreshSessionInternal() async {
    refreshToken ??= await _storage.getRefreshToken();

    if (refreshToken == null) {
      return false;
    }

    final response = await http.post(
      Uri.parse('$baseUrl/auth/refresh'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'refresh_token': refreshToken,
      }),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 401 ||
      response.statusCode == 403) {
    await _clearSession();
    return false;
  }

  if (response.statusCode != 200) {
    throw Exception(
      'Could not refresh session: HTTP ${response.statusCode}',
    );
  }

    final data =
        jsonDecode(response.body) as Map<String, dynamic>;

    await _saveTokens(data);

    return true;
  }

  Future<void> loadCurrentUser() async {
    if (accessToken == null) {
      throw Exception('Not authenticated');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 401) {
      final refreshed = await refreshSession();

      if (!refreshed) {
        throw Exception('Session expired');
      }

      return loadCurrentUser();
    }

    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response));
    }

    currentUser =
        jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> logout() async {
    final token = refreshToken;

    try {
      if (token != null) {
        await http.post(
          Uri.parse('$baseUrl/auth/logout'),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'refresh_token': token,
          }),
        ).timeout(const Duration(seconds: 15));
      }
    } finally {
      await _clearSession();
      notifyListeners();
    }
  }

  Future<void> _clearSession() async {
    accessToken = null;
    refreshToken = null;
    currentUser = null;

    await _storage.clearTokens();
  }

  String _errorMessage(http.Response response) {
    try {
      final data =
          jsonDecode(response.body) as Map<String, dynamic>;

      return data['detail']?.toString() ??
          'HTTP ${response.statusCode}';
    } catch (_) {
      return 'HTTP ${response.statusCode}: ${response.body}';
    }
  }
}
