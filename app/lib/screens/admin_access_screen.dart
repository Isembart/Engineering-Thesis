import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/api_service.dart';

/// Where an admin token is entered (pasted, or scanned from the QR code the server
/// prints on startup) and where admin mode is left again.
class AdminAccessScreen extends StatefulWidget {
  const AdminAccessScreen({super.key});

  @override
  State<AdminAccessScreen> createState() => _AdminAccessScreenState();
}

class _AdminAccessScreenState extends State<AdminAccessScreen> {
  final _apiService = ApiService();
  final _tokenController = TextEditingController();
  bool _isChecking = false;

  // The scanner plugin has no desktop Linux/Windows implementation, pasting works everywhere
  bool get _canScan =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _submit(String token) async {
    token = token.trim();
    if (token.isEmpty || _isChecking) return;

    setState(() => _isChecking = true);
    String message;
    try {
      message = await _apiService.enterAdminMode(token)
          ? 'Przyznano dostęp administratora'
          : 'Serwer odrzucił ten token';
    } catch (e) {
      message = 'Nie udało się połączyć z serwerem, by sprawdzić token';
    }
    if (!mounted) return;

    _tokenController.clear();
    setState(() => _isChecking = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _scan() async {
    final token = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const _ScanTokenScreen()),
    );
    if (token != null) {
      await _submit(token);
    }
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dostęp administratora')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ValueListenableBuilder<bool>(
          valueListenable: ApiService.isAdmin,
          builder: (context, isAdmin, _) => isAdmin ? _buildAdmin() : _buildGuest(),
        ),
      ),
    );
  }

  Widget _buildAdmin() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tryb administratora jest włączony. Możesz zmieniać nazwy miejsc i ustawienia czujników na tym serwerze.',
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _apiService.leaveAdminMode,
            child: const Text('Wyłącz tryb administratora'),
          ),
        ),
      ],
    );
  }

  Widget _buildGuest() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Wpisz token administratora tego serwera. Serwer wypisuje go, razem z kodem QR, przy każdym uruchomieniu.',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _tokenController,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          onSubmitted: _submit,
          decoration: const InputDecoration(labelText: 'Token administratora'),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isChecking ? null : () => _submit(_tokenController.text),
            child: Text(_isChecking ? 'Sprawdzanie…' : 'Odblokuj'),
          ),
        ),
        if (_canScan) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isChecking ? null : _scan,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Zeskanuj kod QR'),
            ),
          ),
        ],
      ],
    );
  }
}

class _ScanTokenScreen extends StatefulWidget {
  const _ScanTokenScreen();

  @override
  State<_ScanTokenScreen> createState() => _ScanTokenScreenState();
}

class _ScanTokenScreenState extends State<_ScanTokenScreen> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Zeskanuj kod QR')),
      body: MobileScanner(
        onDetect: (capture) {
          final value = capture.barcodes.firstOrNull?.rawValue;
          // onDetect keeps firing while the code is in view, pop only once
          if (value == null || _done) return;
          _done = true;
          Navigator.pop(context, value);
        },
      ),
    );
  }
}
