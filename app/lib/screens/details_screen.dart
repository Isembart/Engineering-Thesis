import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/board.dart';
import '../models/board_data_record.dart';
import '../services/api_service.dart';
import '../services/data_aggregator.dart';
import '../utils/mac_address_formatter.dart';
import 'board_settings_screen.dart';

enum Timeframe { last3Hours, daytime, fullDay }

class DetailsScreen extends StatefulWidget {
  final Board board;

  const DetailsScreen({Key? key, required this.board}) : super(key: key);

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String? _error;
  List<BoardDataRecord> _records = [];
  List<AggregatedBucket> _buckets = [];
  late String _boardName;
  bool _boardsChanged = false;
  Timeframe _selectedTimeframe = Timeframe.daytime;
  DateTime _selectedDate = DateTime.now();
  double _currentClients = 0.0;

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  @override
  void initState() {
    super.initState();
    _boardName = widget.board.name ?? '';
    _loadData();
  }

  Future<void> _loadData({bool showOverlay = true}) async {
    setState(() {
      if (showOverlay) _isLoading = true;
      _error = null;
    });

    try {
      final now = DateTime.now();
      DateTime start;
      DateTime end;
      int bucketSizeMinutes;

      if (_selectedTimeframe == Timeframe.last3Hours && _isToday(_selectedDate)) {
        end = now;
        start = now.subtract(const Duration(hours: 3));
        bucketSizeMinutes = 15;
      } else if (_selectedTimeframe == Timeframe.daytime) {
        start = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 6, 0, 0);
        end = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);
        bucketSizeMinutes = 60;
      } else {
        start = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 0, 0, 0);
        end = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);
        bucketSizeMinutes = 60;
      }

      final records = await _apiService.getBoardData(
        widget.board.boardMac,
        start: start,
        end: end,
        bucketSizeMinutes: bucketSizeMinutes,
      );

      // Fetch recent records for Current Clients specifically
      final recentStart = now.subtract(const Duration(minutes: 15));
      final recentRecords = await _apiService.getBoardData(
        widget.board.boardMac,
        start: recentStart,
        end: now,
        bucketSizeMinutes: 1,
      );
      final currentLevel = DataAggregator.getCurrentCrowdLevel(recentRecords, now);

      final buckets = DataAggregator.aggregateToFixedBuckets(records, start, end, bucketSizeMinutes);

      if (mounted) {
        setState(() {
          _records = records;
          _buckets = buckets;
          _currentClients = currentLevel;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load detailed data.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refresh() => _loadData(showOverlay: false);

  Future<void> _selectCustomDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        if (!_isToday(_selectedDate) && _selectedTimeframe == Timeframe.last3Hours) {
          _selectedTimeframe = Timeframe.daytime;
        }
      });
      _loadData();
    }
  }

  Future<void> _showRenameDialog() async {
    final controller = TextEditingController(text: _boardName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename Board'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Enter new name'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (newName != null) {
      try {
        await _apiService.renameBoard(widget.board.boardMac, newName);
        if (mounted) {
          setState(() {
            _boardName = newName;
            _boardsChanged = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Board renamed successfully')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error renaming board: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _boardName.isNotEmpty 
        ? _boardName 
        : MacAddressFormatter.format(widget.board.boardMac);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_boardsChanged);
      },
      child: Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(
          displayName,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune, color: Colors.black87),
            tooltip: 'Board settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BoardSettingsScreen(board: widget.board),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.black87),
            onPressed: _showRenameDialog,
          ),
        ],
      ),
      body: _buildBody(),
    ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadData,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCurrentStatusCard(),
            const SizedBox(height: 32),
            const Text(
              'Trends',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    setState(() {
                      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                      if (!_isToday(_selectedDate) && _selectedTimeframe == Timeframe.last3Hours) {
                        _selectedTimeframe = Timeframe.daytime;
                      }
                    });
                    _loadData();
                  },
                ),
                TextButton(
                  onPressed: _selectCustomDate,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: Size.zero,
                  ),
                  child: Text(
                    _isToday(_selectedDate) ? 'Today' : DateFormat('MMM d').format(_selectedDate),
                    style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _isToday(_selectedDate)
                      ? null
                      : () {
                          setState(() {
                            _selectedDate = _selectedDate.add(const Duration(days: 1));
                            if (!_isToday(_selectedDate) && _selectedTimeframe == Timeframe.last3Hours) {
                              _selectedTimeframe = Timeframe.daytime;
                            }
                          });
                          _loadData();
                        },
                ),
                const Spacer(),
                DropdownButton<Timeframe>(
                  value: _selectedTimeframe,
                  underline: const SizedBox.shrink(),
                  items: [
                    const DropdownMenuItem(value: Timeframe.daytime, child: Text('6:00 – 23:00')),
                    const DropdownMenuItem(value: Timeframe.fullDay, child: Text('Full Day')),
                    if (_isToday(_selectedDate))
                      const DropdownMenuItem(value: Timeframe.last3Hours, child: Text('Last 3h')),
                  ],
                  onChanged: (Timeframe? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedTimeframe = newValue;
                      });
                      _loadData();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildChartCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Current Clients',
            style: TextStyle(
              fontSize: 16,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _currentClients.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard() {
    if (_buckets.isEmpty) {
      return Container(
        height: 300,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200, width: 1),
        ),
        child: const Text('No data available for the selected timeframe.'),
      );
    }

    final now = DateTime.now();
    final maxClients = _buckets
        .map((b) => b.averageClients)
        .fold<double>(0, (prev, v) => v > prev ? v : prev);
    final maxY = maxClients <= 0 ? 5.0 : (maxClients * 1.2).ceilToDouble();

    // Label every 2 hours for day views, every ~4 buckets for shorter ranges.
    final isHourly = _selectedTimeframe != Timeframe.last3Hours;
    final labelEvery = isHourly ? 2 : 4;

    return Container(
      height: 350,
      padding: const EdgeInsets.fromLTRB(8, 24, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          minY: 0,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY <= 10 ? 2 : 5,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey.shade100,
                strokeWidth: 1,
              );
            },
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= _buckets.length) {
                    return const SizedBox.shrink();
                  }
                  if (index % labelEvery != 0) {
                    return const SizedBox.shrink();
                  }

                  final bucket = _buckets[index];
                  final label = DateFormat(
                    isHourly ? 'HH' : 'HH:mm',
                  ).format(bucket.startTime);

                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 10,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          barGroups: _buckets.asMap().entries.map((entry) {
            final index = entry.key;
            final bucket = entry.value;
            final isFuture = bucket.startTime.isAfter(now);

            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: isFuture ? 0 : bucket.averageClients,
                  color: isFuture || bucket.averageClients <= 0
                      ? Colors.transparent
                      : const Color(0xFF3B82F6),
                  width: isHourly ? 8 : 10,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
