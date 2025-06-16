import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../subscription_detail_screen.dart';

class ListCalendarTab extends StatefulWidget {
  final String currentUserId;
  final ThemeData theme;
  final VoidCallback onRefresh;
  final String Function(num, String) getFormattedAmount;

  const ListCalendarTab({
    super.key,
    required this.currentUserId,
    required this.theme,
    required this.onRefresh,
    required this.getFormattedAmount,
  });

  @override
  State<ListCalendarTab> createState() => _ListCalendarTabState();
}

class _ListCalendarTabState extends State<ListCalendarTab> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Set<DateTime> _paymentDays = {};
  List<QueryDocumentSnapshot>? _subscriptionsForSelectedDay;

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

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        widget.onRefresh();
        setState(() {});
      },
      child: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('subscriptions')
                .where('userId', isEqualTo: widget.currentUserId)
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
          final paymentDates =
              docs
                  .map(
                    (doc) => (doc['nextPaymentDate'] as Timestamp?)?.toDate(),
                  )
                  .whereType<DateTime>()
                  .toSet();

          if (_paymentDays != paymentDates) {
            _paymentDays = paymentDates;
          }

          if (_selectedDay != null) {
            return _buildSelectedDayView(docs);
          }

          if (docs.isEmpty) {
            return _buildEmptyView(docs);
          }

          return _buildMainView(docs, paymentDates);
        },
      ),
    );
  }

  Widget _buildSelectedDayView(List<QueryDocumentSnapshot> docs) {
    List<QueryDocumentSnapshot> subscriptions =
        _subscriptionsForSelectedDay ??
        docs.where((doc) {
          final data = doc.data()! as Map<String, dynamic>;
          final nextDate = (data['nextPaymentDate'] as Timestamp?)?.toDate();
          return nextDate != null &&
              nextDate.year == _selectedDay!.year &&
              nextDate.month == _selectedDay!.month &&
              nextDate.day == _selectedDay!.day;
        }).toList();

    return Column(
      children: [
        _buildCalendar(_paymentDays, docs),
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
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                  : _buildSubscriptionList(subscriptions),
        ),
      ],
    );
  }

  Widget _buildEmptyView(List<QueryDocumentSnapshot> docs) {
    return Column(
      children: [
        _buildCalendar(<DateTime>{}, docs),
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

  Widget _buildMainView(
    List<QueryDocumentSnapshot> docs,
    Set<DateTime> paymentDates,
  ) {
    return Column(
      children: [
        _buildCalendar(paymentDates, docs),
        Expanded(child: _buildSubscriptionList(docs)),
      ],
    );
  }

  Widget _buildCalendar(
    Set<DateTime> paymentDates,
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
                  color: widget.theme.colorScheme.error,
                ),
              ),
            );
          }
          return null;
        },
      ),
      calendarStyle: CalendarStyle(
        markerDecoration: BoxDecoration(
          color: widget.theme.colorScheme.error,
          shape: BoxShape.circle,
        ),
      ),
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
      ),
    );
  }

  Widget _buildSubscriptionList(List<QueryDocumentSnapshot> docs) {
    return ListView.separated(
      padding: const EdgeInsets.all(16.0),
      itemCount: docs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final document = docs[index];
        final data = document.data()! as Map<String, dynamic>;

        final nextDate = (data['nextPaymentDate'] as Timestamp?)?.toDate();
        final formattedDate =
            (nextDate != null)
                ? '${nextDate.day}/${nextDate.month}/${nextDate.year}'
                : 'Chưa có ngày';

        final amount = data['amount'] ?? 0;
        final currency = (data['currency'] ?? 'VND').toString();
        final formattedAmount = widget.getFormattedAmount(amount, currency);

        return Dismissible(
          key: Key(document.id),
          direction: DismissDirection.endToStart,
          background: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                color: Colors.red,
                child: const Icon(Icons.delete, color: Colors.white, size: 32),
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
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Huỷ'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
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
            color: widget.theme.colorScheme.surface,
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
                  backgroundColor: widget.theme.colorScheme.surfaceVariant,
                  backgroundImage:
                      (data['iconUrl'] != null && data['iconUrl'].isNotEmpty)
                          ? NetworkImage(data['iconUrl'])
                          : null,
                  child:
                      (data['iconUrl'] == null || data['iconUrl'].isEmpty)
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
                    color: widget.theme.textTheme.bodyLarge?.color,
                  ),
                ),
                subtitle: Text(
                  'Đến hạn: $formattedDate\nSố tiền: $formattedAmount',
                  style: TextStyle(
                    fontSize: 14,
                    color: widget.theme.textTheme.bodyMedium?.color,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
