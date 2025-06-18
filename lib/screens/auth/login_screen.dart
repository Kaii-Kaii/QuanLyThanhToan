// lib/screens/auth/login_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isGoogleLoading = false; // Thêm biến loading riêng cho Google
  bool _obscurePassword = true;
  String? _loginError; // Thêm biến lưu lỗi đăng nhập

  void _setLoading(bool loading) {
    setState(() {
      _isLoading = loading;
    });
  }

  void _setGoogleLoading(bool loading) {
    setState(() {
      _isGoogleLoading = loading;
    });
  }

  Future<void> _login() async {
    // Reset lỗi trước khi đăng nhập
    setState(() {
      _loginError = null;
    });

    if (!_formKey.currentState!.validate() || _isLoading) return;

    _setLoading(true);
    try {
      await _authService.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        // Hiển thị lỗi dưới ô input
        switch (e.code) {
          case 'user-not-found':
            _loginError = 'Không tìm thấy tài khoản với email này';
            break;
          case 'wrong-password':
            _loginError = 'Sai tài khoản hoặc mật khẩu';
            break;
          case 'invalid-email':
            _loginError = 'Email không hợp lệ';
            break;
          case 'user-disabled':
            _loginError = 'Tài khoản đã bị vô hiệu hóa';
            break;
          case 'too-many-requests':
            _loginError = 'Quá nhiều lần thử. Vui lòng thử lại sau';
            break;
          case 'invalid-credential':
            _loginError = 'Sai tài khoản hoặc mật khẩu';
            break;
          default:
            _loginError = 'Đăng nhập thất bại. Vui lòng thử lại';
        }
      });
    } finally {
      _setLoading(false);
    }
  }

  // Cập nhật method đăng nhập với Google
  Future<void> _signInWithGoogle() async {
    setState(() {
      _loginError = null;
    });

    _setGoogleLoading(true);
    try {
      final userCredential = await _authService.signInWithGoogle();
      if (userCredential == null) {
        // User canceled the sign-in
        return;
      }

      // Hiển thị thông báo thành công (tùy chọn)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Đăng nhập thành công với ${userCredential.user?.email}',
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        switch (e.code) {
          case 'account-exists-with-different-credential':
            _loginError =
                'Email này đã được sử dụng với phương thức đăng nhập khác';
            break;
          case 'invalid-credential':
            _loginError = 'Thông tin đăng nhập không hợp lệ';
            break;
          case 'operation-not-allowed':
            _loginError = 'Đăng nhập Google chưa được kích hoạt';
            break;
          case 'user-disabled':
            _loginError = 'Tài khoản đã bị vô hiệu hóa';
            break;
          case 'network-request-failed':
            _loginError = 'Lỗi kết nối mạng. Vui lòng kiểm tra internet';
            break;
          default:
            _loginError = 'Đăng nhập Google thất bại: ${e.message}';
        }
      });
    } catch (e) {
      setState(() {
        _loginError = 'Đăng nhập Google thất bại. Vui lòng thử lại';
      });
      print('Google Sign-In Error: $e');
    } finally {
      if (mounted) {
        _setGoogleLoading(false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo/Icon
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.account_balance_wallet,
                      size: 64,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Title
                  Text(
                    'Chào mừng trở lại!',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Đăng nhập để tiếp tục',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textCapitalization: TextCapitalization.none,
                    autocorrect: false, // Thêm dòng này
                    enableSuggestions: false, // Thêm dòng này
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Vui lòng nhập email';
                      }
                      if (!RegExp(
                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                      ).hasMatch(value)) {
                        return 'Email không hợp lệ';
                      }
                      return null;
                    },
                    style: TextStyle(
                      fontSize: 16,
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: TextStyle(
                        color:
                            _loginError != null
                                ? colorScheme.error
                                : colorScheme.onSurface.withOpacity(0.7),
                        fontSize: 16,
                      ),
                      hintText: 'Nhập email của bạn',
                      hintStyle: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.5),
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.email_outlined,
                        color:
                            _loginError != null
                                ? colorScheme.error
                                : colorScheme.onSurface.withOpacity(0.7),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color:
                              _loginError != null
                                  ? colorScheme.error
                                  : colorScheme.outline,
                          width: 1.5,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color:
                              _loginError != null
                                  ? colorScheme.error
                                  : colorScheme.outline,
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color:
                              _loginError != null
                                  ? colorScheme.error
                                  : colorScheme.primary,
                          width: 2.5,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: colorScheme.error,
                          width: 1.5,
                        ),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: colorScheme.error,
                          width: 2.5,
                        ),
                      ),
                      filled: true,
                      fillColor:
                          isDark
                              ? colorScheme.surfaceVariant.withOpacity(0.3)
                              : colorScheme.surfaceVariant.withOpacity(0.5),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Vui lòng nhập mật khẩu';
                      }
                      // Bỏ validation độ dài mật khẩu cho đăng nhập
                      return null;
                    },
                    style: TextStyle(
                      fontSize: 16,
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu',
                      labelStyle: TextStyle(
                        color:
                            _loginError != null
                                ? colorScheme.error
                                : colorScheme.onSurface.withOpacity(0.7),
                        fontSize: 16,
                      ),
                      hintText: 'Nhập mật khẩu của bạn',
                      hintStyle: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.5),
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.lock_outline,
                        color:
                            _loginError != null
                                ? colorScheme.error
                                : colorScheme.onSurface.withOpacity(0.7),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: colorScheme.onSurface.withOpacity(0.7),
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color:
                              _loginError != null
                                  ? colorScheme.error
                                  : colorScheme.outline,
                          width: 1.5,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color:
                              _loginError != null
                                  ? colorScheme.error
                                  : colorScheme.outline,
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color:
                              _loginError != null
                                  ? colorScheme.error
                                  : colorScheme.primary,
                          width: 2.5,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: colorScheme.error,
                          width: 1.5,
                        ),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: colorScheme.error,
                          width: 2.5,
                        ),
                      ),
                      filled: true,
                      fillColor:
                          isDark
                              ? colorScheme.surfaceVariant.withOpacity(0.3)
                              : colorScheme.surfaceVariant.withOpacity(0.5),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),

                  // Hiển thị lỗi đăng nhập
                  if (_loginError != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        _loginError!,
                        style: TextStyle(
                          color: colorScheme.error,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Forgot Password
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ForgotPasswordScreen(),
                          ),
                        );
                      },
                      child: Text(
                        'Quên mật khẩu?',
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Login Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading || _isGoogleLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child:
                          _isLoading
                              ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    colorScheme.onPrimary,
                                  ),
                                ),
                              )
                              : const Text(
                                'Đăng nhập',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Divider
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: colorScheme.outline.withOpacity(0.5),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'hoặc',
                          style: TextStyle(
                            color: colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: colorScheme.outline.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Google Sign-In Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed:
                          _isLoading || _isGoogleLoading
                              ? null
                              : _signInWithGoogle,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: colorScheme.outline.withOpacity(0.5),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: colorScheme.surface,
                      ),
                      child:
                          _isGoogleLoading
                              ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    colorScheme.primary,
                                  ),
                                ),
                              )
                              : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    isDark
                                        ? 'lib/assets/android_dark_sq_na@1x.png'
                                        : 'lib/assets/android_light_sq_na@1x.png',
                                    height: 24,
                                    width: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Đăng nhập với Google',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Register Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed:
                          _isLoading || _isGoogleLoading
                              ? null
                              : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const RegisterScreen(),
                                  ),
                                );
                              },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: colorScheme.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Tạo tài khoản mới',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
