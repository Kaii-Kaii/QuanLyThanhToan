// lib/screens/home/add_subscription_screen.dart

import 'dart:io'; // Để làm việc với đối tượng File
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';

class AddSubscriptionScreen extends StatefulWidget {
  const AddSubscriptionScreen({super.key});

  @override
  State<AddSubscriptionScreen> createState() => _AddSubscriptionScreenState();
}

class _AddSubscriptionScreenState extends State<AddSubscriptionScreen> {
  // Các controller và key cho Form
  final _formKey = GlobalKey<FormState>();
  final _serviceNameController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Các biến trạng thái
  DateTime? _selectedDate;
  String _selectedCategory = 'Entertainment';
  String _selectedPeriod = 'Monthly';
  File? _imageFile; // Biến để lưu trữ file ảnh người dùng chọn
  bool _isUploading = false; // Biến để kiểm soát trạng thái upload

  final List<String> _categories = [
    'Entertainment',
    'Productivity',
    'Music',
    'Video',
    'Gaming',
    'Education',
    'Other',
  ];

  final List<String> _periods = ['Weekly', 'Monthly', 'Yearly'];

  @override
  void dispose() {
    _serviceNameController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // --- HÀM XỬ LÝ ẢNH ---

  /// Mở thư viện ảnh để người dùng chọn
  Future<void> _pickImage() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Chọn nguồn ảnh'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.camera_alt),
                title: Text('Chụp ảnh'),
                onTap: () {
                  Navigator.pop(context);
                  _getImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text('Thư viện ảnh'),
                onTap: () {
                  Navigator.pop(context);
                  _getImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _getImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
        print('Đã chọn ảnh: ${pickedFile.path}');
      } else {
        print('Không có ảnh nào được chọn');
      }
    } catch (e) {
      print('Lỗi khi chọn ảnh: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể chọn ảnh: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Upload ảnh lên Cloudinary và trả về URL
  Future<String?> _uploadImageToCloudinary(File image) async {
    // !!! THAY THẾ THÔNG TIN CỦA BẠN VÀO ĐÂY !!!
    const cloudName = 'ddfzzvwvx'; // <--- THAY BẰNG CLOUD NAME CỦA BẠN
    const uploadPreset = 'flutter_uploads'; // Tên upload preset bạn đã tạo

    final cloudinary = CloudinaryPublic(cloudName, uploadPreset, cache: false);

    try {
      setState(() {
        _isUploading = true;
      }); // Bắt đầu hiển thị loading
      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          image.path,
          resourceType: CloudinaryResourceType.Image,
        ),
      );
      setState(() {
        _isUploading = false;
      }); // Kết thúc loading
      return response.secureUrl; // Trả về URL an toàn (https://...)
    } catch (e) {
      setState(() {
        _isUploading = false;
      }); // Kết thúc loading nếu có lỗi
      print('Lỗi upload ảnh: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload ảnh thất bại: $e')));
      return null;
    }
  }

  // --- HÀM LƯU DỮ LIỆU ---

  /// Lưu toàn bộ thông tin subscription lên Firestore
  Future<void> _saveSubscription() async {
    // Kiểm tra form có hợp lệ không
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Lấy userId
    final userId = AuthService().currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không tìm thấy người dùng! Vui lòng đăng nhập lại.'),
        ),
      );
      return;
    }

    String imageUrl = '';
    // Nếu có ảnh, upload trước
    if (_imageFile != null) {
      final uploadedUrl = await _uploadImageToCloudinary(_imageFile!);
      if (uploadedUrl == null) {
        // Dừng lại nếu upload lỗi
        return;
      }
      imageUrl = uploadedUrl;
    }

    // Chuẩn bị dữ liệu để lưu
    final subscriptionData = {
      'serviceName': _serviceNameController.text.trim(),
      'amount': double.tryParse(_amountController.text) ?? 0.0,
      'currency': 'VND',
      'paymentCycle': _selectedPeriod,
      'nextPaymentDate':
          _selectedDate != null ? Timestamp.fromDate(_selectedDate!) : null,
      'iconUrl': imageUrl, // Lưu URL ảnh đã upload
      'userId': userId,
      'createdAt': Timestamp.now(),
    };

    // Lưu lên Firestore
    try {
      await FirebaseFirestore.instance
          .collection('subscriptions')
          .add(subscriptionData);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã thêm thành công!')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lưu dữ liệu thất bại: $e')));
    }
  }

  // Hàm hiển thị Date Picker
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // --- GIAO DIỆN (BUILD WIDGET) ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thêm khoản thanh toán'),
        actions: [
          // Hiển thị vòng xoay loading nếu đang upload, ngược lại hiển thị nút Save
          if (_isUploading)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveSubscription,
              tooltip: 'Lưu',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Phần chọn ảnh
              Card(
                child: InkWell(
                  onTap: _pickImage,
                  child: Container(
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child:
                        _imageFile != null
                            ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                _imageFile!,
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            )
                            : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate,
                                  size: 50,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Chạm để thêm ảnh',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Tên subscription
              TextFormField(
                controller: _serviceNameController,
                decoration: const InputDecoration(
                  labelText: 'Tên dịch vụ',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.subscriptions),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập tên dịch vụ';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Giá
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Giá (VNĐ)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập giá';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Vui lòng nhập số hợp lệ';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Danh mục
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Danh mục',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items:
                    _categories.map((String category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedCategory = newValue!;
                  });
                },
              ),

              const SizedBox(height: 16),

              // Chu kỳ thanh toán
              DropdownButtonFormField<String>(
                value: _selectedPeriod,
                decoration: const InputDecoration(
                  labelText: 'Chu kỳ thanh toán',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.schedule),
                ),
                items:
                    _periods.map((String period) {
                      return DropdownMenuItem<String>(
                        value: period,
                        child: Text(period),
                      );
                    }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedPeriod = newValue!;
                  });
                },
              ),

              const SizedBox(height: 16),

              // Ngày thanh toán tiếp theo
              InkWell(
                onTap: () => _selectDate(context),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Ngày thanh toán tiếp theo',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    _selectedDate == null
                        ? 'Chưa chọn ngày'
                        : 'Ngày đến hạn: ${DateFormat('dd/MM/yyyy').format(_selectedDate!)}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Mô tả
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Mô tả (tùy chọn)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
              ),

              const SizedBox(height: 24),

              // Nút lưu
              ElevatedButton(
                onPressed: _saveSubscription,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Lưu Subscription',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
