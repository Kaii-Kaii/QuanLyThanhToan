// lib/services/auth_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  // Khởi tạo các instance của Firebase Authentication và Cloud Firestore
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- CÁC HÀM GETTER ---

  /// Cung cấp một Stream để lắng nghe sự thay đổi trạng thái đăng nhập (đăng nhập/đăng xuất).
  /// Widget AuthGate sẽ sử dụng stream này.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Cung cấp một cách nhanh chóng để lấy thông tin người dùng đang đăng nhập hiện tại.
  User? get currentUser => _auth.currentUser;

  // --- CÁC HÀM XỬ LÝ XÁC THỰC ---

  /// Đăng nhập người dùng đã có bằng Email và Mật khẩu.
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      // Ném lại lỗi để giao diện (UI) có thể bắt và hiển thị thông báo.
      rethrow;
    }
  }

  /// Đăng ký một người dùng mới.
  /// Hàm này sẽ thực hiện 2 việc:
  /// 1. Tạo user trong Firebase Authentication.
  /// 2. Tạo một document tương ứng cho user đó trong Cloud Firestore.
  Future<void> registerWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      // BƯỚC 1: Tạo người dùng trong Firebase Authentication.
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      // Lấy đối tượng User từ kết quả trả về
      User? newUser = userCredential.user;

      // BƯỚC 2: Nếu người dùng được tạo thành công, tạo một document trong Firestore.
      if (newUser != null) {
        // Sử dụng chính UID của người dùng làm ID cho document.
        // Đây là cách tốt nhất để liên kết dữ liệu giữa hai dịch vụ.
        await _firestore.collection('users').doc(newUser.uid).set({
          'uid': newUser.uid,
          'email': newUser.email,
          'displayName':
              '', // Tạm thời để trống, người dùng có thể cập nhật sau
          'createdAt': Timestamp.now(), // Ghi lại thời điểm tài khoản được tạo
        });
      }
    } catch (e) {
      // Ném lại lỗi để UI xử lý.
      rethrow;
    }
  }

  /// Đăng xuất người dùng hiện tại.
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
