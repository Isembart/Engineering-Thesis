import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/board.dart';
import '../models/board_settings.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/board_card.dart';

class BoardSettingsScreen extends StatefulWidget {
  final Board board;

  const BoardSettingsScreen({super.key, required this.board});

  @override
  State<BoardSettingsScreen> createState() => _BoardSettingsScreenState();
}

class _BoardSettingsScreenState extends State<BoardSettingsScreen> {
  final _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  final _scansPerSendController = TextEditingController();
  final _wifiScanTimeMsController = TextEditingController();
  final _bluetoothScanTimeMsController = TextEditingController();
  final _wifiChannelScanTimeMsController = TextEditingController();
  final _minimalEncounterCountController = TextEditingController();
  final _minRssiController = TextEditingController();
  final _minRssiBleController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _exists = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _applySettings(BoardSettings settings) {
    _scansPerSendController.text = settings.scansPerSend.toString();
    _wifiScanTimeMsController.text = settings.wifiScanTimeMs.toString();
    _bluetoothScanTimeMsController.text = settings.bluetoothScanTimeMs.toString();
    _wifiChannelScanTimeMsController.text = settings.wifiChannelScanTimeMs.toString();
    _minimalEncounterCountController.text = settings.minimalEncounterCount.toString();
    _minRssiController.text = settings.minRssi.toString();
    _minRssiBleController.text = settings.minRssiBle.toString();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final settings = await _apiService.getBoardSettings(widget.board.boardMac);
      if (!mounted) return;

      if (settings != null) {
        _exists = true;
        _applySettings(settings);
      } else {
        _exists = false;
        _applySettings(BoardSettings.defaults());
      }

      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Nie udało się pobrać ustawień czujnika.';
        _isLoading = false;
      });
    }
  }

  BoardSettings _settingsFromForm() {
    return BoardSettings(
      scansPerSend: int.parse(_scansPerSendController.text.trim()),
      wifiScanTimeMs: int.parse(_wifiScanTimeMsController.text.trim()),
      bluetoothScanTimeMs: int.parse(_bluetoothScanTimeMsController.text.trim()),
      wifiChannelScanTimeMs: int.parse(_wifiChannelScanTimeMsController.text.trim()),
      minimalEncounterCount: int.parse(_minimalEncounterCountController.text.trim()),
      minRssi: int.parse(_minRssiController.text.trim()),
      minRssiBle: int.parse(_minRssiBleController.text.trim()),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final settings = _settingsFromForm();
      final creating = !_exists;
      final saved = await _apiService.updateBoardSettings(widget.board.boardMac, settings);

      if (!mounted) return;

      setState(() {
        _exists = true;
        _isSaving = false;
      });
      _applySettings(saved);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(creating ? 'Utworzono ustawienia' : 'Zapisano ustawienia')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się zapisać ustawień: $e')),
      );
    }
  }

  @override
  void dispose() {
    _scansPerSendController.dispose();
    _wifiScanTimeMsController.dispose();
    _bluetoothScanTimeMsController.dispose();
    _wifiChannelScanTimeMsController.dispose();
    _minimalEncounterCountController.dispose();
    _minRssiController.dispose();
    _minRssiBleController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(String label, {String? helper}) {
    return InputDecoration(labelText: label, helperText: helper);
  }

  String? _intInRange(String? value, int min, int max) {
    if (value == null || value.trim().isEmpty) return 'Pole wymagane';
    final parsed = int.tryParse(value.trim());
    if (parsed == null) return 'Podaj liczbę całkowitą';
    if (parsed < min || parsed > max) return 'Wartość od $min do $max';
    return null;
  }

  // Bounds mirror the board (BoardSettings::tunablesInBounds) and the server (BoardSettingsDTO::validate)
  Widget _intField({
    required TextEditingController controller,
    required String label,
    required int min,
    required int max,
  }) {
    final allowNegative = min < 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(signed: allowNegative),
        inputFormatters: [
          FilteringTextInputFormatter.allow(
            allowNegative ? RegExp(r'^-?\d*') : RegExp(r'\d*'),
          ),
        ],
        decoration: _fieldDecoration(label, helper: 'od $min do $max'),
        validator: (value) => _intInRange(value, min, max),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Ustawienia: ${boardDisplayName(widget.board)}')),
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
            Text(_error!, style: archivo(18, weight: FontWeight.w600)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadSettings, child: const Text('Spróbuj ponownie')),
          ],
        ),
      );
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!_exists)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Ten czujnik nie ma jeszcze ustawień. Formularz zawiera jego wartości domyślne.',
                style: archivo(14, color: Palette.muted),
              ),
            ),
          _intField(
            controller: _scansPerSendController,
            label: 'Skany na jedną wysyłkę',
            min: 1,
            max: 10,
          ),
          _intField(
            controller: _wifiScanTimeMsController,
            label: 'Czas skanowania WiFi (ms)',
            min: 1000,
            max: 5 * 60 * 1000,
          ),
          _intField(
            controller: _bluetoothScanTimeMsController,
            label: 'Czas skanowania Bluetooth (ms)',
            min: 1000,
            max: 60 * 1000,
          ),
          _intField(
            controller: _wifiChannelScanTimeMsController,
            label: 'Czas skanowania kanału WiFi (ms)',
            min: 50,
            max: 5000,
          ),
          _intField(
            controller: _minimalEncounterCountController,
            label: 'Minimalna liczba wykryć',
            min: 1,
            max: 100,
          ),
          _intField(
            controller: _minRssiController,
            label: 'Minimalne RSSI WiFi (dBm)',
            min: -100,
            max: 0,
          ),
          _intField(
            controller: _minRssiBleController,
            label: 'Minimalne RSSI BLE (dBm)',
            min: -100,
            max: 0,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_exists ? 'Zapisz ustawienia' : 'Utwórz ustawienia'),
            ),
          ),
        ],
      ),
    );
  }
}
