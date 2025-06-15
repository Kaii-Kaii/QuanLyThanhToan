import 'package:flutter/material.dart';
import 'add_subscription_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SubscriptionDetailScreen extends StatelessWidget {
  final String subscriptionId;
  final Map<String, dynamic> data;

  const SubscriptionDetailScreen({
    super.key,
    required this.subscriptionId,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    String formattedDate = 'Chưa có ngày';
    if (data['nextPaymentDate'] != null) {
      final nextDate = (data['nextPaymentDate'] as Timestamp).toDate();
      formattedDate = '${nextDate.day}/${nextDate.month}/${nextDate.year}';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết khoản thanh toán'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.blue),
            tooltip: 'Sửa',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => AddSubscriptionScreen(
                        subscriptionId: subscriptionId,
                        initialData: data,
                      ),
                ),
              );
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
                      content: const Text('Bạn có chắc muốn xoá khoản này?'),
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
                    .doc(subscriptionId)
                    .delete();
                if (context.mounted) {
                  Navigator.pop(context); // Thoát khỏi màn hình chi tiết
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã xoá thành công!')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (data['iconUrl'] != null && data['iconUrl'].isNotEmpty)
              Center(
                child: CircleAvatar(
                  radius: 40,
                  backgroundImage: NetworkImage(data['iconUrl']),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'Tên dịch vụ: ${data['serviceName'] ?? ''}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Số tiền: ${data['amount'] ?? 0} VNĐ',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Chu kỳ: ${getVietnameseCycle(data['paymentCycle'])}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Ngày đến hạn: $formattedDate',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Ghi chú: ${data['notes'] ?? ''}',
              style: const TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}
