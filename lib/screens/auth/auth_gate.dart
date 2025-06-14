// lib/screens/auth/auth_gate.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart'; // Import AuthService
import '../home/home_screen.dart'; // Sửa đường dẫn đến home_screen
import 'login_screen.dart'; // Sửa đường dẫn đến login_screen

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // Sử dụng stream từ AuthService để code sạch hơn
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        // User is logged in
        if (snapshot.hasData) {
          return const HomeScreen();
        }
        // User is NOT logged in
        else {
          return const LoginScreen();
        }
      },
    );
  }
}
