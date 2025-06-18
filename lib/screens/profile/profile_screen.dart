import 'dart:io';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../services/theme_service.dart';
import '../auth/change_password_screen.dart';
import '../../services/auth_service.dart';
import '../../utils/avatar_helper.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _displayNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isEditing = false;
  bool _isLoading = false;

  File? _avatarFile;
  bool _isUploadingAvatar = false;

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (pickedFile != null) {
      setState(() {
        _avatarFile = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadAvatar(File image) async {
    setState(() => _isUploadingAvatar = true);
    try {
      final cloudinary = CloudinaryPublic(
        'ddfzzvwvx',
        'flutter_uploads',
        cache: false,
      );
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          image.path,
          resourceType: CloudinaryResourceType.Image,
        ),
      );
      return response.secureUrl;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi upload ảnh: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return null;
    } finally {
      setState(() => _isUploadingAvatar = false);
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile(String uid) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      String? avatarUrl;
      if (_avatarFile != null) {
        avatarUrl = await _uploadAvatar(_avatarFile!);
        if (avatarUrl == null) throw Exception('Không upload được ảnh');
      }

      // Sửa kiểu dữ liệu từ Map<String, String> thành Map<String, dynamic>
      final Map<String, dynamic> updateData = {
        'displayName': _displayNameController.text.trim(),
      };

      if (avatarUrl != null) {
        // Sử dụng helper để cập nhật đúng cách
        updateData.addAll(AvatarHelper.getUpdateData(avatarUrl));
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update(updateData);

      setState(() {
        _isEditing = false;
        _avatarFile = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Cập nhật thông tin thành công'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildThemeSwitcher(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final mode = themeService.mode;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Map<AppThemeMode, Widget> segments = {
      AppThemeMode.light: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.light_mode_outlined, size: 24),
            SizedBox(height: 6),
            Text(
              'Sáng',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
      AppThemeMode.dark: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.dark_mode_outlined, size: 24),
            SizedBox(height: 6),
            Text(
              'Tối',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
      AppThemeMode.system: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.settings_outlined, size: 24),
            SizedBox(height: 6),
            Text(
              'Hệ thống',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    };

    return Container(
      decoration: BoxDecoration(
        color:
            isDark
                ? colorScheme.surfaceVariant.withOpacity(0.3)
                : colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.palette_outlined,
                  size: 20,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Giao diện',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: CupertinoSlidingSegmentedControl<AppThemeMode>(
              groupValue: mode,
              children: segments,
              onValueChanged: (AppThemeMode? value) {
                if (value != null) {
                  themeService.setMode(value);
                }
              },
              thumbColor: colorScheme.primary.withOpacity(0.15),
              backgroundColor: colorScheme.surface.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? backgroundColor,
    Color? foregroundColor,
    bool isOutlined = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child:
          isOutlined
              ? OutlinedButton.icon(
                icon: Icon(icon, size: 20),
                label: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: onPressed,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: colorScheme.primary, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  foregroundColor: colorScheme.primary,
                ),
              )
              : ElevatedButton.icon(
                icon: Icon(icon, size: 20),
                label: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: backgroundColor ?? colorScheme.primary,
                  foregroundColor: foregroundColor ?? colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
    );
  }

  Widget _buildUidDisplay(
    String uid,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: SelectableText(
                uid,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.7),
                  fontFamily: "monospace",
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.copy, size: 20),
              tooltip: 'Sao chép UID',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: uid));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã sao chép UID'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    if (user == null) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: const Center(child: Text('Không tìm thấy người dùng')),
      );
    }

    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            backgroundColor: colorScheme.surface,
            body: Center(
              child: CircularProgressIndicator(color: colorScheme.primary),
            ),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final avatar = AvatarHelper.getAvatarUrl(data);
        final displayName = data['displayName'] ?? '';
        final email = user.email ?? '';
        final uid = user.uid;

        if (!_isEditing) {
          _displayNameController.text = displayName;
        }

        return Scaffold(
          backgroundColor: colorScheme.surface,
          appBar: AppBar(
            title: Text(
              'Thông tin cá nhân',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            backgroundColor: colorScheme.surface,
            elevation: 0,
            iconTheme: IconThemeData(color: colorScheme.onSurface),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // Avatar Section
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colorScheme.primary.withOpacity(0.3),
                                width: 3,
                              ),
                            ),
                            child:
                                _avatarFile != null
                                    ? CircleAvatar(
                                      radius: 60,
                                      backgroundColor:
                                          colorScheme.surfaceVariant,
                                      backgroundImage: FileImage(_avatarFile!),
                                    )
                                    : AvatarHelper.buildAvatar(
                                      avatarUrl: avatar,
                                      radius: 60,
                                      backgroundColor:
                                          colorScheme.surfaceVariant,
                                      iconColor: colorScheme.onSurfaceVariant,
                                    ),
                          ),
                          if (_isUploadingAvatar)
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: colorScheme.primary,
                                  strokeWidth: 3,
                                ),
                              ),
                            ),
                          if (_isEditing && !_isUploadingAvatar)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: InkWell(
                                onTap: _pickAvatar,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.camera_alt,
                                    color: colorScheme.onPrimary,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Profile Info Section
                    if (_isEditing) ...[
                      // Edit Mode
                      TextFormField(
                        controller: _displayNameController,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Vui lòng nhập tên hiển thị';
                          }
                          if (value.trim().length < 2) {
                            return 'Tên hiển thị phải có ít nhất 2 ký tự';
                          }
                          return null;
                        },
                        style: TextStyle(
                          fontSize: 16,
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Tên hiển thị',
                          labelStyle: TextStyle(
                            color: colorScheme.onSurface.withOpacity(0.7),
                            fontSize: 16,
                          ),
                          hintText: 'Nhập tên hiển thị của bạn',
                          hintStyle: TextStyle(
                            color: colorScheme.onSurface.withOpacity(0.5),
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.person_outline,
                            color: colorScheme.onSurface.withOpacity(0.7),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: colorScheme.outline,
                              width: 1.5,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: colorScheme.outline,
                              width: 1.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: colorScheme.primary,
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
                      const SizedBox(height: 12),
                      _buildUidDisplay(uid, theme, colorScheme),
                      const SizedBox(height: 12),

                      // Save/Cancel Buttons
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              icon: Icons.save_outlined,
                              label:
                                  _isLoading ? 'Đang lưu...' : 'Lưu thay đổi',
                              onPressed:
                                  _isLoading
                                      ? () {}
                                      : () => _updateProfile(user.uid),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildActionButton(
                              icon: Icons.close,
                              label: 'Hủy',
                              onPressed: () {
                                setState(() {
                                  _isEditing = false;
                                  _avatarFile = null;
                                });
                              },
                              isOutlined: true,
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      // Display Mode
                      Text(
                        displayName.isNotEmpty
                            ? displayName
                            : 'Chưa có tên hiển thị',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        email,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      _buildUidDisplay(uid, theme, colorScheme),
                      _buildActionButton(
                        icon: Icons.edit_outlined,
                        label: 'Chỉnh sửa thông tin',
                        onPressed: () {
                          setState(() => _isEditing = true);
                        },
                        isOutlined: true,
                      ),
                    ],

                    const SizedBox(height: 40),

                    // Theme Switcher
                    _buildThemeSwitcher(context),
                    const SizedBox(height: 24),

                    // Change Password Button
                    _buildActionButton(
                      icon: Icons.lock_reset_outlined,
                      label: 'Thay đổi mật khẩu',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ChangePasswordScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Logout Button
                    _buildActionButton(
                      icon: Icons.logout,
                      label: 'Đăng xuất',
                      onPressed: () async {
                        final shouldLogout = await showDialog<bool>(
                          context: context,
                          builder:
                              (context) => AlertDialog(
                                title: const Text('Xác nhận đăng xuất'),
                                content: const Text(
                                  'Bạn có chắc chắn muốn đăng xuất?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () => Navigator.pop(context, false),
                                    child: const Text('Hủy'),
                                  ),
                                  TextButton(
                                    onPressed:
                                        () => Navigator.pop(context, true),
                                    child: const Text('Đăng xuất'),
                                  ),
                                ],
                              ),
                        );

                        if (shouldLogout == true) {
                          await AuthService().signOut();
                          if (mounted) Navigator.pop(context);
                        }
                      },
                      backgroundColor: colorScheme.error,
                      foregroundColor: colorScheme.onError,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
