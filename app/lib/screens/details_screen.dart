import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/board.dart';
import '../models/board_data_record.dart';
import '../models/hour_prediction.dart';
import '../services/api_service.dart';
import '../services/data_aggregator.dart';
import '../utils/mac_address_formatter.dart';
import '../widgets/crowd_comparison_row.dart';
import '../widgets/week_heatmap.dart';
import 'board_settings_screen.dart';

/// Default English localizations, but weeks start on Monday (used by the date picker).
class _MondayFirstLocalizations extends DefaultMaterialLocalizations {
  const _MondayFirstLocalizations();

  @override
  int get firstDayOfWeekIndex => 1;
}

class _MondayFirstDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const _MondayFirstDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      SynchronousFuture(const _MondayFirstLocalizations());

  @override
  bool shouldReload(_MondayFirstDelegate old) => false;
}

enum Timeframe { daytime, fullDay }

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
  /// Prediction for each bucket in [_buckets], keyed by epoch ms.
  Map<int, HourPrediction> _dayPrediction = {};
  /// Today 00:00 + 7 days, for the heatmap and the current-hour comparison.
  List<HourPrediction> _weekPrediction = [];
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

      if (_selectedTimeframe == Timeframe.daytime) {
        start = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 6, 0, 0);
        end = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);
      } else {
        start = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 0, 0, 0);
        end = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);
      }

      final records = await _apiService.getBoardData(
        widget.board.boardMac,
        start: start,
        end: end,
      );

      // Fetch recent records for Current Clients specifically
      final recentStart = now.subtract(const Duration(minutes: 15));
      final recentRecords = await _apiService.getBoardData(
        widget.board.boardMac,
        start: recentStart,
        end: now,
      );
      final currentLevel = DataAggregator.getCurrentCrowdLevel(recentRecords);

      final buckets = DataAggregator.aggregateToFixedBuckets(records, start, end);

      // Predictions are optional: on failure the chart shows only actual data.
      final dayEnd = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day + 1);
      final today = DateTime(now.year, now.month, now.day);
      final mac = widget.board.boardMac;
      final [dayPrediction, weekPrediction] = await Future.wait([
        _apiService.getBoardPrediction(mac, start, dayEnd),
        _apiService.getBoardPrediction(mac, today, DateTime(now.year, now.month, now.day + 7)),
      ].map((f) => f.catchError((_) => <HourPrediction>[])));

      if (mounted) {
        setState(() {
          _records = records;
          _buckets = buckets;
          _dayPrediction = {
            for (final p in dayPrediction) p.timestamp.millisecondsSinceEpoch: p,
          };
          _weekPrediction = weekPrediction;
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
      builder: (context, child) => Localizations.override(
        context: context,
        delegates: const [_MondayFirstDelegate()],
        child: child,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
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
        // Admin controls are not built at all in guest mode
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: ApiService.isAdmin,
            builder: (context, isAdmin, _) {
              if (!isAdmin) return const SizedBox.shrink();
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                    tooltip: 'Rename board',
                    onPressed: _showRenameDialog,
                  ),
                ],
              );
            },
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
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () {
                    setState(() {
                      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                    });
                    _loadData();
                  },
                ),
                TextButton(
                  onPressed: _selectCustomDate,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    _isToday(_selectedDate)
                        ? 'Today, ${DateFormat('EEEE').format(_selectedDate)}'
                        : DateFormat('EEEE, MMM d').format(_selectedDate),
                    style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: _isToday(_selectedDate)
                      ? null
                      : () {
                          setState(() {
                            _selectedDate = _selectedDate.add(const Duration(days: 1));
                          });
                          _loadData();
                        },
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Timeframe>(
                        value: _selectedTimeframe,
                        isDense: true,
                        items: [
                          const DropdownMenuItem(value: Timeframe.daytime, child: Text('6:00-23:00')),
                          const DropdownMenuItem(value: Timeframe.fullDay, child: Text('Full Day')),
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
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildChartCard(),
            const SizedBox(height: 32),
            const Text(
              'Typical week',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            _buildHeatmapCard(),
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
          CrowdComparisonRow(current: _currentClients, prediction: _currentHourPrediction()),
        ],
      ),
    );
  }

  HourPrediction? _currentHourPrediction() {
    final now = DateTime.now();
    final hourStart = DateTime(now.year, now.month, now.day, now.hour);
    return _weekPrediction.where((p) => p.timestamp.isAtSameMomentAs(hourStart)).firstOrNull;
  }

  Widget _buildHeatmapCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: _weekPrediction.isEmpty
          ? const Text('No prediction available.')
          : WeekHeatmap(
              week: _weekPrediction,
              fromHour: _selectedTimeframe == Timeframe.daytime ? 6 : 0,
              toHour: 24,
            ),
    );
  }

  static const _blue = Color(0xFF3B82F6);

  Widget _buildChartCard() {
    final decoration = BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.grey.shade200, width: 1),
    );
    final now = DateTime.now();
    final n = _buckets.length;
    final predictions = [for (final b in _buckets) _dayPrediction[b.startTime.millisecondsSinceEpoch]];
    List<FlSpot> spots(num? Function(int i) y) => [
          for (var i = 0; i < n; i++)
            if (y(i) case final v?) FlSpot(i.toDouble(), v.toDouble()) else FlSpot.nullSpot,
        ];

    // Offline and future hours become gaps in the line.
    final actual = spots((i) => _buckets[i].startTime.isAfter(now) ? null : _buckets[i].averageClients);
    final rangeMax = spots((i) => predictions[i]?.max);
    final rangeMin = spots((i) => predictions[i]?.min);
    final usual = spots((i) => predictions[i]?.mean);

    final values = [...actual, ...rangeMax].where((s) => s.isNotNull()).map((s) => s.y);
    if (values.isEmpty) {
      return Container(
        height: 300,
        alignment: Alignment.center,
        decoration: decoration,
        child: const Text('No data available for the selected timeframe.'),
      );
    }
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final maxY = maxValue <= 0 ? 5.0 : (maxValue * 1.2).ceilToDouble();
    final gridInterval = maxY <= 10 ? 2.0 : (maxY / 5).ceilToDouble();
    final weeks = predictions.map((p) => p?.samples ?? 0).fold(0, (a, b) => b > a ? b : a);
    final labelStyle = TextStyle(color: Colors.grey.shade500, fontSize: 10);

    LineChartBarData line(List<FlSpot> spots, Color color, double width, {List<int>? dash}) =>
        LineChartBarData(
          spots: spots,
          color: color,
          barWidth: width,
          dashArray: dash,
          isCurved: true,
          preventCurveOverShooting: true,
          dotData: const FlDotData(show: false),
        );

    // A lone hour between two gaps has no neighbours to draw a line to, so it gets a dot.
    bool gapAt(int i) => i < 0 || i >= n || actual[i].isNull();
    final actualLine = line(actual, _blue, 2.5).copyWith(
      dotData: FlDotData(
        checkToShowDot: (s, _) => gapAt(s.x.toInt() - 1) && gapAt(s.x.toInt() + 1),
      ),
    );

    final chart = LineChart(
      LineChartData(
        minX: 0,
        maxX: (n - 1).toDouble(),
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: gridInterval,
          getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.shade100, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        // Index 0/1 = typical range edges (invisible, filled between), 2 = usual, 3 = actual.
        lineBarsData: [
          line(rangeMax, Colors.transparent, 0),
          line(rangeMin, Colors.transparent, 0),
          line(usual, _blue.withValues(alpha: 0.6), 1.5, dash: [4, 4]),
          actualLine,
        ],
        betweenBarsData: [
          BetweenBarsData(fromIndex: 0, toIndex: 1, color: _blue.withValues(alpha: 0.15)),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => Colors.black87,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (touched) => touched.map((s) {
              final i = s.x.toInt();
              final p = predictions[i];
              final header = identical(s, touched.first)
                  ? '${DateFormat('EEE HH:mm').format(_buckets[i].startTime)}\n'
                  : '';
              const style = TextStyle(color: Colors.white, fontSize: 12);
              return switch (s.barIndex) {
                0 => LineTooltipItem('${header}Range ${p!.min}–${p.max}', style),
                2 => LineTooltipItem('${header}Usual ~${s.y.toStringAsFixed(1)}', style),
                3 => LineTooltipItem('${header}Actual ${s.y.toStringAsFixed(1)}',
                    style.copyWith(fontWeight: FontWeight.bold)),
                _ => null,
              };
            }).toList(),
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: gridInterval,
              getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: labelStyle),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 2,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= n) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(DateFormat('HH:mm').format(_buckets[index].startTime), style: labelStyle),
                );
              },
            ),
          ),
        ),
      ),
    );

    Widget legend(Widget mark, String text) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [mark, const SizedBox(width: 4), Text(text, style: labelStyle)],
        );

    return Container(
      height: 380,
      padding: const EdgeInsets.fromLTRB(8, 24, 16, 12),
      decoration: decoration,
      child: Column(
        children: [
          Expanded(child: chart),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              legend(Container(width: 14, height: 3, color: _blue), 'Actual'),
              legend(Container(width: 14, height: 2, color: _blue.withValues(alpha: 0.6)), 'Usual'),
              legend(Container(width: 14, height: 10, color: _blue.withValues(alpha: 0.15)), 'Typical range'),
              if (_dayPrediction.isNotEmpty)
                Text(weeks == 0 ? 'No history yet for this day' : 'Based on $weeks of 4 weeks',
                    style: labelStyle),
            ],
          ),
        ],
      ),
    );
  }
}
