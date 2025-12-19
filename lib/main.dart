import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'loginScreen.dart';
import 'dashboard_screen.dart';
import 'add_product_screen.dart';
import 'database_helper.dart';
import 'settings_store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await DatabaseHelper().database;

  final settings = SettingsStore();
  await settings.load();

  runApp(SettingsProvider(store: settings, child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final store = SettingsProvider.of(context);

    final themeMode = (store.getSetting('theme_mode') ?? 'light').toString();
    final isDark = themeMode == 'dark';
    final fontScaleRaw = store.getSetting('font_scale') ?? 1.0;
    final double fontScale = (fontScaleRaw is num) ? fontScaleRaw.toDouble() : 1.0;
    final isRtl = (store.getSetting('is_rtl') ?? true) as bool;

    final baseTheme = ThemeData(
      fontFamily: 'Cairo',
      brightness: isDark ? Brightness.dark : Brightness.light,
      primarySwatch: Colors.blue,
      appBarTheme: const AppBarTheme(
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontFamily: 'Cairo'),
        bodyMedium: TextStyle(fontFamily: 'Cairo'),
      ),
    );

    return MaterialApp(
      title: 'نظام إدارة المخزون',
      debugShowCheckedModeBanner: false,
      theme: baseTheme,
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/add_product': (context) => const AddProductScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/dashboard') {
          final args = settings.arguments as Map<String, String>?;
          return MaterialPageRoute(
            builder: (context) => DashboardScreen(
              username: args?['username'] ?? 'مستخدم',
              role: args?['role'] ?? 'user',
              name: args?['name'] ?? 'المستخدم',
            ),
          );
        }
        return null;
      },
      builder: (context, child) {
        return Directionality(
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaleFactor: fontScale),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
