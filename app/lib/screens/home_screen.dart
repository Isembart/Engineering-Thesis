import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/board.dart';
import '../models/hour_prediction.dart';
import '../services/api_service.dart';
import '../services/data_aggregator.dart';
import '../theme.dart';
import '../widgets/board_card.dart';
import 'details_screen.dart';
import 'settings_screen.dart';

typedef _Entry = ({Board board, double? current, HourPrediction? prediction});

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
  DateTime _loadedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
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
    return (board: board, current: count, prediction: predictions.firstOrNull);
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final boards = await _apiService.getBoards();
      final entries = await Future.wait(boards.map(_loadEntry));
      if (!mounted) return;
      setState(() {
        // Offline places sink to the bottom, otherwise keep the server's order.
        _entries = [...entries.where((e) => e.current != null), ...entries.where((e) => e.current == null)];
        _loadedAt = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Nie udało się połączyć z serwerem.');
    }
  }

  Future<void> _openSettings() async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
    if (changed == true) {
      setState(() => _entries = null);
      _load();
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
    final day = DateFormat('EEEE, HH:mm').format(_loadedAt);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            children: [
              Row(
                children: [
                  Expanded(child: Text(day[0].toUpperCase() + day.substring(1), style: heading(28))),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    tooltip: 'Ustawienia',
                    onPressed: _openSettings,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _buildContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_error != null) {
      return _Message(
        key: const ValueKey('error'),
        text: _error!,
        action: ElevatedButton(onPressed: _load, child: const Text('Spróbuj ponownie')),
      );
    }
    final entries = _entries;
    if (entries == null) {
      return Column(
        key: const ValueKey('loading'),
        children: [
          for (var i = 0; i < 3; i++) ...[
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              decoration: panelDecoration(),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [Skeleton(height: 20, width: 150), Spacer(), Skeleton(height: 30, width: 110)]),
                  SizedBox(height: 6),
                  Skeleton(height: 16, width: 220),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      );
    }
    if (entries.isEmpty) {
      return const _Message(key: ValueKey('empty'), text: 'Na tym serwerze nie ma jeszcze żadnych miejsc.');
    }
    return Column(
      key: const ValueKey('list'),
      children: [
        for (final e in entries) ...[
          BoardCard(
            board: e.board,
            current: e.current,
            prediction: e.prediction,
            onTap: () => _openDetails(e.board),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _Message extends StatelessWidget {
  final String text;
  final Widget? action;

  const _Message({super.key, required this.text, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: archivo(18, weight: FontWeight.w600)),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}
