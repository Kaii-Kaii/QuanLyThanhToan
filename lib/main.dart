// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/auth/auth_gate.dart'; // Sửa đường dẫn import
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'services/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('vi_VN', null);
  runApp(
    ChangeNotifierProvider(create: (_) => ThemeService(), child: const MyApp()),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Quản Lý Thanh Toán',
      theme: ThemeData.light(
        useMaterial3: true,
      ).copyWith(cardColor: Colors.white),
      darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
        cardColor: Colors.grey[900], // hoặc colorScheme.surface
      ),
      themeMode: themeService.themeMode,
      home: const AuthGate(),
    );
  }
}
