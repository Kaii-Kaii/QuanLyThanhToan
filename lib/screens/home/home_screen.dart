// lib/screens/home/home_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../services/auth_service.dart';
import 'add_subscription_screen.dart';
import 'subscription_detail_screen.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Set<DateTime> _paymentDays = {};

  @override
  void initState() {
    super.initState();
    _checkAndUpdateExpiredPayments();
  }

  Future<void> _checkAndUpdateExpiredPayments() async {
    final currentUserId = _authService.currentUser?.uid;
    if (currentUserId == null) return;

    final snapshot = await FirebaseFirestore.instance
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

    if (nextDate != null && now.isAfter(nextDate)) {
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? currentUserId = _authService.currentUser?.uid;

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
          IconButton(
            icon: const Icon(Icons.account_circle),
            tooltip: 'Thông tin cá nhân',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .get(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final userData =
              userSnapshot.data?.data() as Map<String, dynamic>? ?? {};
          final displayName = userData['displayName'] ?? '';

          return RefreshIndicator(
            onRefresh: () async {
              await _checkAndUpdateExpiredPayments();
              setState(() {});
            },
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('subscriptions')
                  .where('userId', isEqualTo: currentUserId)
                  .orderBy('nextPaymentDate', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Đã xảy ra lỗi: ${snapshot.error}'),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                final paymentDates = docs
                    .map((doc) =>
                        (doc['nextPaymentDate'] as Timestamp?)?.toDate())
                    .whereType<DateTime>()
                    .toSet();

                if (_paymentDays != paymentDates) {
                  _paymentDays = paymentDates;
                }

                if (docs.isEmpty) {
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Xin chào${displayName.isNotEmpty ? ', $displayName' : ''}!',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      _buildCalendar(<DateTime>{}),
                      const Expanded(
                        child: Center(
                          child: Text(
                            'Bạn chưa có khoản thanh toán nào.\nNhấn nút + để thêm mới!',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                          top: 16, bottom: 8, left: 16, right: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Xin chào${displayName.isNotEmpty ? ', $displayName' : ''}!',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    _buildCalendar(paymentDates),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final document = docs[index];
                          final data =
                              document.data()! as Map<String, dynamic>;

                          final nextDate = (data['nextPaymentDate']
                                  as Timestamp?)
                              ?.toDate();
                          final formattedDate = (nextDate != null)
                              ? '${nextDate.day}/${nextDate.month}/${nextDate.year}'
                              : 'Chưa có ngày';

                          final currencyFormat = NumberFormat.currency(
                            locale: 'vi_VN',
                            symbol: '₫',
                          );
                          final formattedAmount = currencyFormat
                              .format(data['amount'] ?? 0);

                          return Dismissible(
                            key: Key(document.id),
                            direction: DismissDirection.endToStart,
                            background: Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 6),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20),
                                  color: Colors.red,
                                  child: const Icon(
                                    Icons.delete,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                              ),
                            ),
                            confirmDismiss: (direction) async {
                              return await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Xác nhận xóa'),
                                  content: Text(
                                    'Bạn có chắc chắn muốn xóa "${data['serviceName'] ?? 'Không có tên'}"?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(false),
                                      child: const Text('Hủy'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(true),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.red,
                                      ),
                                      child: const Text('Xóa'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            onDismissed: (_) async {
                              await FirebaseFirestore.instance
                                  .collection('subscriptions')
                                  .doc(document.id)
                                  .delete();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Đã xóa "${data['serviceName'] ?? 'Không có tên'}"',
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            child: Material(
                              elevation: 3,
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.white,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          SubscriptionDetailScreen(
                                        subscriptionId: document.id,
                                        data: data,
                                      ),
                                    ),
                                  );
                                },
                                child: ListTile(
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 16,
                                  ),
                                  leading: CircleAvatar(
                                    radius: 25,
                                    backgroundColor:
                                        Colors.grey.shade200,
                                    backgroundImage:
                                        (data['iconUrl'] != null &&
                                                data['iconUrl'].isNotEmpty)
                                            ? NetworkImage(
                                                data['iconUrl'])
                                            : null,
                                    child: (data['iconUrl'] == null ||
                                            data['iconUrl'].isEmpty)
                                        ? const Icon(
                                            Icons.wallet_giftcard_rounded,
                                            color: Colors.grey,
                                          )
                                        : null,
                                  ),
                                  title: Text(
                                    data['serviceName'] ?? 'Không có tên',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Đến hạn: $formattedDate\nSố tiền: $formattedAmount',
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
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

  Widget _buildCalendar(Set<DateTime> paymentDates) {
    return TableCalendar(
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2100, 12, 31),
      focusedDay: _focusedDay,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });
      },
      calendarBuilders: CalendarBuilders(
        markerBuilder: (context, date, _) {
          final hasPayment = paymentDates.any((d) =>
              d.year == date.year &&
              d.month == date.month &&
              d.day == date.day);
          if (hasPayment) {
            return Positioned(
              bottom: 1,
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red,
                ),
              ),
            );
          }
          return null;
        },
      ),
      calendarStyle: const CalendarStyle(
        markerDecoration: BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
      ),
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
      ),
    );
  }
}
