import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
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
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
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
        ref = await FirebaseFirestore.instance
            .collection('subscriptions')
            .add(subscriptionData);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã thêm thành công!')));
      }

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

  Widget _buildInputSection({
    required String label,
    required Widget child,
    IconData? icon,
    double spacing = 12,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: EdgeInsets.only(bottom: spacing),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: colorScheme.surfaceVariant.withOpacity(0.35),
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.10),
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(icon, color: colorScheme.primary, size: 22),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    )),
                const SizedBox(height: 4),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePicker() {
    final colorScheme = Theme.of(context).colorScheme;
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorScheme.surfaceVariant.withOpacity(0.38),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withOpacity(0.18),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _imageFile != null
              ? ClipOval(
                  child: Image.file(
                    _imageFile!,
                    fit: BoxFit.cover,
                    width: 110,
                    height: 110,
                  ),
                )
              : widget.initialData?['iconUrl'] != null &&
                      widget.initialData?['iconUrl'] != ''
                  ? ClipOval(
                      child: Image.network(
                        widget.initialData!['iconUrl'],
                        fit: BoxFit.cover,
                        width: 110,
                        height: 110,
                      ),
                    )
                  : Center(
                      child: Icon(Icons.add_photo_alternate_outlined,
                          color: colorScheme.primary, size: 42),
                    ),
        ),
        if (_isUploading)
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: Colors.black38,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            ),
          ),
        if (!_isUploading)
          Positioned(
            bottom: 4,
            right: 8,
            child: InkWell(
              onTap: _pickImage,
              borderRadius: BorderRadius.circular(40),
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(Icons.camera_alt, color: colorScheme.onPrimary, size: 18),
              ),
            ),
          ),
      ],
    );
  }

  /// Build the row for amount & currency with equal height, no overflow, compact currency field
  Widget _buildAmountCurrencyRow() {
    final colorScheme = Theme.of(context).colorScheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Amount
          Expanded(
            flex: 3,
            child: _buildInputSection(
              label: 'Giá',
              icon: Icons.attach_money,
              child: TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  hintText: '0',
                  border: InputBorder.none,
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Nhập giá';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Chỉ nhập số';
                  }
                  return null;
                },
                style: const TextStyle(fontSize: 15),
              ),
              spacing: 0,
            ),
          ),
          const SizedBox(width: 10),
          // Currency - compact, same height as amount
          Container(
            margin: const EdgeInsets.only(bottom: 0),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: colorScheme.surfaceVariant.withOpacity(0.35),
              border: Border.all(
                color: colorScheme.primary.withOpacity(0.10),
                width: 1.2,
              ),
            ),
            width: 90,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tiền tệ',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    )),
                DropdownButtonFormField<String>(
                  value: _selectedCurrency,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  items: _currencies
                      .map(
                        (e) => DropdownMenuItem(
                          value: e['value'],
                          child: Text(
                            e['value']!, // chỉ hiện mã tiền tệ
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCurrency = value!;
                    });
                  },
                  style: const TextStyle(fontSize: 15),
                  menuMaxHeight: 300,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(widget.subscriptionId != null ? 'Chỉnh sửa dịch vụ' : 'Thêm dịch vụ'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isUploading ? null : _saveSubscription,
            tooltip: 'Lưu',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Center(child: _buildImagePicker()),
              const SizedBox(height: 24),

              _buildInputSection(
                label: 'Tên dịch vụ',
                icon: Icons.apps_rounded,
                child: TextFormField(
                  controller: _serviceNameController,
                  decoration: const InputDecoration(
                    hintText: 'Nhập tên dịch vụ (VD: Netflix, Spotify...)',
                    border: InputBorder.none,
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Vui lòng nhập tên dịch vụ'
                      : null,
                  style: const TextStyle(fontSize: 15),
                ),
              ),

              _buildAmountCurrencyRow(),
              const SizedBox(height: 12),

              _buildInputSection(
                label: 'Chu kỳ thanh toán',
                icon: Icons.repeat_rounded,
                child: DropdownButtonFormField<String>(
                  value: _selectedPeriod,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  items: _periods
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
                  style: const TextStyle(fontSize: 15),
                ),
              ),

              _buildInputSection(
                label: 'Ngày thanh toán tiếp theo',
                icon: Icons.calendar_month_outlined,
                child: InkWell(
                  onTap: () => _selectDate(context),
                  borderRadius: BorderRadius.circular(7),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      hintText: 'Chọn ngày thanh toán',
                      border: InputBorder.none,
                    ),
                    child: Text(
                      _selectedDate == null
                          ? 'Chưa chọn ngày'
                          : DateFormat('dd/MM/yyyy').format(_selectedDate!),
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                ),
              ),

              _buildInputSection(
                label: 'Ghi chú (tuỳ chọn)',
                icon: Icons.edit_note_rounded,
                child: TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    hintText: 'Thêm ghi chú cho dịch vụ này...',
                    border: InputBorder.none,
                  ),
                  maxLines: 3,
                  style: const TextStyle(fontSize: 15),
                ),
              ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save_alt_rounded, size: 20),
                  label: Text(
                    widget.subscriptionId != null ? 'Lưu thay đổi' : 'Thêm mới',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  onPressed: _isUploading ? null : _saveSubscription,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 1,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}