import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../services/auth_service.dart';
import 'add_subscription_screen.dart';
import 'subscription_detail_screen.dart';
import '../profile/profile_screen.dart';
import '../../utils/notification_helper.dart';

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
  List<QueryDocumentSnapshot>? _subscriptionsForSelectedDay;

  @override
  void initState() {
    super.initState();
    _checkAndUpdateExpiredPayments();
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
      // Đã loại bỏ hoàn toàn phần gửi thông báo ở đây
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

      // Lên lịch notification cho kỳ tiếp theo:
      await NotificationHelper.scheduleNotification(
        id: document.id.hashCode,
        title: 'Sắp đến hạn thanh toán!',
        body:
            'Bạn có khoản thanh toán "${data['serviceName']}" vào ngày ${DateFormat('dd/MM/yyyy').format(updatedDate)}.',
        scheduledDate: updatedDate.subtract(const Duration(days: 1)),
      );
    }
  }

  void _showPaymentsForDay(DateTime day, List<QueryDocumentSnapshot> allDocs) {
    final filtered =
        allDocs.where((doc) {
          final data = doc.data()! as Map<String, dynamic>;
          final nextDate = (data['nextPaymentDate'] as Timestamp?)?.toDate();
          return nextDate != null &&
              nextDate.year == day.year &&
              nextDate.month == day.month &&
              nextDate.day == day.day;
        }).toList();

    setState(() {
      _selectedDay = day;
      _subscriptionsForSelectedDay = filtered;
      _focusedDay = day;
    });
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

          return RefreshIndicator(
            onRefresh: () async {
              await _checkAndUpdateExpiredPayments();
              setState(() {});
            },
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
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

                final paymentDates =
                    docs
                        .map(
                          (doc) =>
                              (doc['nextPaymentDate'] as Timestamp?)?.toDate(),
                        )
                        .whereType<DateTime>()
                        .toSet();

                if (_paymentDays != paymentDates) {
                  _paymentDays = paymentDates;
                }

                if (_selectedDay != null) {
                  List<QueryDocumentSnapshot> subscriptions =
                      _subscriptionsForSelectedDay ??
                      docs.where((doc) {
                        final data = doc.data()! as Map<String, dynamic>;
                        final nextDate =
                            (data['nextPaymentDate'] as Timestamp?)?.toDate();
                        return nextDate != null &&
                            nextDate.year == _selectedDay!.year &&
                            nextDate.month == _selectedDay!.month &&
                            nextDate.day == _selectedDay!.day;
                      }).toList();

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                          top: 16,
                          bottom: 8,
                          left: 16,
                          right: 16,
                        ),
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
                      _buildCalendar(paymentDates, theme, docs),
                      Padding(
                        padding: const EdgeInsets.only(
                          top: 12,
                          left: 16,
                          right: 16,
                          bottom: 8,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Các khoản thanh toán ngày: '
                                '${_selectedDay!.day}/${_selectedDay!.month}/${_selectedDay!.year}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _selectedDay = null;
                                  _subscriptionsForSelectedDay = null;
                                });
                              },
                              child: const Text('Xem tất cả'),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child:
                            subscriptions.isEmpty
                                ? const Center(
                                  child: Text(
                                    'Không có khoản thanh toán nào trong ngày này.',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey,
                                    ),
                                  ),
                                )
                                : ListView.separated(
                                  padding: const EdgeInsets.all(16.0),
                                  itemCount: subscriptions.length,
                                  separatorBuilder:
                                      (_, __) => const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final document = subscriptions[index];
                                    final data =
                                        document.data()!
                                            as Map<String, dynamic>;

                                    final nextDate =
                                        (data['nextPaymentDate'] as Timestamp?)
                                            ?.toDate();
                                    final formattedDate =
                                        (nextDate != null)
                                            ? '${nextDate.day}/${nextDate.month}/${nextDate.year}'
                                            : 'Chưa có ngày';

                                    final amount = data['amount'] ?? 0;
                                    final currency =
                                        (data['currency'] ?? 'VND').toString();
                                    final formattedAmount = getFormattedAmount(
                                      amount,
                                      currency,
                                    );

                                    return Dismissible(
                                      key: Key(document.id),
                                      direction: DismissDirection.endToStart,
                                      background: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 3,
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: Container(
                                            alignment: Alignment.centerRight,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 20,
                                            ),
                                            color: Colors.red,
                                            child: const Icon(
                                              Icons.delete,
                                              color: Colors.white,
                                              size: 32,
                                            ),
                                          ),
                                        ),
                                      ),
                                      confirmDismiss: (direction) async {
                                        return await showDialog<bool>(
                                          context: context,
                                          builder:
                                              (context) => AlertDialog(
                                                title: const Text(
                                                  'Xác nhận xoá',
                                                ),
                                                content: Text(
                                                  'Bạn có chắc muốn xoá "${data['serviceName'] ?? 'Không có tên'}"?',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed:
                                                        () => Navigator.of(
                                                          context,
                                                        ).pop(false),
                                                    child: const Text('Huỷ'),
                                                  ),
                                                  TextButton(
                                                    onPressed:
                                                        () => Navigator.of(
                                                          context,
                                                        ).pop(true),
                                                    child: const Text(
                                                      'Xoá',
                                                      style: TextStyle(
                                                        color: Colors.red,
                                                      ),
                                                    ),
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
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Đã xoá "${data['serviceName'] ?? 'Không có tên'}"',
                                            ),
                                          ),
                                        );
                                      },
                                      child: Material(
                                        elevation: 3,
                                        borderRadius: BorderRadius.circular(12),
                                        color: theme.colorScheme.surface,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder:
                                                    (context) =>
                                                        SubscriptionDetailScreen(
                                                          subscriptionId:
                                                              document.id,
                                                          data: data,
                                                        ),
                                              ),
                                            );
                                          },
                                          child: ListTile(
                                            tileColor: Colors.transparent,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  vertical: 8,
                                                  horizontal: 16,
                                                ),
                                            leading: CircleAvatar(
                                              radius: 25,
                                              backgroundColor:
                                                  theme
                                                      .colorScheme
                                                      .surfaceVariant,
                                              backgroundImage:
                                                  (data['iconUrl'] != null &&
                                                          data['iconUrl']
                                                              .isNotEmpty)
                                                      ? NetworkImage(
                                                        data['iconUrl'],
                                                      )
                                                      : null,
                                              child:
                                                  (data['iconUrl'] == null ||
                                                          data['iconUrl']
                                                              .isEmpty)
                                                      ? const Icon(
                                                        Icons
                                                            .wallet_giftcard_rounded,
                                                        color: Colors.grey,
                                                      )
                                                      : null,
                                            ),
                                            title: Text(
                                              data['serviceName'] ??
                                                  'Không có tên',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color:
                                                    theme
                                                        .textTheme
                                                        .bodyLarge
                                                        ?.color,
                                              ),
                                            ),
                                            subtitle: Text(
                                              'Đến hạn: $formattedDate\nSố tiền: $formattedAmount',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color:
                                                    theme
                                                        .textTheme
                                                        .bodyMedium
                                                        ?.color,
                                              ),
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
                      _buildCalendar(<DateTime>{}, theme, docs),
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
                        top: 16,
                        bottom: 8,
                        left: 16,
                        right: 16,
                      ),
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
                    _buildCalendar(paymentDates, theme, docs),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final document = docs[index];
                          final data = document.data()! as Map<String, dynamic>;

                          final nextDate =
                              (data['nextPaymentDate'] as Timestamp?)?.toDate();
                          final formattedDate =
                              (nextDate != null)
                                  ? '${nextDate.day}/${nextDate.month}/${nextDate.year}'
                                  : 'Chưa có ngày';

                          final amount = data['amount'] ?? 0;
                          final currency =
                              (data['currency'] ?? 'VND').toString();
                          final formattedAmount = getFormattedAmount(
                            amount,
                            currency,
                          );

                          return Dismissible(
                            key: Key(document.id),
                            direction: DismissDirection.endToStart,
                            background: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  color: Colors.red,
                                  child: const Icon(
                                    Icons.delete,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                              ),
                            ),
                            confirmDismiss: (direction) async {
                              return await showDialog<bool>(
                                context: context,
                                builder:
                                    (context) => AlertDialog(
                                      title: const Text('Xác nhận xoá'),
                                      content: Text(
                                        'Bạn có chắc muốn xoá "${data['serviceName'] ?? 'Không có tên'}"?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed:
                                              () => Navigator.of(
                                                context,
                                              ).pop(false),
                                          child: const Text('Huỷ'),
                                        ),
                                        TextButton(
                                          onPressed:
                                              () => Navigator.of(
                                                context,
                                              ).pop(true),
                                          child: const Text(
                                            'Xoá',
                                            style: TextStyle(color: Colors.red),
                                          ),
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
                                    'Đã xoá "${data['serviceName'] ?? 'Không có tên'}"',
                                  ),
                                ),
                              );
                            },
                            child: Material(
                              elevation: 3,
                              borderRadius: BorderRadius.circular(12),
                              color: theme.colorScheme.surface,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
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
                                child: ListTile(
                                  tileColor: Colors.transparent,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 16,
                                  ),
                                  leading: CircleAvatar(
                                    radius: 25,
                                    backgroundColor:
                                        theme.colorScheme.surfaceVariant,
                                    backgroundImage:
                                        (data['iconUrl'] != null &&
                                                data['iconUrl'].isNotEmpty)
                                            ? NetworkImage(data['iconUrl'])
                                            : null,
                                    child:
                                        (data['iconUrl'] == null ||
                                                data['iconUrl'].isEmpty)
                                            ? const Icon(
                                              Icons.wallet_giftcard_rounded,
                                              color: Colors.grey,
                                            )
                                            : null,
                                  ),
                                  title: Text(
                                    data['serviceName'] ?? 'Không có tên',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: theme.textTheme.bodyLarge?.color,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Đến hạn: $formattedDate\nSố tiền: $formattedAmount',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: theme.textTheme.bodyMedium?.color,
                                    ),
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
      floatingActionButton: Stack(
        children: [
          Positioned(
            bottom: 80,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'testNotification',
              mini: true,
              tooltip: 'Gửi thông báo test',
              child: const Icon(Icons.notifications_active),
              onPressed: () async {
                await NotificationHelper.showNow(
                  id: 9999,
                  title: 'Thông báo test',
                  body: 'Đây là thông báo local notification test!',
                );
              },
            ),
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
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
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar(
    Set<DateTime> paymentDates,
    ThemeData theme,
    List<QueryDocumentSnapshot> allDocs,
  ) {
    return TableCalendar(
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2100, 12, 31),
      focusedDay: _focusedDay,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      onDaySelected: (selectedDay, focusedDay) {
        _showPaymentsForDay(selectedDay, allDocs);
      },
      calendarBuilders: CalendarBuilders(
        markerBuilder: (context, date, _) {
          final hasPayment = paymentDates.any(
            (d) =>
                d.year == date.year &&
                d.month == date.month &&
                d.day == date.day,
          );
          if (hasPayment) {
            return Positioned(
              bottom: 1,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.error,
                ),
              ),
            );
          }
          return null;
        },
      ),
      calendarStyle: CalendarStyle(
        markerDecoration: BoxDecoration(
          color: theme.colorScheme.error,
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
