import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../services/theme_service.dart';
import '../auth/change_password_screen.dart';
import '../../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _displayNameController = TextEditingController();
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi upload ảnh: $e')));
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
    setState(() => _isLoading = true);
    try {
      String? avatarUrl;
      if (_avatarFile != null) {
        avatarUrl = await _uploadAvatar(_avatarFile!);
        if (avatarUrl == null) throw Exception('Không upload được ảnh');
      }
      final updateData = {'displayName': _displayNameController.text.trim()};
      if (avatarUrl != null) {
        updateData['avatar'] = avatarUrl;
      }
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update(updateData);
      setState(() {
        _isEditing = false;
        _avatarFile = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cập nhật thông tin thành công')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi: ${e.toString()}')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildThemeSwitcher(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final mode = themeService.mode;

    final Map<AppThemeMode, Widget> segments = {
      AppThemeMode.light: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.light_mode, size: 28),
            SizedBox(height: 4),
            Text('Sáng', style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
      AppThemeMode.dark: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.dark_mode, size: 28),
            SizedBox(height: 4),
            Text('Tối', style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
      AppThemeMode.system: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.phone_android, size: 28),
            SizedBox(height: 4),
            Text('Hệ thống', style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    };

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.palette_rounded, size: 22),
              SizedBox(width: 8),
              Text(
                'Giao diện',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final segmentWidth = (constraints.maxWidth - 8) / 3;
                return CupertinoSlidingSegmentedControl<AppThemeMode>(
                  groupValue: mode,
                  children: segments.map(
                    (key, value) => MapEntry(
                      key,
                      SizedBox(
                        width: segmentWidth,
                        child: Center(child: value),
                      ),
                    ),
                  ),
                  onValueChanged: (AppThemeMode? value) {
                    if (value != null) {
                      themeService.setMode(value);
                    }
                  },
                  thumbColor: Theme.of(context).colorScheme.primary.withOpacity(0.22),
                  backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(0.7),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Không tìm thấy người dùng')),
      );
    }
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final avatar = (data['avatar'] as String?)?.isNotEmpty == true
            ? data['avatar']
            : 'https://res.cloudinary.com/ddfzzvwvx/image/upload/v1749923335/download_iqse1o.jpg';
        final displayName = data['displayName'] ?? '';
        final email = user.email ?? '';

        if (!_isEditing) {
          _displayNameController.text = displayName;
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Thông tin cá nhân')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 32),
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 80,
                        backgroundImage: _avatarFile != null
                            ? FileImage(_avatarFile!)
                            : NetworkImage(avatar) as ImageProvider,
                        child: _isUploadingAvatar
                            ? const CircularProgressIndicator()
                            : null,
                      ),
                      if (_isEditing)
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: InkWell(
                            onTap: _isUploadingAvatar ? null : _pickAvatar,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _isEditing
                    ? Column(
                        children: [
                          TextField(
                            controller: _displayNameController,
                            decoration: const InputDecoration(
                              labelText: 'Tên hiển thị',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _isLoading
                              ? const CircularProgressIndicator()
                              : Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () => _updateProfile(user.uid),
                                        child: const Text('Lưu'),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () {
                                          setState(() => _isEditing = false);
                                        },
                                        child: const Text('Hủy'),
                                      ),
                                    ),
                                  ],
                                ),
                        ],
                      )
                    : Column(
                        children: [
                          Center(
                            child: Text(
                              displayName.isNotEmpty
                                  ? displayName
                                  : 'Chưa có tên hiển thị',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: Text(
                              email,
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.edit),
                              label: const Text('Chỉnh sửa thông tin'),
                              onPressed: () {
                                setState(() => _isEditing = true);
                              },
                            ),
                          ),
                        ],
                      ),
                const SizedBox(height: 40),
                Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: _buildThemeSwitcher(context),
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.lock_reset),
                    label: const Text(
                      'Thay đổi mật khẩu',
                      style: TextStyle(fontSize: 18),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ChangePasswordScreen(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.logout),
                    label: const Text(
                      'Đăng xuất',
                      style: TextStyle(fontSize: 18),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () async {
                      await AuthService().signOut();
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}