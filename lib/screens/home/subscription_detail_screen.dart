import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import '../../utils/notification_helper.dart'; // Thêm import này

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

  final List<Map<String, String>> _currencies = [
    {'code': 'VND', 'name': '₫ (VNĐ)'},
    {'code': 'USD', 'name': '\$ (USD)'},
    {'code': 'EUR', 'name': '€ (EUR)'},
    {'code': 'JPY', 'name': '¥ (JPY)'},
    {'code': 'KRW', 'name': '₩ (KRW)'},
    {'code': 'CNY', 'name': '¥ (CNY)'},
    {'code': 'GBP', 'name': '£ (GBP)'},
    {'code': 'SGD', 'name': 'S\$ (SGD)'},
    {'code': 'THB', 'name': '฿ (THB)'},
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

      // Nếu có chọn ảnh mới thì upload
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
      };

      if (iconUrl != null && iconUrl.isNotEmpty) {
        updateData['iconUrl'] = iconUrl;
      }

      await FirebaseFirestore.instance
          .collection('subscriptions')
          .doc(widget.subscriptionId)
          .update(updateData);

      // --- THÊM LẠI PHẦN THÔNG BÁO ---
      final now = DateTime.now();
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      final isTomorrow =
          _nextPaymentDate.year == tomorrow.year &&
          _nextPaymentDate.month == tomorrow.month &&
          _nextPaymentDate.day == tomorrow.day;

      if (isTomorrow) {
        // Nếu là ngày mai thì gửi thông báo ngay
        await NotificationHelper.showNow(
          id: widget.subscriptionId.hashCode,
          title: 'Sắp đến hạn thanh toán!',
          body:
              'Bạn có khoản thanh toán "${_serviceNameController.text.trim()}" vào ngày ${DateFormat('dd/MM/yyyy').format(_nextPaymentDate)}.',
        );
      } else {
        // Lên lịch thông báo trước 1 ngày
        final scheduledDate = _nextPaymentDate.subtract(
          const Duration(days: 1),
        );
        if (scheduledDate.isAfter(now)) {
          await NotificationHelper.scheduleNotification(
            id: widget.subscriptionId.hashCode,
            title: 'Sắp đến hạn thanh toán!',
            body:
                'Bạn có khoản thanh toán "${_serviceNameController.text.trim()}" vào ngày ${DateFormat('dd/MM/yyyy').format(_nextPaymentDate)}.',
            scheduledDate: scheduledDate,
          );
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

  // Helper function: Trả về định dạng tiền tệ theo từng loại currency
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

  Widget _buildEditingView(Map<String, dynamic> data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon section
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceVariant,
                    backgroundImage:
                        _iconFile != null
                            ? FileImage(_iconFile!)
                            : (data['iconUrl'] != null &&
                                data['iconUrl'].isNotEmpty)
                            ? NetworkImage(data['iconUrl'])
                            : null,
                    child:
                        (_iconFile == null &&
                                (data['iconUrl'] == null ||
                                    data['iconUrl'].isEmpty))
                            ? Icon(
                              Icons.wallet_giftcard_rounded,
                              size: 40,
                              color: Colors.grey[600],
                            )
                            : _isUploadingIcon
                            ? const CircularProgressIndicator()
                            : null,
                  ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: InkWell(
                      onTap: _isUploadingIcon ? null : _pickIcon,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.camera_alt,
                          color: Theme.of(context).colorScheme.onPrimary,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Tên dịch vụ
            TextFormField(
              controller: _serviceNameController,
              decoration: const InputDecoration(
                labelText: 'Tên dịch vụ',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Vui lòng nhập tên dịch vụ';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Số tiền và Tiền tệ
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _amountController,
                    decoration: const InputDecoration(
                      labelText: 'Số tiền',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Vui lòng nhập số tiền';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Số tiền không hợp lệ';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedCurrency,
                    decoration: const InputDecoration(
                      labelText: 'Tiền tệ',
                      border: OutlineInputBorder(),
                    ),
                    items:
                        _currencies.map((currency) {
                          return DropdownMenuItem(
                            value: currency['code'],
                            child: Text(currency['name']!),
                          );
                        }).toList(),
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

            // Chu kỳ thanh toán
            DropdownButtonFormField<String>(
              value: _selectedCycle,
              decoration: const InputDecoration(
                labelText: 'Chu kỳ thanh toán',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.schedule),
              ),
              items:
                  _cycles.map((cycle) {
                    return DropdownMenuItem(
                      value: cycle['value'],
                      child: Text(cycle['label']!),
                    );
                  }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCycle = value!;
                });
              },
            ),
            const SizedBox(height: 16),

            // Ngày đến hạn
            InkWell(
              onTap: _selectDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Ngày đến hạn',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  DateFormat('dd/MM/yyyy').format(_nextPaymentDate),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Ghi chú
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Ghi chú (tùy chọn)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 32),

            // Nút hành động
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
                    child: const Text('Hủy'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        _isLoading ? null : () => _updateSubscription(data),
                    child:
                        _isLoading
                            ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text('Đang lưu...'),
                              ],
                            )
                            : const Text('Lưu'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewingMode(Map<String, dynamic> data) {
    String formattedDate = 'Chưa có ngày';
    if (data['nextPaymentDate'] != null) {
      final nextDate = (data['nextPaymentDate'] as Timestamp).toDate();
      formattedDate = '${nextDate.day}/${nextDate.month}/${nextDate.year}';
    }

    final amount = data['amount'] ?? 0;
    final currency = (data['currency'] ?? 'VND').toString();
    final formattedAmount = getFormattedAmount(amount, currency);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (data['iconUrl'] != null && data['iconUrl'].isNotEmpty)
            Center(
              child: CircleAvatar(
                radius: 60,
                backgroundImage: NetworkImage(data['iconUrl']),
              ),
            ),
          const SizedBox(height: 24),

          _buildInfoCard(
            'Tên dịch vụ',
            data['serviceName'] ?? '',
            Icons.business,
          ),
          const SizedBox(height: 12),

          _buildInfoCard('Số tiền', formattedAmount, Icons.attach_money),
          const SizedBox(height: 12),

          _buildInfoCard(
            'Chu kỳ',
            getVietnameseCycle(data['paymentCycle']),
            Icons.schedule,
          ),
          const SizedBox(height: 12),

          _buildInfoCard('Ngày đến hạn', formattedDate, Icons.calendar_today),
          const SizedBox(height: 12),

          if (data['notes'] != null && data['notes'].isNotEmpty)
            _buildInfoCard('Ghi chú', data['notes'], Icons.note),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
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
    return StreamBuilder<DocumentSnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('subscriptions')
              .doc(widget.subscriptionId)
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final data = snapshot.data!.data() as Map<String, dynamic>;

        // Load data to controllers when switching to editing mode
        if (_isEditing && _serviceNameController.text.isEmpty) {
          _loadDataToControllers(data);
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(
              _isEditing
                  ? 'Chỉnh sửa khoản thanh toán'
                  : 'Chi tiết khoản thanh toán',
            ),
            actions: [
              if (!_isEditing) ...[
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
          body: _isEditing ? _buildEditingView(data) : _buildViewingMode(data),
        );
      },
    );
  }
}
