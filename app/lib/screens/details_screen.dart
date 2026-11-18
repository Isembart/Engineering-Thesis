import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/board.dart';
import '../models/hour_prediction.dart';
import '../services/api_service.dart';
import '../services/data_aggregator.dart';
import '../theme.dart';
import '../widgets/board_card.dart';
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

      final records = await _apiService.getBoardData(widget.board.boardMac, start: start, end: end);
      final recentRecords = await _apiService.getBoardData(
        widget.board.boardMac,
        start: now.subtract(const Duration(minutes: 15)),
        end: now,
      );

      // Predictions are optional: on failure the chart shows only actual data.
      final dayEnd = DateTime(d.year, d.month, d.day + 1);
      final today = DateTime(now.year, now.month, now.day);
      final mac = widget.board.boardMac;
      final [dayPrediction, weekPrediction] = await Future.wait([
        _apiService.getBoardPrediction(mac, start, dayEnd),
        _apiService.getBoardPrediction(mac, today, DateTime(now.year, now.month, now.day + 7)),
      ].map((f) => f.catchError((_) => <HourPrediction>[])));

      if (!mounted) return;
      setState(() {
        _buckets = DataAggregator.aggregateToFixedBuckets(records, start, end);
        _dayPrediction = {for (final p in dayPrediction) p.timestamp.millisecondsSinceEpoch: p};
        _weekPrediction = weekPrediction;
        _currentClients = DataAggregator.getCurrentCrowdLevel(recentRecords);
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
        title: Text('Zmień nazwę', style: heading(20)),
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
      messenger.showSnackBar(SnackBar(content: Text('Nie udało się zmienić nazwy: $e')));
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
          // Admin controls are not built at all in guest mode
          actions: [
            ValueListenableBuilder<bool>(
              valueListenable: ApiService.isAdmin,
              builder: (context, isAdmin, _) {
                if (!isAdmin) return const SizedBox.shrink();
                return PopupMenuButton<VoidCallback>(
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'Więcej',
                  onSelected: (action) => action(),
                  itemBuilder: (context) => [
                    PopupMenuItem(value: _showRenameDialog, child: const Text('Zmień nazwę')),
                    PopupMenuItem(
                      value: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => BoardSettingsScreen(board: widget.board)),
                      ),
                      child: const Text('Ustawienia czujnika'),
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
        body: RefreshIndicator(
          onRefresh: _loadData,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              Text(boardDisplayName(widget.board, _boardName), style: heading(30)),
              const SizedBox(height: 16),
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
    if (_isLoading) {
      return const Column(
        key: ValueKey('loading'),
        children: [Skeleton(height: 130), SizedBox(height: 32), Skeleton(height: 300)],
      );
    }
    if (_error != null) {
      return Padding(
        key: const ValueKey('error'),
        padding: const EdgeInsets.only(top: 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_error!, style: archivo(18, weight: FontWeight.w600)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadData, child: const Text('Spróbuj ponownie')),
          ],
        ),
      );
    }

    final dateLabel = _isToday(_selectedDate) ? 'Dziś' : DateFormat('EEEE, d MMM').format(_selectedDate);

    return Column(
      key: const ValueKey('content'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: panelDecoration(),
          child: StatusBlock(current: _currentClients, prediction: _currentHourPrediction()),
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _selectCustomDate,
                child: Text(
                  dateLabel[0].toUpperCase() + dateLabel.substring(1),
                  style: heading(22).copyWith(decoration: TextDecoration.underline, decorationColor: Palette.line),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Poprzedni dzień',
              onPressed: () => _showDate(_selectedDate.subtract(const Duration(days: 1))),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Następny dzień',
              onPressed: _isToday(_selectedDate) ? null : () => _showDate(_selectedDate.add(const Duration(days: 1))),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: SegmentedButton<Timeframe>(
            segments: const [
              ButtonSegment(value: Timeframe.daytime, label: Text('6–23')),
              ButtonSegment(value: Timeframe.fullDay, label: Text('Cała doba')),
            ],
            selected: {_selectedTimeframe},
            showSelectedIcon: false,
            onSelectionChanged: (selection) {
              setState(() => _selectedTimeframe = selection.first);
              _loadData();
            },
          ),
        ),
        const SizedBox(height: 12),
        _buildChartCard(),
        const SizedBox(height: 32),
        Text('Typowy tydzień', style: heading(22)),
        const SizedBox(height: 4),
        Text('Zwykła liczba osób. Dotknij pola, aby zobaczyć szczegóły.',
            style: archivo(14, color: Palette.muted)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(8, 12, 12, 12),
          decoration: panelDecoration(),
          child: _weekPrediction.isEmpty
              ? Text('Brak prognozy dla tego miejsca.', style: archivo(14, color: Palette.muted))
              : WeekHeatmap(
                  week: _weekPrediction,
                  fromHour: _selectedTimeframe == Timeframe.daytime ? 6 : 0,
                  toHour: 24,
                ),
        ),
      ],
    );
  }

  HourPrediction? _currentHourPrediction() {
    final now = DateTime.now();
    final hourStart = DateTime(now.year, now.month, now.day, now.hour);
    return _weekPrediction.where((p) => p.timestamp.isAtSameMomentAs(hourStart)).firstOrNull;
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
        height: 200,
        alignment: Alignment.center,
        decoration: panelDecoration(),
        child: Text('Brak danych dla tego dnia.', style: archivo(14, color: Palette.muted)),
      );
    }
    final (maxY, step) = _yScale(values.reduce((a, b) => a > b ? a : b));
    final weeks = predictions.map((p) => p?.samples ?? 0).fold(0, (a, b) => b > a ? b : a);
    final label = archivo(11, color: Palette.muted);

    // Where "now" falls, in bucket units; null when it is not on this chart.
    final nowIndex = _buckets.indexWhere((b) => !now.isBefore(b.startTime) && now.isBefore(b.endTime));
    final nowX = nowIndex < 0 ? null : nowIndex + now.minute / 60;

    LineChartBarData line(List<FlSpot> spots, Color color, double width, {List<int>? dash, bool dots = false}) =>
        LineChartBarData(
          spots: spots,
          color: color,
          barWidth: width,
          dashArray: dash,
          dotData: FlDotData(
            show: dots,
            getDotPainter: (_, _, _, _) => FlDotCirclePainter(radius: 2.5, color: color, strokeWidth: 0),
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
          getDrawingHorizontalLine: (_) => const FlLine(color: Palette.heatLow, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        extraLinesData: ExtraLinesData(
          verticalLines: [
            if (nowX != null)
              VerticalLine(
                x: nowX,
                color: Palette.muted,
                strokeWidth: 1,
                dashArray: [3, 3],
                label: VerticalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  style: archivo(11, weight: FontWeight.w600, color: Palette.muted),
                  labelResolver: (_) => 'teraz',
                ),
              ),
          ],
        ),
        // Index 0/1 = typical range edges (invisible, filled between), 2 = usual, 3 = actual.
        lineBarsData: [
          line(rangeMax, Colors.transparent, 0),
          line(rangeMin, Colors.transparent, 0),
          line(usual, Palette.muted, 1.5, dash: [4, 4]),
          line(actual, Palette.accent, 2.5, dots: true),
        ],
        betweenBarsData: [BetweenBarsData(fromIndex: 0, toIndex: 1, color: Palette.learning)],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => Palette.ink,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (touched) => touched.map((s) {
              final i = s.x.toInt();
              final p = predictions[i];
              final header = identical(s, touched.first) ? '${DateFormat('HH:mm').format(_buckets[i].startTime)}\n' : '';
              final style = archivo(12, color: Colors.white);
              return switch (s.barIndex) {
                0 => LineTooltipItem('${header}typowo ${p!.min}–${p.max}', style),
                2 => LineTooltipItem('${header}zwykle ok. ${s.y.round()}', style),
                3 => LineTooltipItem('${header}zmierzono ok. ${s.y.round()}', style.copyWith(fontWeight: FontWeight.w700)),
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
              reservedSize: 32,
              interval: step,
              getTitlesWidget: (value, meta) =>
                  value % step == 0 ? Text(value.toInt().toString(), style: label) : const SizedBox.shrink(),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: 3,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= n) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
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
          children: [mark, const SizedBox(width: 6), Text(text, style: label)],
        );

    return Container(
      height: 320,
      padding: const EdgeInsets.fromLTRB(4, 20, 16, 12),
      decoration: panelDecoration(),
      child: Column(
        children: [
          Expanded(child: chart),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Wrap(
              spacing: 14,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                legend(Container(width: 14, height: 3, color: Palette.accent), 'zmierzono'),
                legend(Container(width: 14, height: 2, color: Palette.muted), 'zwykle'),
                legend(Container(width: 14, height: 10, color: Palette.learning), 'typowy zakres'),
                if (_dayPrediction.isNotEmpty)
                  Text(weeks == 0 ? 'brak historii dla tego dnia' : 'na podstawie $weeks z 4 tygodni', style: label),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
