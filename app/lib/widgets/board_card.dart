import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/board.dart';
import '../models/board_data_record.dart';
import '../services/api_service.dart';
import '../services/data_aggregator.dart';
import '../utils/mac_address_formatter.dart';
import '../screens/details_screen.dart';

class BoardCard extends StatefulWidget {
  final Board board;

  const BoardCard({Key? key, required this.board}) : super(key: key);

  @override
  State<BoardCard> createState() => _BoardCardState();
}

class _BoardCardState extends State<BoardCard> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  double _currentCrowd = 0;
  List<BoardDataRecord> _recentRecords = [];
  DateTime? _graphStart;
  DateTime? _graphEnd;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final now = DateTime.now();
      // Fetch data for the last 2 hours for the mini graph and current level
      final start = now.subtract(const Duration(hours: 2));
      final records = await _apiService.getBoardData(
        widget.board.boardMac,
        start: start,
        end: now,
      );

      final current = DataAggregator.getCurrentCrowdLevel(records, now);

      if (mounted) {
        setState(() {
          _recentRecords = records;
          _currentCrowd = current;
          _graphStart = start;
          _graphEnd = now;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.board.name.isNotEmpty 
        ? widget.board.name 
        : MacAddressFormatter.format(widget.board.boardMac);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailsScreen(board: widget.board),
          ),
        ).then((_) => _loadData()); // Reload when coming back
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              displayName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _currentCrowd.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 4, left: 8),
                    child: Text(
                      'Clients (Last 15m)',
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            if (!_isLoading && _recentRecords.isNotEmpty)
              SizedBox(
                height: 40,
                child: _buildMiniGraph(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniGraph() {
    if (_graphStart == null || _graphEnd == null) return const SizedBox.shrink();
    final buckets = DataAggregator.aggregateToFixed15MinBuckets(_recentRecords, _graphStart!, _graphEnd!);
    if (buckets.isEmpty) return const SizedBox.shrink();

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: buckets.asMap().entries.map((e) {
              return FlSpot(e.key.toDouble(), e.value.averageClients);
            }).toList(),
            isCurved: true,
            color: Colors.blue.shade300,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blue.shade300.withOpacity(0.2),
            ),
          ),
        ],
      ),
    );
  }
}
