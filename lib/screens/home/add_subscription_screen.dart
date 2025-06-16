import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../utils/notification_helper.dart';

class AddSubscriptionScreen extends StatefulWidget {
  final String? subscriptionId;
  final Map<String, dynamic>? initialData;

  const AddSubscriptionScreen({Key? key, this.subscriptionId, this.initialData})
    : super(key: key);

  @override
  State<AddSubscriptionScreen> createState() => _AddSubscriptionScreenState();
}

class _AddSubscriptionScreenState extends State<AddSubscriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serviceNameController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime? _selectedDate;
  String _selectedPeriod = 'monthly';
  String _selectedCurrency = 'VND';
  File? _imageFile;
  bool _isUploading = false;

  final List<Map<String, String>> _periods = [
    {'value': 'monthly', 'label': 'Hàng tháng'},
    {'value': 'yearly', 'label': 'Hàng năm'},
  ];

  final List<Map<String, String>> _currencies = [
    {'value': 'VND', 'label': 'VNĐ - Vietnamese Đồng'},
    {'value': 'USD', 'label': 'USD - US Dollar'},
    {'value': 'EUR', 'label': 'EUR - Euro'},
    {'value': 'JPY', 'label': 'JPY - Japanese Yen'},
    {'value': 'KRW', 'label': 'KRW - South Korean Won'},
    {'value': 'CNY', 'label': 'CNY - Chinese Yuan'},
    {'value': 'GBP', 'label': 'GBP - British Pound'},
    {'value': 'SGD', 'label': 'SGD - Singapore Dollar'},
    {'value': 'THB', 'label': 'THB - Thai Baht'},
  ];

  @override
  void dispose() {
    _serviceNameController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      final data = widget.initialData!;
      _serviceNameController.text = data['serviceName'] ?? '';
      _amountController.text = (data['amount']?.toString() ?? '');
      _notesController.text = data['notes'] ?? '';
      _selectedPeriod = data['paymentCycle'] ?? 'monthly';
      _selectedCurrency = data['currency'] ?? 'VND';
      if (data['nextPaymentDate'] != null) {
        _selectedDate = (data['nextPaymentDate'] as Timestamp).toDate();
      }
    }
  }

  Future<void> _pickImage() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Chọn nguồn ảnh'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Chụp ảnh'),
                onTap: () {
                  Navigator.pop(context);
                  _getImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Thư viện ảnh'),
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
      }
    } catch (e) {
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

  Future<String?> _uploadImageToCloudinary(File image) async {
    const cloudName = 'ddfzzvwvx';
    const uploadPreset = 'flutter_uploads';

    final cloudinary = CloudinaryPublic(cloudName, uploadPreset, cache: false);

    try {
      setState(() {
        _isUploading = true;
      });

      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          image.path,
          resourceType: CloudinaryResourceType.Image,
        ),
      );

      setState(() {
        _isUploading = false;
      });

      return response.secureUrl;
    } catch (e) {
      setState(() {
        _isUploading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload ảnh thất bại: $e')));
      return null;
    }
  }

  Future<void> _saveSubscription() async {
    if (!_formKey.currentState!.validate()) return;

    final userId = AuthService().currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không tìm thấy người dùng! Vui lòng đăng nhập lại.'),
        ),
      );
      return;
    }

    String imageUrl = widget.initialData?['iconUrl'] ?? '';
    if (_imageFile != null) {
      final uploadedUrl = await _uploadImageToCloudinary(_imageFile!);
      if (uploadedUrl == null) return;
      imageUrl = uploadedUrl;
    }

    final subscriptionData = {
      'serviceName': _serviceNameController.text.trim(),
      'amount': double.tryParse(_amountController.text) ?? 0.0,
      'currency': _selectedCurrency,
      'paymentCycle': _selectedPeriod,
      'nextPaymentDate':
          _selectedDate != null ? Timestamp.fromDate(_selectedDate!) : null,
      'iconUrl': imageUrl,
      'notes': _notesController.text.trim(),
      'userId': userId,
      'createdAt': widget.initialData?['createdAt'] ?? Timestamp.now(),
    };

    try {
      DocumentReference? ref;
      if (widget.subscriptionId != null) {
        // Update
        await FirebaseFirestore.instance
            .collection('subscriptions')
            .doc(widget.subscriptionId)
            .update(subscriptionData);
        ref = FirebaseFirestore.instance
            .collection('subscriptions')
            .doc(widget.subscriptionId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã cập nhật thành công!')),
        );
      } else {
        // Add mới
        ref = await FirebaseFirestore.instance
            .collection('subscriptions')
            .add(subscriptionData);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã thêm thành công!')));
      }

      // --- Schedule notification ---
      if (_selectedDate != null && ref != null) {
        final now = DateTime.now();
        final tomorrow = DateTime(now.year, now.month, now.day + 1);
        final isTomorrow =
            _selectedDate!.year == tomorrow.year &&
            _selectedDate!.month == tomorrow.month &&
            _selectedDate!.day == tomorrow.day;

        if (isTomorrow) {
          await NotificationHelper.showNow(
            id: ref.hashCode,
            title: 'Sắp đến hạn thanh toán!',
            body:
                'Bạn có khoản thanh toán "${_serviceNameController.text}" vào ngày ${DateFormat('dd/MM/yyyy').format(_selectedDate!)}.',
          );
        } else {
          final scheduledDate = _selectedDate!.subtract(
            const Duration(days: 1),
          );
          if (scheduledDate.isAfter(now)) {
            await NotificationHelper.scheduleNotification(
              id: ref.hashCode,
              title: 'Sắp đến hạn thanh toán!',
              body:
                  'Bạn có khoản thanh toán "${_serviceNameController.text}" vào ngày ${DateFormat('dd/MM/yyyy').format(_selectedDate!)}.',
              scheduledDate: scheduledDate,
            );
          }
        }
      }

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lưu dữ liệu thất bại: $e')));
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thêm đăng ký'),
        actions: [
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
            children: [
              InkWell(
                onTap: _pickImage,
                child: Container(
                  height: 180,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:
                      _imageFile != null
                          ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              _imageFile!,
                              width: double.infinity,
                              height: 180,
                              fit: BoxFit.cover,
                            ),
                          )
                          : const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate,
                                  size: 50,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Chạm để thêm ảnh',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _serviceNameController,
                decoration: const InputDecoration(
                  labelText: 'Tên dịch vụ',
                  border: OutlineInputBorder(),
                ),
                validator:
                    (value) =>
                        value == null || value.isEmpty
                            ? 'Vui lòng nhập tên dịch vụ'
                            : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: 'Giá',
                        border: OutlineInputBorder(),
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
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: _selectedCurrency,
                      decoration: const InputDecoration(
                        labelText: 'Loại tiền tệ',
                        border: OutlineInputBorder(),
                      ),
                      items:
                          _currencies
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e['value'],
                                  child: Text(e['label']!),
                                ),
                              )
                              .toList(),
                      selectedItemBuilder:
                          (context) =>
                              _currencies
                                  .map(
                                    (e) => Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        e['value']!,
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ),
                                  )
                                  .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCurrency = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedPeriod,
                decoration: const InputDecoration(
                  labelText: 'Chu kỳ thanh toán',
                  border: OutlineInputBorder(),
                ),
                items:
                    _periods
                        .map(
                          (e) => DropdownMenuItem(
                            value: e['value'],
                            child: Text(e['label']!),
                          ),
                        )
                        .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPeriod = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () => _selectDate(context),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Ngày thanh toán tiếp theo',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    _selectedDate == null
                        ? 'Chưa chọn ngày'
                        : DateFormat('dd/MM/yyyy').format(_selectedDate!),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú (tuỳ chọn)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveSubscription,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('Lưu đăng ký', style: TextStyle(fontSize: 16)),
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
