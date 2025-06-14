import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'profile_info_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  Future<void> _register() async {
    setState(() => _isLoading = true);
    try {
      await _authService.registerWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final user = AuthService().currentUser;
      await user?.sendEmailVerification();

      if (!mounted) return;
      _showVerifyDialog();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đăng ký thất bại: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showVerifyDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            bool _checking = false;
            return AlertDialog(
              title: const Text('Xác minh email'),
              content: const Text(
                  'Vui lòng kiểm tra email và xác minh tài khoản. Sau khi xác minh, nhấn "Tôi đã xác minh".'),
              actions: [
                TextButton(
                  onPressed: _checking
                      ? null
                      : () async {
                          setStateDialog(() => _checking = true);
                          await AuthService().currentUser?.reload();
                          final verified = AuthService().currentUser?.emailVerified ?? false;
                          setStateDialog(() => _checking = false);
                          if (verified) {
                            if (mounted) Navigator.of(context).pop();
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const ProfileInfoScreen()),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Bạn chưa xác minh email!')),
                            );
                          }
                        },
                  child: _checking
                      ? const SizedBox(
                          width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Tôi đã xác minh'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng ký')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Mật khẩu', border: OutlineInputBorder()),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _register,
                      child: const Text('Đăng ký'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}