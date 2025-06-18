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

  Future<List<String>> getMemberSubscriptionIds(String userId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('subscription_members')
        .where('userId', isEqualTo: userId)
        .get();
    return snapshot.docs
        .map((doc) => doc['subscriptionId'] as String)
        .toList();
  }

  Widget _buildWelcomeSection() {
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary.withOpacity(0.1),
            colorScheme.primary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.waving_hand, color: Colors.amber, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName.isNotEmpty
                          ? 'Xin chào, $displayName!'
                          : 'Xin chào!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Quản lý thanh toán thông minh',
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildJarSection(
    BuildContext context,
    List<QueryDocumentSnapshot> soonestPayments,
    List<QueryDocumentSnapshot> allDocs,
  ) {
    final colorScheme = theme.colorScheme;

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
                  color: colorScheme.primary.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 30,
              backgroundColor: colorScheme.surface,
              backgroundImage:
                  (iconUrl.isNotEmpty) ? NetworkImage(iconUrl) : null,
              child:
                  (iconUrl.isEmpty)
                      ? Icon(
                        Icons.wallet_giftcard_rounded,
                        color: colorScheme.primary,
                        size: 32,
                      )
                      : null,
            ),
          ),
        ),
      );
    });

    return Column(
      children: [
        // Header với thống kê
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colorScheme.surfaceVariant.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outline.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lọ Thanh Toán',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Các khoản thanh toán sắp tới',
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '${soonestPayments.length}/10',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Jar Widget với design mới
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: PaymentJarWidget(balls: balls, width: 300, height: 420),
        ),

        const SizedBox(height: 24),

        // More payments indicator
        if (allDocs.length > 10) _buildMorePaymentsIndicator(allDocs.length),
      ],
    );
  }

  Widget _buildMorePaymentsIndicator(int totalCount) {
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.surfaceVariant.withOpacity(0.3),
            colorScheme.surfaceVariant.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.more_horiz, size: 20, color: colorScheme.primary),
          const SizedBox(width: 12),
          Text(
            '+ ${totalCount - 10} khoản khác',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Xem thêm ở tab Danh sách',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: Column(  
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildWelcomeSection(),

          const SizedBox(height: 40),

          // Empty jar với design đồng nhất
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: PaymentJarWidget(
              balls: const [],
              width: 300,
              height: 420,
            ), // Sử dụng PaymentJarWidget thay vì tự tạo
          ),

          const SizedBox(height: 32),

          // Empty state message
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colorScheme.outline.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 48,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Lọ thanh toán đang trống!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Thêm khoản thanh toán đầu tiên của bạn\nbằng nút "Thêm mới" bên dưới',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: getMemberSubscriptionIds(currentUserId),
      builder: (context, memberSnapshot) {
        if (memberSnapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: theme.colorScheme.primary));
        }
        final memberSubIds = memberSnapshot.data ?? [];

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('subscriptions')
              .where(
                Filter.or(
                  Filter('userId', isEqualTo: currentUserId),
                  Filter(FieldPath.documentId, whereIn: memberSubIds.isEmpty ? ['dummy'] : memberSubIds),
                ),
              )
              .orderBy('nextPaymentDate', descending: false)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Đã xảy ra lỗi',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(color: theme.colorScheme.primary),
              );
            }

            final docs = snapshot.data!.docs;
            final List<QueryDocumentSnapshot> soonestPayments =
                docs.length > 10 ? docs.sublist(0, 10) : docs;

            if (soonestPayments.isEmpty) {
              return SingleChildScrollView(child: _buildEmptyState());
            }

            return SingleChildScrollView(
              child: Column(
                children: [
                  _buildWelcomeSection(),
                  const SizedBox(height: 16),
                  _buildJarSection(context, soonestPayments, docs),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
