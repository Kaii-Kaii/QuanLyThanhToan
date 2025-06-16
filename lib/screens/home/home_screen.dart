import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import 'add_subscription_screen.dart';
import '../profile/profile_screen.dart';
import '../../utils/notification_helper.dart';
import 'tabs/payment_jar_tab.dart';
import 'tabs/list_calendar_tab.dart';

// Helper class for persistent TabBar below SliverAppBar
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  final ThemeData theme; // Thêm theme parameter

  _SliverAppBarDelegate(this._tabBar, this.theme);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: theme.colorScheme.surface, // Sử dụng theme được truyền vào
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return theme != oldDelegate.theme; // Rebuild khi theme thay đổi
  }
}

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

  /// Sửa điều kiện ở đây: cập nhật nếu nextDate là hôm nay hoặc đã qua
  Future<void> _updateNextPaymentDateIfNeeded(
    DocumentSnapshot document,
    Map<String, dynamic> data,
  ) async {
    DateTime? nextDate;
    if (data['nextPaymentDate'] != null) {
      nextDate = (data['nextPaymentDate'] as Timestamp).toDate();
    }
    final now = DateTime.now();

    // Sửa logic: cập nhật nếu nextDate <= hôm nay
    if (nextDate != null && !nextDate.isAfter(now)) {
      String cycle = data['paymentCycle'] ?? 'monthly';
      DateTime updatedDate = nextDate;

      // Tăng tới khi updatedDate > hôm nay
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

  Widget _buildModernAppBar(String? currentUserId, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      snap: false,
      elevation: 0,
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.primary.withOpacity(0.1),
                colorScheme.primary.withOpacity(0.05),
                colorScheme.surface,
              ],
            ),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.account_balance_wallet,
                color: colorScheme.primary,
                size: 14,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Quản lý thanh toán',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        titlePadding: const EdgeInsets.only(left: 16, bottom: 16, right: 80),
      ),
      actions: [
        StreamBuilder<DocumentSnapshot>(
          stream:
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUserId)
                  .snapshots(),
          builder: (context, snapshot) {
            final userData =
                snapshot.data?.data() as Map<String, dynamic>? ?? {};
            final avatarUrl = userData['avatar'] as String?;

            return Padding(
              padding: const EdgeInsets.only(right: 16),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(25),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colorScheme.primary.withOpacity(0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: colorScheme.surfaceVariant,
                    backgroundImage:
                        (avatarUrl != null && avatarUrl.isNotEmpty)
                            ? NetworkImage(avatarUrl)
                            : null,
                    child:
                        (avatarUrl == null || avatarUrl.isEmpty)
                            ? Icon(
                              Icons.person_outline,
                              size: 24,
                              color: colorScheme.onSurfaceVariant,
                            )
                            : null,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildModernFAB(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        heroTag: 'addSubscription',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddSubscriptionScreen(),
            ),
          );
        },
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        icon: const Icon(Icons.add, size: 24),
        label: const Text(
          'Thêm mới',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? currentUserId = _authService.currentUser?.uid;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (currentUserId == null) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: colorScheme.error),
                const SizedBox(height: 16),
                Text(
                  'Không thể xác định người dùng',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Vui lòng đăng nhập lại',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AnimatedTheme(
      // Wrap với AnimatedTheme
      data: theme,
      duration: const Duration(milliseconds: 200),
      child: DefaultTabController(
        length: 2,
        initialIndex: 0,
        child: Scaffold(
          backgroundColor: colorScheme.surface,
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                _buildModernAppBar(currentUserId, theme),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverAppBarDelegate(
                    TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: colorScheme.primary,
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicatorPadding: const EdgeInsets.all(4),
                      labelColor: colorScheme.onPrimary,
                      unselectedLabelColor: colorScheme.onSurfaceVariant,
                      dividerColor: Colors.transparent,
                      overlayColor: MaterialStateProperty.all(
                        Colors.transparent,
                      ),
                      splashFactory: NoSplash.splashFactory,
                      tabs: const [
                        Tab(
                          icon: Icon(Icons.sports_basketball, size: 24),
                          text: "Lọ",
                        ),
                        Tab(
                          icon: Icon(Icons.list_alt, size: 24),
                          text: "Danh sách",
                        ),
                      ],
                    ),
                    theme, // Truyền theme vào delegate
                  ),
                ),
              ];
            },
            body: StreamBuilder<DocumentSnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUserId)
                      .snapshots(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: colorScheme.primary,
                    ),
                  );
                }

                final userData =
                    userSnapshot.data?.data() as Map<String, dynamic>? ?? {};
                final displayName = userData['displayName'] ?? '';

                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        colorScheme.surface,
                        colorScheme.surface.withOpacity(0.95),
                      ],
                    ),
                  ),
                  child: TabBarView(
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
                  ),
                );
              },
            ),
          ),
          floatingActionButton: _buildModernFAB(theme),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        ),
      ),
    );
  }
}
