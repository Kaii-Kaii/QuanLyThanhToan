// lib/services/auth_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  // Khởi tạo các instance của Firebase Authentication và Cloud Firestore
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

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

  /// Đăng nhập với Google và tự động tạo user document nếu chưa tồn tại
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Bắt đầu quy trình xác thực
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // Người dùng đã hủy bỏ việc đăng nhập
        return null;
      }

      // Lấy thông tin xác thực từ yêu cầu
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Tạo một credential mới
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Đăng nhập vào Firebase bằng credential của Google
      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      // Kiểm tra xem đây có phải là lần đăng nhập đầu tiên không
      if (userCredential.additionalUserInfo?.isNewUser == true) {
        // Tạo document cho user mới trong Firestore
        await _createUserDocument(userCredential.user!);
      }

      return userCredential;
    } catch (e) {
      print('Lỗi đăng nhập Google: $e');
      rethrow;
    }
  }

  /// Tạo document cho user trong Firestore
  Future<void> _createUserDocument(User user) async {
    try {
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName ?? '', // Sử dụng displayName từ Google
        'photoURL': user.photoURL ?? '', // Lưu ảnh đại diện từ Google
        'createdAt': Timestamp.now(),
        'loginMethod': 'google', // Đánh dấu phương thức đăng nhập
      });
    } catch (e) {
      print('Lỗi tạo user document: $e');
      // Không throw lỗi ở đây để không ảnh hưởng đến quá trình đăng nhập
    }
  }

  /// Đăng xuất người dùng hiện tại.
  /// Hàm này sẽ đăng xuất khỏi cả Firebase và Google.
  Future<void> signOut() async {
    await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
  }
}
