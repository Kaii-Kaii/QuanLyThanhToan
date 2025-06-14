// lib/screens/home/home_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Import để định dạng ngày tháng và số
import '../../services/auth_service.dart';
import 'add_subscription_screen.dart'; // Import màn hình thêm mới

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    final String? currentUserId = _authService.currentUser?.uid;

    // Trường hợp hiếm gặp: không có user, hiển thị lỗi
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
          // Nút Đăng xuất
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
            onPressed: () async {
              await _authService.signOut();
              // AuthGate sẽ tự động chuyển hướng về màn hình đăng nhập
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('subscriptions')
                .where('userId', isEqualTo: currentUserId)
                .orderBy(
                  'nextPaymentDate',
                  descending: false,
                ) // Sắp xếp theo ngày đến hạn gần nhất
                .snapshots(),
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
          // Xử lý các trạng thái của stream
          if (snapshot.hasError) {
            return Center(child: Text('Đã xảy ra lỗi: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'Bạn chưa có khoản thanh toán nào.\nNhấn nút + để thêm mới!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          // Hiển thị danh sách nếu có dữ liệu
          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              DocumentSnapshot document = snapshot.data!.docs[index];
              Map<String, dynamic> data =
                  document.data()! as Map<String, dynamic>;

              // Lấy và định dạng ngày tháng cho dễ đọc
              String formattedDate = 'Chưa có ngày';
              if (data['nextPaymentDate'] != null) {
                DateTime nextDate =
                    (data['nextPaymentDate'] as Timestamp).toDate();
                formattedDate = DateFormat('dd/MM/yyyy').format(nextDate);
              }

              // Lấy và định dạng số tiền theo đơn vị tiền tệ Việt Nam
              final currencyFormat = NumberFormat.currency(
                locale: 'vi_VN',
                symbol: '₫',
              );
              String formattedAmount = currencyFormat.format(
                data['amount'] ?? 0,
              );

              // Xây dựng giao diện cho mỗi mục
              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 16,
                  ),
                  // === PHẦN HIỂN THỊ ICON ĐÃ CẬP NHẬT ===
                  leading: CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.grey.shade200,
                    // Nếu có iconUrl hợp lệ, hiển thị ảnh từ mạng
                    backgroundImage:
                        (data['iconUrl'] != null && data['iconUrl'].isNotEmpty)
                            ? NetworkImage(data['iconUrl'])
                            : null,
                    // Nếu không có ảnh, hiển thị icon mặc định
                    child:
                        (data['iconUrl'] == null || data['iconUrl'].isEmpty)
                            ? const Icon(
                              Icons.wallet_giftcard_rounded,
                              color: Colors.grey,
                            )
                            : null,
                  ),
                  // =======================================
                  title: Text(
                    data['serviceName'] ?? 'Không có tên',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text('Đến hạn: $formattedDate'),
                  trailing: Text(
                    formattedAmount,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      // Nút tròn để thêm mới một khoản thanh toán
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Điều hướng đến màn hình thêm mới khi nhấn nút
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
