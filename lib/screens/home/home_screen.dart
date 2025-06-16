import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import 'add_subscription_screen.dart';
import '../profile/profile_screen.dart';
import '../../utils/notification_helper.dart';
import 'tabs/payment_jar_tab.dart';
import 'tabs/list_calendar_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkAndUpdateExpiredPayments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkAndUpdateExpiredPayments() async {
    final currentUserId = _authService.currentUser?.uid;
    if (currentUserId == null) return;

    final snapshot =
        await FirebaseFirestore.instance
            .collection('subscriptions')
            .where('userId', isEqualTo: currentUserId)
            .get();

    for (var doc in snapshot.docs) {
      final data = doc.data();
      await _updateNextPaymentDateIfNeeded(doc, data);
    }
  }

  Future<void> _updateNextPaymentDateIfNeeded(
    DocumentSnapshot document,
    Map<String, dynamic> data,
  ) async {
    DateTime? nextDate;
    if (data['nextPaymentDate'] != null) {
      nextDate = (data['nextPaymentDate'] as Timestamp).toDate();
    }
    final now = DateTime.now();
    final yesterday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 1));

    if (nextDate != null && yesterday.isAfter(nextDate)) {
      String cycle = data['paymentCycle'] ?? 'monthly';
      DateTime updatedDate = nextDate;

      while (!updatedDate.isAfter(now)) {
        if (cycle == 'monthly') {
          updatedDate = DateTime(
            updatedDate.year,
            updatedDate.month + 1,
            updatedDate.day,
          );
        } else if (cycle == 'yearly') {
          updatedDate = DateTime(
            updatedDate.year + 1,
            updatedDate.month,
            updatedDate.day,
          );
        } else {
          break;
        }
      }

      await FirebaseFirestore.instance
          .collection('subscriptions')
          .doc(document.id)
          .update({'nextPaymentDate': Timestamp.fromDate(updatedDate)});

      await NotificationHelper.scheduleNotification(
        id: document.id.hashCode,
        title: 'Sắp đến hạn thanh toán!',
        body:
            'Bạn có khoản thanh toán "${data['serviceName']}" vào ngày ${DateFormat('dd/MM/yyyy').format(updatedDate)}.',
        scheduledDate: updatedDate.subtract(const Duration(days: 1)),
      );
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

  @override
  Widget build(BuildContext context) {
    final String? currentUserId = _authService.currentUser?.uid;
    final theme = Theme.of(context);

    if (currentUserId == null) {
      return const Scaffold(
        body: Center(
          child: Text('Không thể xác định người dùng. Vui lòng đăng nhập lại.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Các khoản thanh toán'),
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream:
                FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUserId)
                    .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return IconButton(
                  icon: const Icon(Icons.account_circle),
                  tooltip: 'Thông tin cá nhân',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    );
                  },
                );
              }

              final userData =
                  snapshot.data?.data() as Map<String, dynamic>? ?? {};
              // Thay đổi từ 'avatarUrl' thành 'avatar'
              final avatarUrl = userData['avatar'] as String?;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: theme.colorScheme.surfaceVariant,
                      backgroundImage:
                          (avatarUrl != null && avatarUrl.isNotEmpty)
                              ? NetworkImage(avatarUrl)
                              : null,
                      child:
                          (avatarUrl == null || avatarUrl.isEmpty)
                              ? Icon(
                                Icons.account_circle,
                                size: 24,
                                color: theme.colorScheme.onSurfaceVariant,
                              )
                              : null,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.sports_basketball), text: "Lọ thanh toán"),
            Tab(icon: Icon(Icons.list_alt), text: "Danh sách"),
          ],
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorPadding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('users')
                .doc(currentUserId)
                .snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final userData =
              userSnapshot.data?.data() as Map<String, dynamic>? ?? {};
          final displayName = userData['displayName'] ?? '';

          return TabBarView(
            controller: _tabController,
            children: [
              PaymentJarTab(
                currentUserId: currentUserId,
                displayName: displayName,
                theme: theme,
              ),
              ListCalendarTab(
                currentUserId: currentUserId,
                theme: theme,
                onRefresh: _checkAndUpdateExpiredPayments,
                getFormattedAmount: getFormattedAmount,
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'addSubscription',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddSubscriptionScreen(),
            ),
          );
        },
        tooltip: 'Thêm mới',
        child: const Icon(Icons.add),
      ),
    );
  }
}
