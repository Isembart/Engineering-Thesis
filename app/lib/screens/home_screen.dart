import 'package:flutter/material.dart';
import '../models/board.dart';
import '../services/api_service.dart';
import '../widgets/board_card.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  List<Board> _boards = [];
  bool _isLoading = true;
  String? _error;
  DateTime _lastRefresh = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadBoards();
  }

  Future<void> _loadBoards() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final boards = await _apiService.getBoards();
      if (mounted) {
        setState(() {
          _boards = boards;
          _isLoading = false;
          _lastRefresh = DateTime.now(); // Update timestamp to force child refresh
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load boards. Please check server settings.';
          _isLoading = false;
        });
      }
    }
  }

  void _openSettings() async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
    if (changed == true) {
      _loadBoards();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Crowdness Tracker',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: _loadBoards,
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black87),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadBoards,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    Widget content;
    if (_boards.isEmpty && !_isLoading) {
      content = const Center(child: Text('No boards found.'));
    } else {
      content = ListView.builder(
        padding: const EdgeInsets.only(top: 16, bottom: 32),
        itemCount: _boards.length,
        itemBuilder: (context, index) {
          return BoardCard(
            key: ValueKey('${_boards[index].boardMac}_${_lastRefresh.millisecondsSinceEpoch}'),
            board: _boards[index],
          );
        },
      );
    }

    return Stack(
      children: [
        content,
        if (_isLoading)
          Container(
            color: Colors.white.withOpacity(0.6), // Dim the background slightly
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }
}
