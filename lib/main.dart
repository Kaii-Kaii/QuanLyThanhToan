// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/auth/auth_gate.dart'; // Sửa đường dẫn import
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('vi_VN', null); // Khởi tạo locale tiếng Việt
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Quản Lý Thanh Toán',
      theme: ThemeData.light(useMaterial3: true), // Thử giao diện sáng
      darkTheme: ThemeData.dark(useMaterial3: true),
      themeMode: ThemeMode.system, // Tự động chọn theme theo hệ thống
      home: const AuthGate(),
    );
  }
}
