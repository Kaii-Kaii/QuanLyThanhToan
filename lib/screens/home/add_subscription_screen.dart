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
  String _planType = 'personal';
  List<String> _familyMemberUids = [];
  final TextEditingController _memberUidController = TextEditingController();
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
    _memberUidController.dispose();
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

  Future<bool> _checkUserExists(String uid) async {
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return doc.exists;
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
      'planType': _planType,
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

        // Luôn thêm owner vào subscription_members (dù là cá nhân hay gia đình)
        await FirebaseFirestore.instance
            .collection('subscription_members')
            .add({
              'subscriptionId': ref.id,
              'userId': userId,
              'role': 'owner',
              'ownerId': userId,
              'joinedAt': Timestamp.now(),
            });

        // Nếu là gói gia đình, thêm các thành viên (chỉ thêm nếu tồn tại trong users)
        if (_planType == 'family') {
          for (final memberUid in _familyMemberUids) {
            if (memberUid.trim().isNotEmpty && memberUid != userId) {
              final exists = await _checkUserExists(memberUid.trim());
              if (exists) {
                await FirebaseFirestore.instance
                    .collection('subscription_members')
                    .add({
                      'subscriptionId': ref.id,
                      'userId': memberUid.trim(),
                      'role': 'member',
                      'ownerId': userId,
                      'joinedAt': Timestamp.now(),
                    });
              }
            }
          }
        }

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
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
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
          child:
              _imageFile != null
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
                    child: Icon(
                      Icons.add_photo_alternate_outlined,
                      color: colorScheme.primary,
                      size: 42,
                    ),
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
                child: Icon(
                  Icons.camera_alt,
                  color: colorScheme.onPrimary,
                  size: 18,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAmountCurrencyRow() {
    final colorScheme = Theme.of(context).colorScheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                Text(
                  'Tiền tệ',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
                DropdownButtonFormField<String>(
                  value: _selectedCurrency,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  items:
                      _currencies
                          .map(
                            (e) => DropdownMenuItem(
                              value: e['value'],
                              child: Text(
                                e['value']!,
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

  Widget _buildPlanTypeSelector() {
    final isFamily = _planType == 'family';
    final userId = AuthService().currentUser?.uid;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Loại gói:', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ToggleButtons(
          isSelected: [_planType == 'personal', _planType == 'family'],
          onPressed: (index) {
            setState(() {
              _planType = index == 0 ? 'personal' : 'family';
              if (_planType == 'personal') _familyMemberUids.clear();
            });
          },
          borderRadius: BorderRadius.circular(12),
          selectedColor: Theme.of(context).colorScheme.onPrimary,
          fillColor: Theme.of(context).colorScheme.primary,
          color: Theme.of(context).colorScheme.primary,
          constraints: const BoxConstraints(minWidth: 110, minHeight: 40),
          children: const [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('Cá nhân', style: TextStyle(fontSize: 15)),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('Gia đình', style: TextStyle(fontSize: 15)),
            ),
          ],
        ),
        if (isFamily) ...[
          const SizedBox(height: 16),
          Text(
            'Thành viên (UID):',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _memberUidController,
                  decoration: const InputDecoration(
                    hintText: 'Nhập UID thành viên',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (value) async {
                    final uid = value.trim();
                    if (uid.isEmpty) return;
                    if (uid == userId) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Không thể thêm chính bạn vào danh sách thành viên!',
                          ),
                        ),
                      );
                      return;
                    }
                    if (_familyMemberUids.contains(uid)) return;
                    final exists = await _checkUserExists(uid);
                    if (!exists) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('UID này không tồn tại!')),
                      );
                      return;
                    }
                    setState(() {
                      _familyMemberUids.add(uid);
                      _memberUidController.clear();
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  final uid = _memberUidController.text.trim();
                  if (uid.isEmpty) return;
                  if (uid == userId) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Không thể thêm chính bạn vào danh sách thành viên!',
                        ),
                      ),
                    );
                    return;
                  }
                  if (_familyMemberUids.contains(uid)) return;
                  final exists = await _checkUserExists(uid);
                  if (!exists) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('UID này không tồn tại!')),
                    );
                    return;
                  }
                  setState(() {
                    _familyMemberUids.add(uid);
                    _memberUidController.clear();
                  });
                },
                child: const Text('Thêm'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_familyMemberUids.isNotEmpty)
            Wrap(
              spacing: 8,
              children:
                  _familyMemberUids
                      .map(
                        (uid) => Chip(
                          label: Text(uid),
                          onDeleted: () {
                            setState(() {
                              _familyMemberUids.remove(uid);
                            });
                          },
                        ),
                      )
                      .toList(),
            ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          widget.subscriptionId != null ? 'Chỉnh sửa dịch vụ' : 'Thêm dịch vụ',
        ),
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
                  validator:
                      (value) =>
                          value == null || value.trim().isEmpty
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
              const SizedBox(height: 8),
              _buildPlanTypeSelector(),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save_alt_rounded, size: 20),
                  label: Text(
                    widget.subscriptionId != null ? 'Lưu thay đổi' : 'Thêm mới',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
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
