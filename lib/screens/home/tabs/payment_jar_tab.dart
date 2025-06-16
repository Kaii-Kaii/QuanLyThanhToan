import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../subscription_detail_screen.dart';
import '../../../widgets/payment_jar_widget.dart';

class PaymentJarTab extends StatelessWidget {
  final String currentUserId;
  final String displayName;
  final ThemeData theme;

  const PaymentJarTab({
    super.key,
    required this.currentUserId,
    required this.displayName,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('subscriptions')
              .where('userId', isEqualTo: currentUserId)
              .orderBy('nextPaymentDate', descending: false)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Đã xảy ra lỗi: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;

        // Thay đổi từ 7 thành 10 quả bóng tối đa
        final List<QueryDocumentSnapshot> soonestPayments =
            docs.length > 10 ? docs.sublist(0, 10) : docs;

        if (soonestPayments.isEmpty) {
          return _buildEmptyJar();
        }

        return _buildJarWithBalls(context, soonestPayments, docs);
      },
    );
  }

  Widget _buildJarWithBalls(
    BuildContext context,
    List<QueryDocumentSnapshot> soonestPayments,
    List<QueryDocumentSnapshot> allDocs,
  ) {
    List<Widget> balls = List.generate(soonestPayments.length, (index) {
      final document = soonestPayments[index];
      final data = document.data()! as Map<String, dynamic>;
      final iconUrl = data['iconUrl'] ?? '';
      final serviceName = data['serviceName'] ?? '';
      final nextDate = (data['nextPaymentDate'] as Timestamp?)?.toDate();

      return Tooltip(
        message:
            "$serviceName\n${nextDate != null ? "Đến hạn: ${nextDate.day}/${nextDate.month}/${nextDate.year}" : ""}",
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) => SubscriptionDetailScreen(
                      subscriptionId: document.id,
                      data: data,
                    ),
              ),
            );
          },
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 30,
              backgroundColor: theme.colorScheme.surface,
              backgroundImage:
                  (iconUrl.isNotEmpty) ? NetworkImage(iconUrl) : null,
              child:
                  (iconUrl.isEmpty)
                      ? Icon(
                        Icons.wallet_giftcard_rounded,
                        color: theme.colorScheme.primary,
                        size: 32,
                      )
                      : null,
            ),
          ),
        ),
      );
    });

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 12),
              child: Text(
                'Xin chào${displayName.isNotEmpty ? ', $displayName' : ''}!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Lọ Thanh Toán',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${soonestPayments.length} khoản sắp tới',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 25),
            // Bỏ Container bao ngoài với nền trắng - chỉ để shadow
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: PaymentJarWidget(balls: balls, width: 280, height: 400),
            ),
            const SizedBox(height: 25),
            // Cập nhật thông báo số khoản khác
            if (allDocs.length > 10)
              _buildMorePaymentsIndicator(allDocs.length),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyJar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 20),
              child: Text(
                'Xin chào${displayName.isNotEmpty ? ', $displayName' : ''}!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Chỉ thêm shadow, không có nền màu
            Container(
              width: 220,
              height: 320,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'lib/assets/image.png',
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  // Thêm color filter chỉ cho chế độ tối
                  color:
                      theme.brightness == Brightness.dark
                          ? Colors.white.withOpacity(0.8)
                          : null,
                  colorBlendMode:
                      theme.brightness == Brightness.dark
                          ? BlendMode.modulate
                          : null,
                ),
              ),
            ),
            const SizedBox(height: 30),
            Text(
              'Lọ thanh toán đang trống!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Thêm khoản thanh toán đầu tiên của bạn\nbằng nút + bên dưới',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildMorePaymentsIndicator(int totalCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.surfaceVariant.withOpacity(0.3),
            theme.colorScheme.surfaceVariant.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.more_horiz,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            '+ ${totalCount - 10} khoản khác', // Thay đổi từ 7 thành 10
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
