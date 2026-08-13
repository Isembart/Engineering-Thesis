import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/board.dart';
import '../models/board_settings.dart';
import '../services/api_service.dart';
import '../utils/mac_address_formatter.dart';

class BoardSettingsScreen extends StatefulWidget {
  final Board board;

  const BoardSettingsScreen({Key? key, required this.board}) : super(key: key);

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
        _error = 'Failed to load board settings.';
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
      final saved = creating
          ? await _apiService.createBoardSettings(widget.board.boardMac, settings)
          : await _apiService.updateBoardSettings(widget.board.boardMac, settings);

      if (!mounted) return;

      setState(() {
        _exists = true;
        _isSaving = false;
      });
      _applySettings(saved);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(creating ? 'Settings created' : 'Settings saved')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save settings: $e')),
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
    return InputDecoration(
      labelText: label,
      helperText: helper,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
    );
  }

  String? _requiredInt(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    if (int.tryParse(value.trim()) == null) return 'Enter an integer';
    return null;
  }

  Widget _intField({
    required TextEditingController controller,
    required String label,
    String? helper,
    bool allowNegative = false,
  }) {
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
        decoration: _fieldDecoration(label, helper: helper),
        validator: _requiredInt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.board.name?.isNotEmpty == true
        ? '${widget.board.name} settings'
        : '${MacAddressFormatter.format(widget.board.boardMac)} settings';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(
          title,
          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
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
            ElevatedButton(onPressed: _loadSettings, child: const Text('Retry')),
          ],
        ),
      );
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (!_exists)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'No settings yet. Form is filled with defaults from config.h.example.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
          _intField(
            controller: _scansPerSendController,
            label: 'Scans per send',
          ),
          _intField(
            controller: _wifiScanTimeMsController,
            label: 'WiFi scan time (ms)',
          ),
          _intField(
            controller: _bluetoothScanTimeMsController,
            label: 'Bluetooth scan time (ms)',
          ),
          _intField(
            controller: _wifiChannelScanTimeMsController,
            label: 'WiFi channel scan time (ms)',
          ),
          _intField(
            controller: _minimalEncounterCountController,
            label: 'Minimal encounter count',
          ),
          _intField(
            controller: _minRssiController,
            label: 'Min RSSI WiFi (dBm)',
            allowNegative: true,
          ),
          _intField(
            controller: _minRssiBleController,
            label: 'Min RSSI BLE (dBm)',
            allowNegative: true,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue.shade600,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      _exists ? 'Save settings' : 'Create settings',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
