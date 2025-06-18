import 'package:flutter/material.dart';

class AvatarHelper {
  static const String defaultAvatar =
      'https://res.cloudinary.com/ddfzzvwvx/image/upload/v1749923335/download_iqse1o.jpg';

  /// Lấy URL avatar từ user data, ưu tiên avatar > photoURL > default
  static String getAvatarUrl(Map<String, dynamic> userData) {
    // Ưu tiên avatar (từ upload thủ công)
    if ((userData['avatar'] as String?)?.isNotEmpty == true) {
      return userData['avatar'];
    }

    // Fallback về photoURL (từ Google)
    if ((userData['photoURL'] as String?)?.isNotEmpty == true) {
      return userData['photoURL'];
    }

    // Default avatar
    return defaultAvatar;
  }

  /// Cập nhật avatar field thống nhất khi user upload ảnh mới
  static Map<String, dynamic> getUpdateData(String avatarUrl) {
    return {
      'avatar': avatarUrl,
      // Xóa photoURL cũ để tránh nhầm lẫn
      'photoURL': null,
    };
  }

  /// Widget avatar với error handling
  static Widget buildAvatar({
    required String avatarUrl,
    required double radius,
    Color? backgroundColor,
    Color? iconColor,
  }) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? Colors.grey[300],
      child: ClipOval(
        child: Image.network(
          avatarUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.person,
              size: radius * 1.2,
              color: iconColor ?? Colors.grey[600],
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value:
                    loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                strokeWidth: 2,
              ),
            );
          },
        ),
      ),
    );
  }
}
