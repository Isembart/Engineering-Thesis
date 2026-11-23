import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/board.dart';
import '../models/hour_prediction.dart';
import '../services/api_service.dart';
import '../services/data_aggregator.dart';
import '../widgets/board_card.dart';
import '../widgets/status_block.dart';
import 'details_screen.dart';
import 'settings_screen.dart';

typedef _Entry = ({Board board, double? current, HourPrediction? prediction, List<String> extra});

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  /// Null until the first load finishes.
  List<_Entry>? _entries;
  String? _error;
  bool _isLoading = true;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _load);
    _load();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  /// Last 15 minutes and this hour's prediction. A failed call reads as offline / no history.
  Future<_Entry> _loadEntry(Board board) async {
    final now = DateTime.now();
    final hourStart = DateTime(now.year, now.month, now.day, now.hour);
    Future<double?> current() async {
      try {
        final recent = now.subtract(const Duration(minutes: 15));
        return DataAggregator.getCurrentCrowdLevel(
            await _apiService.getBoardData(board.boardMac, start: recent, end: now));
      } catch (_) {
        return null;
      }
    }

    final (count, predictions) = await (
      current(),
      _apiService
          .getBoardPrediction(board.boardMac, hourStart, hourStart.add(const Duration(hours: 1)))
          .catchError((_) => <HourPrediction>[]),
    ).wait;
    return (
      board: board,
      current: count,
      prediction: predictions.firstOrNull,
      extra: [if (count == null) ?await offlineNote(_apiService, board.boardMac, now)],
    );
  }

  Future<void> _load({bool showOverlay = false}) async {
    setState(() {
      if (showOverlay) _isLoading = true;
      _error = null;
    });
    try {
      final boards = await _apiService.getBoards();
      final entries = await Future.wait(boards.map(_loadEntry));
      if (!mounted) return;
      setState(() {
        // Offline places sink to the bottom, otherwise keep the server's order.
        _entries = [...entries.where((e) => e.current != null), ...entries.where((e) => e.current == null)];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Nie udało się połączyć z serwerem.';
        _isLoading = false;
      });
    }
  }

  Future<void> _openSettings() async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
    if (changed == true) {
      setState(() => _entries = null);
      _load(showOverlay: true);
    }
  }

  Future<void> _openDetails(Board board) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => DetailsScreen(board: board)),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('EEEE, d MMM').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Text(date[0].toUpperCase() + date.substring(1)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Odśwież',
            onPressed: () => _load(showOverlay: true),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Ustawienia',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(onRefresh: _load, child: _buildContent()),
          if (_isLoading)
            Container(
              color: Colors.white.withValues(alpha: 0.6),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_error != null) {
      return _message(
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: () => _load(showOverlay: true), child: const Text('Spróbuj ponownie')),
          ],
        ),
      );
    }
    final entries = _entries ?? const <_Entry>[];
    if (_entries != null && entries.isEmpty) {
      return _message(const Center(child: Text('Na tym serwerze nie ma jeszcze żadnych miejsc.')));
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 16, bottom: 32),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final e = entries[index];
        return BoardCard(
          board: e.board,
          current: e.current,
          prediction: e.prediction,
          extra: e.extra,
          onTap: () => _openDetails(e.board),
        );
      },
    );
  }

  /// Centered message that still allows pull to refresh.
  Widget _message(Widget child) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [SizedBox(height: MediaQuery.of(context).size.height * 0.6, child: child)],
      );
}
