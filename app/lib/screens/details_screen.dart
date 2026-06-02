import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/board.dart';
import '../models/board_data_record.dart';
import '../services/api_service.dart';
import '../services/data_aggregator.dart';
import '../utils/mac_address_formatter.dart';

enum Timeframe { last3Hours, fullDay }

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
  Timeframe _selectedTimeframe = Timeframe.fullDay;
  DateTime _selectedDate = DateTime.now();
  double _currentClients = 0.0;

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  @override
  void initState() {
    super.initState();
    _boardName = widget.board.name;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
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
          _selectedTimeframe = Timeframe.fullDay;
        }
      });
      _loadData();
    }
  }

  Future<void> _showRenameDialog() async {
    final controller = TextEditingController(text: widget.board.name);
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
          // Update the local state so the UI reflects the new name without requiring a full reload from the list
          setState(() {
            // Note: Since widget.board is final, we create a new one or just rely on a local state variable for the name.
            // A better way is to update a local _boardName variable. Let's create one.
            _boardName = newName;
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

    return Scaffold(
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
            icon: const Icon(Icons.edit, color: Colors.black87),
            onPressed: _showRenameDialog,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
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
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCurrentStatusCard(),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Trends',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
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
                          _selectedTimeframe = Timeframe.fullDay;
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
                                _selectedTimeframe = Timeframe.fullDay;
                              }
                            });
                            _loadData();
                          },
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<Timeframe>(
                    value: _selectedTimeframe,
                    items: [
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
            ],
          ),
          const SizedBox(height: 16),
          _buildChartCard(),
        ],
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

    return Container(
      height: 350,
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 5,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey.shade100,
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: _buckets.length > 20 ? (_buckets.length / 5).floorToDouble() : 1,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= _buckets.length) {
                    return const SizedBox.shrink();
                  }
                  
                  final bucket = _buckets[index];
                  final label = DateFormat('HH:mm').format(bucket.startTime);

                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Transform.rotate(
                      angle: -0.5,
                      child: Text(
                        label,
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (_buckets.length - 1).toDouble(),
          minY: 0,
          lineBarsData: [
            LineChartBarData(
              spots: _buckets.asMap().entries.where((e) {
                final bucket = e.value;
                final now = DateTime.now();
                if (bucket.startTime.isAfter(now)) return false;
                if (bucket.averageClients == 0.0 && bucket.endTime.isAfter(now)) return false;
                return true;
              }).map((e) {
                return FlSpot(e.key.toDouble(), e.value.averageClients);
              }).toList(),
              isCurved: false,
              color: const Color(0xFF3B82F6),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: true, getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 3,
                  color: const Color(0xFF3B82F6),
                  strokeWidth: 1,
                  strokeColor: Colors.white,
                );
              }),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFF3B82F6).withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
