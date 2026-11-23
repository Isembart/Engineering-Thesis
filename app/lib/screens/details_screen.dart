import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/board.dart';
import '../models/hour_prediction.dart';
import '../services/api_service.dart';
import '../services/data_aggregator.dart';
import '../widgets/board_card.dart';
import '../widgets/crowd_comparison_row.dart';
import '../widgets/status_block.dart';
import '../widgets/week_heatmap.dart';
import 'board_settings_screen.dart';

enum Timeframe { daytime, fullDay }

class DetailsScreen extends StatefulWidget {
  final Board board;

  const DetailsScreen({super.key, required this.board});

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  final ApiService _apiService = ApiService();
  /// True only until the first load finishes; later loads keep the old content on screen.
  bool _isLoading = true;
  /// A later load (other day, other timeframe, pull to refresh) is running.
  bool _isBusy = false;
  String? _error;
  List<AggregatedBucket> _buckets = [];
  /// Prediction for each bucket in [_buckets], keyed by epoch ms.
  Map<int, HourPrediction> _dayPrediction = {};
  /// Today 00:00 + 7 days, for the heatmap and the current-hour comparison.
  List<HourPrediction> _weekPrediction = [];
  late String _boardName;
  bool _boardsChanged = false;
  Timeframe _selectedTimeframe = Timeframe.daytime;
  DateTime _selectedDate = DateTime.now();
  /// Null means offline.
  double? _currentClients;
  /// Last reading, shown only while offline.
  String? _offlineNote;
  late final AppLifecycleListener _lifecycle;

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  @override
  void initState() {
    super.initState();
    _boardName = widget.board.name ?? '';
    _lifecycle = AppLifecycleListener(onResume: _loadData);
    _loadData();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isBusy = true;
      _error = null;
    });

    try {
      final now = DateTime.now();
      final d = _selectedDate;
      final start = DateTime(d.year, d.month, d.day, _selectedTimeframe == Timeframe.daytime ? 6 : 0);
      final end = DateTime(d.year, d.month, d.day, 23, 59, 59);

      final dayEnd = DateTime(d.year, d.month, d.day + 1);
      final today = DateTime(now.year, now.month, now.day);
      final mac = widget.board.boardMac;
      // Predictions are optional: on failure the chart shows only actual data.
      final (records, recentRecords, dayPrediction, weekPrediction) = await (
        _apiService.getBoardData(mac, start: start, end: end),
        _apiService.getBoardData(mac, start: now.subtract(const Duration(minutes: 15)), end: now),
        _apiService.getBoardPrediction(mac, start, dayEnd).catchError((_) => <HourPrediction>[]),
        _apiService
            .getBoardPrediction(mac, today, DateTime(now.year, now.month, now.day + 7))
            .catchError((_) => <HourPrediction>[]),
      ).wait;
      final current = DataAggregator.getCurrentCrowdLevel(recentRecords);
      final offline = current == null ? await offlineNote(_apiService, mac, now) : null;

      if (!mounted) return;
      setState(() {
        _buckets = DataAggregator.aggregateToFixedBuckets(records, start, end);
        _dayPrediction = {for (final p in dayPrediction) p.timestamp.millisecondsSinceEpoch: p};
        _weekPrediction = weekPrediction;
        _currentClients = current;
        _offlineNote = offline;
        _isLoading = false;
        _isBusy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Nie udało się pobrać danych tego miejsca.';
        _isLoading = false;
        _isBusy = false;
      });
    }
  }

  /// Calendar day, not 24 h, so DST changes do not skip or repeat a day.
  DateTime _shiftDay(int days) => DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day + days);

  void _showDate(DateTime date) {
    setState(() => _selectedDate = date);
    _loadData();
  }

  Future<void> _selectCustomDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) _showDate(picked);
  }

  Future<void> _showRenameDialog() async {
    final controller = TextEditingController(text: _boardName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Zmień nazwę'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Nazwa miejsca'),
          autofocus: true,
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Anuluj')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newName == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await _apiService.renameBoard(widget.board.boardMac, newName);
      if (!mounted) return;
      setState(() {
        _boardName = newName;
        _boardsChanged = true;
      });
      messenger.showSnackBar(const SnackBar(content: Text('Zmieniono nazwę')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Nie udało się zmienić nazwy')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_boardsChanged);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(boardDisplayName(widget.board, _boardName)),
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
                      icon: const Icon(Icons.tune),
                      tooltip: 'Ustawienia czujnika',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => BoardSettingsScreen(board: widget.board)),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: 'Zmień nazwę',
                      onPressed: _showRenameDialog,
                    ),
                  ],
                );
              },
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(2),
            child: _isBusy && !_isLoading
                ? const LinearProgressIndicator(minHeight: 2)
                : const SizedBox(height: 2),
          ),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return RefreshIndicator(
        onRefresh: _loadData,
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
                  ElevatedButton(onPressed: _loadData, child: const Text('Spróbuj ponownie')),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final day = DateFormat('EEEE').format(_selectedDate);
    final dateLabel = _isToday(_selectedDate)
        ? 'Dziś, $day'
        : DateFormat('EEEE, d MMM').format(_selectedDate);
    const sectionTitle = TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87);

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCurrentStatusCard(),
            const SizedBox(height: 32),
            const Text('Trendy', style: sectionTitle),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        tooltip: 'Poprzedni dzień',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        onPressed: () => _showDate(_shiftDay(-1)),
                      ),
                      Flexible(
                        child: TextButton(
                          onPressed: _selectCustomDate,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            dateLabel[0].toUpperCase() + dateLabel.substring(1),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        tooltip: 'Następny dzień',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        onPressed: _isToday(_selectedDate) ? null : () => _showDate(_shiftDay(1)),
                      ),
                    ],
                  ),
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<Timeframe>(
                    value: _selectedTimeframe,
                    isDense: true,
                    items: const [
                      DropdownMenuItem(value: Timeframe.daytime, child: Text('6:00-23:00')),
                      DropdownMenuItem(value: Timeframe.fullDay, child: Text('Cała doba')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedTimeframe = value);
                      _loadData();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildChartCard(),
            const SizedBox(height: 32),
            const Text('Typowy tydzień', style: sectionTitle),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: _cardDecoration,
              child: _weekPrediction.isEmpty
                  ? const Text('Brak prognozy dla tego miejsca.')
                  : WeekHeatmap(
                      week: _weekPrediction,
                      fromHour: _selectedTimeframe == Timeframe.daytime ? 6 : 0,
                      toHour: 24,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static final _cardDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: Colors.grey.shade200, width: 1),
  );
  static const _blue = Color(0xFF3B82F6);

  Widget _buildCurrentStatusCard() {
    final current = _currentClients;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Teraz',
            style: TextStyle(fontSize: 16, color: Colors.black54, fontWeight: FontWeight.w500),
          ),
          if (current != null) ...[
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                countText(current),
                style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ),
          ],
          CrowdComparisonRow(current: current, prediction: _currentHourPrediction(), extra: _hints()),
        ],
      ),
    );
  }

  HourPrediction? _hourPrediction(DateTime hourStart) =>
      _weekPrediction.where((p) => p.timestamp.isAtSameMomentAs(hourStart)).firstOrNull;

  HourPrediction? _currentHourPrediction() {
    final now = DateTime.now();
    return _hourPrediction(DateTime(now.year, now.month, now.day, now.hour));
  }

  /// Lines under the status: last reading when offline, otherwise the next-hour trend
  /// and today's quietest upcoming hour.
  List<String> _hints() {
    if (_currentClients == null) return [?_offlineNote];
    final now = DateTime.now();
    final hourStart = DateTime(now.year, now.month, now.day, now.hour);
    final trend = DataAggregator.trend(_hourPrediction(hourStart), _hourPrediction(hourStart.add(const Duration(hours: 1))));
    final quiet = DataAggregator.quietestHour(_weekPrediction, now,
        fromHour: _selectedTimeframe == Timeframe.daytime ? 6 : 0);
    return [
      if (trend == CrowdComparison.busier) 'zwykle zaraz robi się tłoczniej',
      if (trend == CrowdComparison.quieter) 'zwykle zaraz robi się luźniej',
      if (quiet != null)
        'najluźniej dziś ok. ${DateFormat('H:00').format(quiet.timestamp)} (zwykle ${countText(quiet.mean!)})',
    ];
  }

  /// Y axis top and grid step, on round numbers so the top label sits on a grid line.
  static (double, double) _yScale(double maxValue) {
    final raw = maxValue <= 0 ? 4.0 : maxValue * 1.15;
    final step = const [1, 2, 5, 10, 20, 25, 50, 100, 200, 500]
        .firstWhere((s) => raw / s <= 5, orElse: () => 1000)
        .toDouble();
    return ((raw / step).ceil() * step, step);
  }

  Widget _buildChartCard() {
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
        decoration: _cardDecoration,
        child: const Text('Brak danych dla tego dnia.'),
      );
    }
    final (maxY, step) = _yScale(values.reduce((a, b) => a > b ? a : b));
    final weeks = predictions.map((p) => p?.samples ?? 0).fold(0, (a, b) => b > a ? b : a);
    final label = TextStyle(color: Colors.grey.shade500, fontSize: 10);

    // Where "now" falls, in bucket units; null when it is not on this chart.
    final nowIndex = _buckets.indexWhere((b) => !now.isBefore(b.startTime) && now.isBefore(b.endTime));
    final nowX = nowIndex < 0 ? null : nowIndex + now.minute / 60;

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
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      LineChartData(
        minX: 0,
        maxX: (n - 1).toDouble(),
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: step,
          getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.shade100, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        extraLinesData: ExtraLinesData(
          verticalLines: [
            if (nowX != null)
              VerticalLine(
                x: nowX,
                color: Colors.grey.shade500,
                strokeWidth: 1,
                dashArray: [3, 3],
                label: VerticalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 10, fontWeight: FontWeight.w600),
                  labelResolver: (_) => 'teraz',
                ),
              ),
          ],
        ),
        // Index 0/1 = typical range edges (invisible, filled between), 2 = usual, 3 = actual.
        lineBarsData: [
          line(rangeMax, Colors.transparent, 0),
          line(rangeMin, Colors.transparent, 0),
          line(usual, _blue.withValues(alpha: 0.6), 1.5, dash: [4, 4]),
          actualLine,
        ],
        betweenBarsData: [BetweenBarsData(fromIndex: 0, toIndex: 1, color: _blue.withValues(alpha: 0.15))],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => Colors.black87,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (touched) => touched.map((s) {
              final i = s.x.toInt();
              final p = predictions[i];
              final header = identical(s, touched.first) ? '${DateFormat('EEE HH:mm').format(_buckets[i].startTime)}\n' : '';
              const style = TextStyle(color: Colors.white, fontSize: 12);
              return switch (s.barIndex) {
                0 => LineTooltipItem('${header}typowo ${p!.min}–${p.max}', style),
                2 => LineTooltipItem('${header}zwykle ok. ${s.y.round()}', style),
                3 => LineTooltipItem('${header}zmierzono ok. ${s.y.round()}', style.copyWith(fontWeight: FontWeight.bold)),
                _ => null,
              };
            }).toList(),
          ),
        ),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: step,
              getTitlesWidget: (value, meta) =>
                  value % step == 0 ? Text(value.toInt().toString(), style: label) : const SizedBox.shrink(),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 3,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= n) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(DateFormat('H:mm').format(_buckets[index].startTime), style: label),
                );
              },
            ),
          ),
        ),
      ),
    );

    Widget legend(Widget mark, String text) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [mark, const SizedBox(width: 4), Text(text, style: label)],
        );

    return Container(
      height: 380,
      padding: const EdgeInsets.fromLTRB(8, 24, 16, 12),
      decoration: _cardDecoration,
      child: Column(
        children: [
          Expanded(child: chart),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              legend(Container(width: 14, height: 3, color: _blue), 'zmierzono'),
              legend(Container(width: 14, height: 2, color: _blue.withValues(alpha: 0.6)), 'zwykle'),
              legend(Container(width: 14, height: 10, color: _blue.withValues(alpha: 0.15)), 'typowy zakres'),
              if (_dayPrediction.isNotEmpty)
                Text(weeks == 0 ? 'brak historii dla tego dnia' : 'na podstawie $weeks z 4 tygodni', style: label),
            ],
          ),
        ],
      ),
    );
  }
}
