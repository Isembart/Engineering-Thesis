import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/board.dart';
import '../models/board_data_record.dart';

class ApiService {
  static const String _defaultUrl = 'http://192.168.1.100:3000';
  static const String _serverUrlKey = 'server_url';

  Future<String> getServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_serverUrlKey) ?? _defaultUrl;
  }

  Future<void> setServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverUrlKey, url);
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

  Future<List<BoardDataRecord>> getBoardData(int macAddress, {DateTime? start, DateTime? end, required int bucketSizeMinutes}) async {
    final baseUrl = await getServerUrl();
    var uri = Uri.parse('$baseUrl/get-board-data').replace(queryParameters: {
      'mac_address': macAddress.toString(),
      if (start != null) 'start': _formatDateTime(start),
      if (end != null) 'end': _formatDateTime(end),
      'bucket_size_minutes': bucketSizeMinutes.toString(),
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
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'mac_address': macAddress,
        'name': newName,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to rename board: ${response.statusCode}');
    }
  }
}
