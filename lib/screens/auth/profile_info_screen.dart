import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/auth_service.dart';

class ProfileInfoScreen extends StatefulWidget {
  const ProfileInfoScreen({super.key});

  @override
  State<ProfileInfoScreen> createState() => _ProfileInfoScreenState();
}

class _ProfileInfoScreenState extends State<ProfileInfoScreen> {
  final _displayNameController = TextEditingController();
  File? _avatarFile;
  bool _isUploading = false;
  final String _defaultAvatar = 'https://res.cloudinary.com/ddfzzvwvx/image/upload/v1749923335/download_iqse1o.jpg';

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 512, maxHeight: 512);
    if (pickedFile != null) {
      setState(() {
        _avatarFile = File(pickedFile.path);
      });
    }
  }

  Future<String> _uploadAvatar(File image) async {
    final cloudinary = CloudinaryPublic('ddfzzvwvx', 'flutter_uploads', cache: false);
    setState(() => _isUploading = true);
    try {
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(image.path, resourceType: CloudinaryResourceType.Image),
      );
      return response.secureUrl;
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _saveProfile() async {
    final user = AuthService().currentUser;
    if (user == null) return;
    String avatarUrl = _defaultAvatar;
    if (_avatarFile != null) {
      avatarUrl = await _uploadAvatar(_avatarFile!);
    }
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'displayName': _displayNameController.text.trim(),
      'avatar': avatarUrl,
    });
    if (!mounted) return;
    Navigator.pop(context); // hoặc chuyển về HomeScreen
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thông tin cá nhân')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            InkWell(
              onTap: _pickAvatar,
              child: CircleAvatar(
                radius: 48,
                backgroundImage: _avatarFile != null
                    ? FileImage(_avatarFile!)
                    : NetworkImage(_defaultAvatar) as ImageProvider,
                child: _isUploading
                    ? const CircularProgressIndicator()
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _displayNameController,
              decoration: const InputDecoration(labelText: 'Tên hiển thị', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isUploading ? null : _saveProfile,
              child: const Text('Lưu thông tin'),
            ),
          ],
        ),
      ),
    );
  }
}