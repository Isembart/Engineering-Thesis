import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/board.dart';
import '../models/board_data_record.dart';
import '../services/api_service.dart';
import '../services/data_aggregator.dart';
import '../utils/mac_address_formatter.dart';

enum Timeframe { last3Hours, last24Hours, last7Days, customDate }

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
  Timeframe _selectedTimeframe = Timeframe.last24Hours;
  int _selectedBucketSize = 15;
  DateTime? _customDate;

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

      switch (_selectedTimeframe) {
        case Timeframe.last3Hours:
          end = now;
          start = now.subtract(const Duration(hours: 3));
          break;
        case Timeframe.last24Hours:
          end = now;
          start = now.subtract(const Duration(hours: 24));
          break;
        case Timeframe.last7Days:
          end = now;
          start = now.subtract(const Duration(days: 7));
          break;
        case Timeframe.customDate:
          final selected = _customDate ?? now;
          start = DateTime(selected.year, selected.month, selected.day, 0, 0, 0);
          end = DateTime(selected.year, selected.month, selected.day, 23, 59, 59);
          break;
      }

      final records = await _apiService.getBoardData(
        widget.board.boardMac,
        start: start,
        end: end,
        bucketSizeMinutes: _selectedBucketSize,
      );

      final buckets = DataAggregator.aggregateToFixedBuckets(records, start, end, _selectedBucketSize);

      if (mounted) {
        setState(() {
          _records = records;
          _buckets = buckets;
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
      initialDate: _customDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedTimeframe = Timeframe.customDate;
        _customDate = picked;
      });
      _loadData();
    }
  }

  String _getTrendsTitle() {
    switch (_selectedTimeframe) {
      case Timeframe.last3Hours:
        return 'Trends (Last 3h)';
      case Timeframe.last24Hours:
        return 'Trends (Last 24h)';
      case Timeframe.last7Days:
        return 'Trends (7 Days)';
      case Timeframe.customDate:
        if (_customDate != null) {
          return 'Trends (${DateFormat('MMM d, y').format(_customDate!)})';
        }
        return 'Trends (Custom)';
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
              Text(
                _getTrendsTitle(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Row(
                children: [
                  DropdownButton<int>(
                    value: _selectedBucketSize,
                    items: const [
                      DropdownMenuItem(value: 15, child: Text('15m')),
                      DropdownMenuItem(value: 30, child: Text('30m')),
                      DropdownMenuItem(value: 60, child: Text('1h')),
                      DropdownMenuItem(value: 240, child: Text('4h')),
                      DropdownMenuItem(value: 1440, child: Text('1d')),
                      DropdownMenuItem(value: 10080, child: Text('1w')),
                    ],
                    onChanged: (int? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedBucketSize = newValue;
                        });
                        _loadData();
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<Timeframe>(
                    value: _selectedTimeframe,
                    items: const [
                      DropdownMenuItem(value: Timeframe.last3Hours, child: Text('Last 3h')),
                      DropdownMenuItem(value: Timeframe.last24Hours, child: Text('Last 24h')),
                      DropdownMenuItem(value: Timeframe.last7Days, child: Text('7 Days')),
                      DropdownMenuItem(value: Timeframe.customDate, child: Text('Custom')),
                    ],
                    onChanged: (Timeframe? newValue) {
                      if (newValue == null) return;
                      if (newValue == Timeframe.customDate) {
                        _selectCustomDate();
                      } else {
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
    final currentLevel = DataAggregator.getCurrentCrowdLevel(_records, DateTime.now());
    
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
                currentLevel.toStringAsFixed(1),
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
                  String label;
                  if (_selectedTimeframe == Timeframe.last7Days) {
                    label = DateFormat('MM-dd HH:mm').format(bucket.startTime);
                  } else {
                    label = DateFormat('HH:mm').format(bucket.startTime);
                  }

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
              spots: _buckets.asMap().entries.map((e) {
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
