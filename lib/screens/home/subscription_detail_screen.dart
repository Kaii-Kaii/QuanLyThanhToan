import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import '../../utils/notification_helper.dart';
import '../../services/auth_service.dart';

class SubscriptionDetailScreen extends StatefulWidget {
  final String subscriptionId;
  final Map<String, dynamic> data;

  const SubscriptionDetailScreen({
    super.key,
    required this.subscriptionId,
    required this.data,
  });

  @override
  State<SubscriptionDetailScreen> createState() =>
      _SubscriptionDetailScreenState();
}

class _SubscriptionDetailScreenState extends State<SubscriptionDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serviceNameController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedCurrency = 'VND';
  String _selectedCycle = 'monthly';
  DateTime _nextPaymentDate = DateTime.now();

  bool _isEditing = false;
  bool _isLoading = false;
  bool _isUploadingIcon = false;
  File? _iconFile;

  String _planType = 'personal';

  final List<Map<String, String>> _currencies = [
    {'code': 'VND', 'name': '₫'},
    {'code': 'USD', 'name': '\$'},
    {'code': 'EUR', 'name': '€'},
    {'code': 'JPY', 'name': '¥'},
    {'code': 'KRW', 'name': '₩'},
    {'code': 'CNY', 'name': '¥'},
    {'code': 'GBP', 'name': '£'},
    {'code': 'SGD', 'name': 'S\$'},
    {'code': 'THB', 'name': '฿'},
  ];

  final List<Map<String, String>> _cycles = [
    {'value': 'monthly', 'label': 'Hàng tháng'},
    {'value': 'yearly', 'label': 'Hàng năm'},
  ];

  @override
  void dispose() {
    _serviceNameController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _loadDataToControllers(Map<String, dynamic> data) {
    _serviceNameController.text = data['serviceName'] ?? '';
    _amountController.text = (data['amount'] ?? 0).toString();
    _notesController.text = data['notes'] ?? '';
    _selectedCurrency = data['currency'] ?? 'VND';
    _selectedCycle = data['paymentCycle'] ?? 'monthly';
    if (data['nextPaymentDate'] != null) {
      _nextPaymentDate = (data['nextPaymentDate'] as Timestamp).toDate();
    }
    _planType = data['planType'] ?? 'personal';
  }

  Future<void> _pickIcon() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (pickedFile != null) {
      setState(() {
        _iconFile = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadIcon(File image) async {
    setState(() => _isUploadingIcon = true);
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi upload ảnh: $e')));
      }
      return null;
    } finally {
      setState(() => _isUploadingIcon = false);
    }
  }

  Future<void> _updateSubscription(Map<String, dynamic> currentData) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      String? iconUrl = currentData['iconUrl'];
      if (_iconFile != null) {
        final uploadedUrl = await _uploadIcon(_iconFile!);
        if (uploadedUrl != null) {
          iconUrl = uploadedUrl;
        }
      }

      final updateData = {
        'serviceName': _serviceNameController.text.trim(),
        'amount': double.tryParse(_amountController.text) ?? 0,
        'currency': _selectedCurrency,
        'paymentCycle': _selectedCycle,
        'nextPaymentDate': Timestamp.fromDate(_nextPaymentDate),
        'notes': _notesController.text.trim(),
        'updatedAt': Timestamp.now(),
        'planType': _planType,
      };
      if (iconUrl != null && iconUrl.isNotEmpty) {
        updateData['iconUrl'] = iconUrl;
      }

      await FirebaseFirestore.instance
          .collection('subscriptions')
          .doc(widget.subscriptionId)
          .update(updateData);

      // Handle plan type change
      final oldPlanType = currentData['planType'] ?? 'personal';
      if (oldPlanType == 'family' && _planType == 'personal') {
        // Remove all members (except owner)
        final members = await FirebaseFirestore.instance
            .collection('subscription_members')
            .where('subscriptionId', isEqualTo: widget.subscriptionId)
            .where('role', isEqualTo: 'member')
            .get();
        for (final doc in members.docs) {
          await doc.reference.delete();
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã chuyển về gói cá nhân và xoá các thành viên!'),
            ),
          );
        }
      }
      // Add owner to subscription_members if switch to family
      if (oldPlanType == 'personal' && _planType == 'family') {
        final ownerId = currentData['userId'];
        final memberQuery = await FirebaseFirestore.instance
            .collection('subscription_members')
            .where('subscriptionId', isEqualTo: widget.subscriptionId)
            .where('userId', isEqualTo: ownerId)
            .where('role', isEqualTo: 'owner')
            .get();
        if (memberQuery.docs.isEmpty) {
          await FirebaseFirestore.instance
              .collection('subscription_members')
              .add({
            'subscriptionId': widget.subscriptionId,
            'userId': ownerId,
            'role': 'owner',
            'ownerId': ownerId,
            'joinedAt': Timestamp.now(),
          });
        }
      }

      if (mounted) {
        setState(() {
          _isEditing = false;
          _iconFile = null;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Cập nhật thành công!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: ${e.toString()}')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _nextPaymentDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (pickedDate != null) {
      setState(() {
        _nextPaymentDate = pickedDate;
      });
    }
  }

  String getFormattedAmount(num amount, String currency) {
    switch (currency) {
      case 'USD':
        return NumberFormat.currency(
          locale: 'en_US',
          symbol: '\$',
        ).format(amount);
      case 'EUR':
        return NumberFormat.currency(
          locale: 'en_EU',
          symbol: '€',
        ).format(amount);
      case 'JPY':
        return NumberFormat.currency(
          locale: 'ja_JP',
          symbol: '¥',
        ).format(amount);
      case 'KRW':
        return NumberFormat.currency(
          locale: 'ko_KR',
          symbol: '₩',
        ).format(amount);
      case 'CNY':
        return NumberFormat.currency(
          locale: 'zh_CN',
          symbol: '¥',
        ).format(amount);
      case 'GBP':
        return NumberFormat.currency(
          locale: 'en_GB',
          symbol: '£',
        ).format(amount);
      case 'SGD':
        return NumberFormat.currency(
          locale: 'en_SG',
          symbol: r'S$',
        ).format(amount);
      case 'THB':
        return NumberFormat.currency(
          locale: 'th_TH',
          symbol: '฿',
        ).format(amount);
      case 'VND':
      default:
        return NumberFormat.currency(
          locale: 'vi_VN',
          symbol: '₫',
        ).format(amount);
    }
  }

  String getVietnameseCycle(String? cycle) {
    switch (cycle) {
      case 'monthly':
        return 'Hàng tháng';
      case 'yearly':
        return 'Hàng năm';
      default:
        return '';
    }
  }

  String getPlanTypeLabel(String planType) {
    switch (planType) {
      case 'family':
        return 'Gói gia đình';
      default:
        return 'Gói cá nhân';
    }
  }

  Widget _buildAmountCurrencyInfo(String formattedAmount, String currency) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: colorScheme.surfaceVariant.withOpacity(0.35),
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.10),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Giá',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formattedAmount,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: colorScheme.surfaceVariant.withOpacity(0.35),
              border: Border.all(
                color: colorScheme.primary.withOpacity(0.10),
                width: 1.2,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: currency,
                isDense: true,
                items:
                    _currencies
                        .map(
                          (e) => DropdownMenuItem(
                            value: e['code'],
                            child: Text(
                              e['code']!,
                              style: const TextStyle(fontSize: 15),
                            ),
                          ),
                        )
                        .toList(),
                onChanged: null,
                style: const TextStyle(fontSize: 15),
                dropdownColor: colorScheme.surface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection({
    required String label,
    required String value,
    IconData? icon,
    bool isMultiLine = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
                Text(
                  value,
                  style: const TextStyle(fontSize: 15),
                  maxLines: isMultiLine ? 3 : 1,
                  overflow: isMultiLine ? TextOverflow.ellipsis : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePicker(Map<String, dynamic> data) {
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
              _iconFile != null
                  ? ClipOval(
                    child: Image.file(
                      _iconFile!,
                      fit: BoxFit.cover,
                      width: 110,
                      height: 110,
                    ),
                  )
                  : data['iconUrl'] != null && data['iconUrl'] != ''
                  ? ClipOval(
                    child: Image.network(
                      data['iconUrl'],
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
        if (_isUploadingIcon)
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
        if (!_isUploadingIcon)
          Positioned(
            bottom: 4,
            right: 8,
            child: InkWell(
              onTap: _pickIcon,
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

  Widget _buildAmountCurrencyEditRow() {
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
                              value: e['code'],
                              child: Text(
                                e['code']!,
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

  Widget _buildPlanTypeSelector(String oldPlanType) {
    return Row(
      children: [
        const Text('Loại gói:'),
        const SizedBox(width: 16),
        DropdownButton<String>(
          value: _planType,
          items: const [
            DropdownMenuItem(value: 'personal', child: Text('Cá nhân')),
            DropdownMenuItem(value: 'family', child: Text('Gia đình')),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _planType = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildEditingView(Map<String, dynamic> data) {
    final colorScheme = Theme.of(context).colorScheme;
    final oldPlanType = data['planType'] ?? 'personal';
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Center(child: _buildImagePicker(data)),
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
            _buildAmountCurrencyEditRow(),
            const SizedBox(height: 12),
            _buildInputSection(
              label: 'Chu kỳ thanh toán',
              icon: Icons.repeat_rounded,
              child: DropdownButtonFormField<String>(
                value: _selectedCycle,
                isExpanded: true,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                ),
                items:
                    _cycles
                        .map(
                          (e) => DropdownMenuItem(
                            value: e['value'],
                            child: Text(e['label']!),
                          ),
                        )
                        .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCycle = value!;
                  });
                },
                style: const TextStyle(fontSize: 15),
              ),
            ),
            _buildInputSection(
              label: 'Ngày thanh toán tiếp theo',
              icon: Icons.calendar_month_outlined,
              child: InkWell(
                onTap: _selectDate,
                borderRadius: BorderRadius.circular(7),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    hintText: 'Chọn ngày thanh toán',
                    border: InputBorder.none,
                  ),
                  child: Text(
                    DateFormat('dd/MM/yyyy').format(_nextPaymentDate),
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
            const SizedBox(height: 12),
            _buildPlanTypeSelector(oldPlanType),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _isLoading
                            ? null
                            : () {
                              setState(() {
                                _isEditing = false;
                                _iconFile = null;
                              });
                            },
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      side: BorderSide(color: colorScheme.primary),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Hủy', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        _isLoading ? null : () => _updateSubscription(data),
                    icon:
                        _isLoading
                            ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.save_alt_rounded, size: 20),
                    label: const Text(
                      'Lưu thay đổi',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 1,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
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

  Widget _buildViewingMode(Map<String, dynamic> data, {bool isOwner = false}) {
    String formattedDate = 'Chưa có ngày';
    if (data['nextPaymentDate'] != null) {
      final nextDate = (data['nextPaymentDate'] as Timestamp).toDate();
      formattedDate = DateFormat('dd/MM/yyyy').format(nextDate);
    }
    final amount = data['amount'] ?? 0;
    final currency = (data['currency'] ?? 'VND').toString();
    final formattedAmount = getFormattedAmount(amount, currency);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Center(
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(
                  context,
                ).colorScheme.surfaceVariant.withOpacity(0.38),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child:
                  data['iconUrl'] != null && data['iconUrl'].isNotEmpty
                      ? ClipOval(
                        child: Image.network(
                          data['iconUrl'],
                          fit: BoxFit.cover,
                          width: 110,
                          height: 110,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.wallet_giftcard_rounded,
                              size: 44,
                              color: Theme.of(context).colorScheme.primary,
                            );
                          },
                        ),
                      )
                      : Icon(
                        Icons.wallet_giftcard_rounded,
                        size: 44,
                        color: Theme.of(context).colorScheme.primary,
                      ),
            ),
          ),
          const SizedBox(height: 24),
          // LOẠI GÓI: family/personal
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                data['planType'] == 'family'
                    ? Icons.groups
                    : Icons.person_outline,
                color: Theme.of(context).colorScheme.primary,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                getPlanTypeLabel(data['planType']),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoSection(
            label: 'Tên dịch vụ',
            value: data['serviceName'] ?? '',
            icon: Icons.apps_rounded,
          ),
          _buildAmountCurrencyInfo(formattedAmount, currency),
          _buildInfoSection(
            label: 'Chu kỳ thanh toán',
            value: getVietnameseCycle(data['paymentCycle']),
            icon: Icons.repeat_rounded,
          ),
          _buildInfoSection(
            label: 'Ngày thanh toán tiếp theo',
            value: formattedDate,
            icon: Icons.calendar_month_outlined,
          ),
          if (data['notes'] != null &&
              data['notes'].toString().trim().isNotEmpty)
            _buildInfoSection(
              label: 'Ghi chú',
              value: data['notes'],
              icon: Icons.edit_note_rounded,
              isMultiLine: true,
            ),
          const SizedBox(height: 20),
          if ((data['planType'] ?? '') == 'family') ...[
            if (isOwner) _buildAddMemberSection(),
            const SizedBox(height: 12),
            _buildMemberList(data['userId']),
          ],
        ],
      ),
    );
  }

  Future<void> _addMemberByUid(String uid) async {
    try {
      // Lấy ownerId từ subscription
      final subDoc =
          await FirebaseFirestore.instance
              .collection('subscriptions')
              .doc(widget.subscriptionId)
              .get();
      final ownerId = subDoc['userId'];

      await FirebaseFirestore.instance.collection('subscription_members').add({
        'subscriptionId': widget.subscriptionId,
        'userId': uid,
        'role': 'member',
        'ownerId': ownerId,
        'joinedAt': Timestamp.now(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã thêm thành viên thành công!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  Widget _buildAddMemberSection() {
    final _uidController = TextEditingController();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _uidController,
              decoration: const InputDecoration(
                labelText: 'Nhập UID thành viên',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              final uid = _uidController.text.trim();
              if (uid.isNotEmpty) {
                _addMemberByUid(uid);
                _uidController.clear();
              }
            },
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberList(String ownerId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('subscription_members')
          .where('subscriptionId', isEqualTo: widget.subscriptionId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final members = snapshot.data!.docs;

        if (members.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Chưa có thành viên nào.'),
          );
        }

        // Put owner on top if found, otherwise keep original order
        QueryDocumentSnapshot? ownerDoc;
        final ownerIndex = members.indexWhere((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['role'] == 'owner' || data['userId'] == ownerId;
        });
        if (ownerIndex != -1) {
          ownerDoc = members[ownerIndex];
        } else {
          ownerDoc = null;
        }
        final memberDocs = ownerDoc != null
            ? members.where((doc) => doc != ownerDoc).toList()
            : members.toList();

        List<QueryDocumentSnapshot> sortedList =
            ownerDoc != null ? [ownerDoc, ...memberDocs] : memberDocs;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Thành viên:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            ...sortedList.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final userId = data['userId'] ?? '';
              final role = data['role'] ?? '';
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .get(),
                builder: (context, userSnapshot) {
                  String displayName = userId;
                  String? avatarUrl;
                  if (userSnapshot.hasData && userSnapshot.data!.exists) {
                    final userData =
                        userSnapshot.data!.data() as Map<String, dynamic>;
                    displayName = userData['displayName'] ?? userId;
                    avatarUrl = userData['avatar'];
                  }
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: (avatarUrl == null || avatarUrl.isEmpty)
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(
                        displayName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            role == 'owner' ? 'Chủ sở hữu' : 'Thành viên',
                            style: TextStyle(
                              color: role == 'owner'
                                  ? Colors.blue
                                  : Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            'UID: $userId',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = AuthService().currentUser?.uid;
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('subscriptions')
          .doc(widget.subscriptionId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.data!.exists || snapshot.data!.data() == null) {
          return const Scaffold(
            body: Center(
              child: Text('Dịch vụ này đã bị xoá hoặc không tồn tại.'),
            ),
          );
        }
        final data = snapshot.data!.data() as Map<String, dynamic>;
        final isOwner = data['userId'] == currentUserId;

        // Load data to controllers when switching to editing mode
        if (_isEditing && _serviceNameController.text.isEmpty) {
          _loadDataToControllers(data);
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(_isEditing ? 'Chỉnh sửa dịch vụ' : 'Chi tiết dịch vụ'),
            actions: [
              if (!_isEditing && isOwner) ...[
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  tooltip: 'Sửa',
                  onPressed: () {
                    setState(() {
                      _isEditing = true;
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Xoá',
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder:
                          (ctx) => AlertDialog(
                            title: const Text('Xác nhận xoá'),
                            content: const Text(
                              'Bạn có chắc muốn xoá khoản này?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Huỷ'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text(
                                  'Xoá',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                    );
                    if (confirm == true) {
                      // Xoá các member liên quan
                      final members =
                          await FirebaseFirestore.instance
                              .collection('subscription_members')
                              .where(
                                'subscriptionId',
                                isEqualTo: widget.subscriptionId,
                              )
                              .get();
                      for (final doc in members.docs) {
                        await doc.reference.delete();
                      }
                      // Xoá subscription
                      await FirebaseFirestore.instance
                          .collection('subscriptions')
                          .doc(widget.subscriptionId)
                          .delete();
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đã xoá thành công!')),
                        );
                      }
                    }
                  },
                ),
              ],
            ],
          ),
          body:
              _isEditing && isOwner
                  ? _buildEditingView(data)
                  : _buildViewingMode(data, isOwner: isOwner),
        );
      },
    );
  }
}