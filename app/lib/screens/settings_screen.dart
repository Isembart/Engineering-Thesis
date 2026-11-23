import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'admin_access_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _urlController = TextEditingController();
  final _apiService = ApiService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentUrl();
  }

  Future<void> _loadCurrentUrl() async {
    final url = await _apiService.getServerUrl();
    setState(() {
      _urlController.text = url;
      _isLoading = false;
    });
  }

  Future<void> _saveUrl() async {
    final newUrl = ApiService.normalizeServerUrl(_urlController.text);
    if (newUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nieprawidłowy adres serwera')),
      );
      return;
    }
    await _apiService.setServerUrl(newUrl);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Zapisano adres serwera')),
    );
    Navigator.pop(context, true); // Return true to indicate change
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ustawienia')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Serwer', style: heading(20)),
                  const SizedBox(height: 4),
                  Text('Adres serwera Twojej instytucji.', style: archivo(14, color: Palette.muted)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _urlController,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Adres serwera',
                      hintText: 'https://example.org',
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _saveUrl, child: const Text('Zapisz')),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AdminAccessScreen()),
                    ),
                    child: const Text('Dostęp administratora'),
                  ),
                ],
              ),
            ),
    );
  }
}
