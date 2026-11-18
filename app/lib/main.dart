import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'screens/home_screen.dart';
import 'services/api_service.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pl');
  Intl.defaultLocale = 'pl';
  await ApiService.loadAdminToken();
  runApp(const CrowdnessApp());
}

class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}

class CrowdnessApp extends StatelessWidget {
  const CrowdnessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('pl'),
      supportedLocales: const [Locale('pl')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      scrollBehavior: AppScrollBehavior(),
      // Phone layout; on a wide window (the Linux test build) keep it a centered column.
      builder: (context, child) => ColoredBox(
        color: Palette.bg,
        child: Center(
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: child),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
