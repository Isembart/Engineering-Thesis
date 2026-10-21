import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/board.dart';
import '../models/board_data_record.dart';
import '../models/board_settings.dart';

class ApiService {
  static const String _defaultUrl = 'http://192.168.1.100:3000';
  static const String _serverUrlKey = 'server_url';

  Future<String> getServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_serverUrlKey) ?? _defaultUrl;
  }

  Future<void> setServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    // An admin token belongs to one server, never carry it over to another
    if (url != await getServerUrl()) {
      await leaveAdminMode();
    }
    await prefs.setString(_serverUrlKey, url);
  }

  // --- Admin mode ---
  // The app is in admin mode only while it holds a token the current server accepted.
  // Everything else is guest mode: board list and charts, no board settings, no renaming.
  // Screens hide their admin controls based on [isAdmin]; the server enforces the same
  // split, so hiding is only cosmetic.
  static const String _adminTokenKey = 'admin_token';
  static const _secureStorage = FlutterSecureStorage();
  static String? _adminToken;
  static final ValueNotifier<bool> isAdmin = ValueNotifier(false);

  /// Restores a previously accepted token. Call once at startup.
  static Future<void> loadAdminToken() async {
    try {
      _adminToken = await _secureStorage.read(key: _adminTokenKey);
    } catch (_) {
      // No usable keystore (e.g. Linux without a keyring): stay in guest mode
      _adminToken = null;
    }
    isAdmin.value = _adminToken != null;
  }

  /// Checks [token] against the current server and enters admin mode when it is accepted.
  /// Returns false when the server rejects it, throws when the server cannot be asked.
  Future<bool> enterAdminMode(String token) async {
    final baseUrl = await getServerUrl();
    // Any admin-only read works as the check: an unknown MAC answers 404 once the token
    // is accepted and 401 when it is not.
    final uri = Uri.parse('$baseUrl/board-settings').replace(queryParameters: {'mac_address': '0'});
    final response = await http.get(uri, headers: {'Authorization': 'Bearer $token'});

    if (response.statusCode == 401) {
      return false;
    }
    if (response.statusCode != 200 && response.statusCode != 404) {
      throw Exception('Failed to verify the token: ${response.statusCode}');
    }

    _adminToken = token;
    isAdmin.value = true;
    try {
      await _secureStorage.write(key: _adminTokenKey, value: token);
    } catch (_) {
      // Without a keystore the token still works until the app is closed
    }
    return true;
  }

  Future<void> leaveAdminMode() async {
    _adminToken = null;
    isAdmin.value = false;
    try {
      await _secureStorage.delete(key: _adminTokenKey);
    } catch (_) {}
  }

  Map<String, String> _adminHeaders() => {
        'Content-Type': 'application/json',
        if (_adminToken != null) 'Authorization': 'Bearer $_adminToken',
      };

  /// A 401 on an admin request means the token was rotated or revoked: drop it.
  Future<void> _checkAdminResponse(http.Response response) async {
    if (response.statusCode == 401) {
      await leaveAdminMode();
      throw Exception('Admin access is no longer valid');
    }
  }

  Future<List<Board>> getBoards() async {
    final url = await getServerUrl();
    final response = await http.get(Uri.parse('$url/get-all-boards'));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Board.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load boards: ${response.statusCode}');
    }
  }

  String _formatDateTime(DateTime dt) {
    // The backend now expects a timezone-aware DateTime string (RFC 3339).
    // Converting to UTC and using toIso8601String adds the 'Z' which the 
    // backend will successfully parse as DateTime<FixedOffset>.
    return dt.toUtc().toIso8601String();
  }

  Future<List<BoardDataRecord>> getBoardData(int macAddress, {DateTime? start, DateTime? end}) async {
    final baseUrl = await getServerUrl();
    var uri = Uri.parse('$baseUrl/get-board-data').replace(queryParameters: {
      'mac_address': macAddress.toString(),
      if (start != null) 'start': _formatDateTime(start),
      if (end != null) 'end': _formatDateTime(end),
    });

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => BoardDataRecord.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load board data: ${response.statusCode}');
    }
  }

  Future<void> renameBoard(int macAddress, String newName) async {
    final baseUrl = await getServerUrl();
    final url = Uri.parse('$baseUrl/rename-board');
    
    final response = await http.put(
      url,
      headers: _adminHeaders(),
      body: json.encode({
        'mac_address': macAddress,
        'name': newName,
      }),
    );
    await _checkAdminResponse(response);

    if (response.statusCode != 200) {
      throw Exception('Failed to rename board: ${response.statusCode}');
    }
  }

  Future<BoardSettings?> getBoardSettings(int macAddress) async {
    final baseUrl = await getServerUrl();
    final uri = Uri.parse('$baseUrl/board-settings').replace(queryParameters: {
      'mac_address': macAddress.toString(),
    });

    final response = await http.get(uri, headers: _adminHeaders());
    await _checkAdminResponse(response);

    if (response.statusCode == 200) {
      return BoardSettings.fromJson(json.decode(response.body));
    }
    if (response.statusCode == 404) {
      return null;
    }
    throw Exception('Failed to load board settings: ${response.statusCode}');
  }

  /// Also creates the settings when the board has none yet.
  Future<BoardSettings> updateBoardSettings(int macAddress, BoardSettings settings) async {
    final baseUrl = await getServerUrl();
    final uri = Uri.parse('$baseUrl/board-settings').replace(queryParameters: {
      'mac_address': macAddress.toString(),
    });

    final response = await http.put(
      uri,
      headers: _adminHeaders(),
      body: json.encode(settings.toJson()),
    );
    await _checkAdminResponse(response);

    if (response.statusCode == 200) {
      return BoardSettings.fromJson(json.decode(response.body));
    }
    throw Exception('Failed to update board settings: ${response.statusCode}');
  }
}
