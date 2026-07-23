// ============================================================================
// auth_service.dart - Xử lý TÀI KHOẢN (UC01, UC02, UC03 trong báo cáo)
// ----------------------------------------------------------------------------
// Tại sao tách riêng file service?
//   - Màn hình (UI) chỉ lo hiển thị; mọi thao tác với server nằm ở đây.
//   - Sau này đổi database chỉ cần sửa các file service, không đụng UI.
// ============================================================================

import '../main.dart'; // để dùng biến `supabase`

class AuthService {
  // --------------------------------------------------------------------------
  // UC01 - ĐĂNG KÝ TÀI KHOẢN
  // Gồm 2 bước:
  //   B1: Tạo tài khoản đăng nhập (Supabase tự mã hóa mật khẩu - an toàn)
  //   B2: Lưu hồ sơ (họ tên, SĐT, địa chỉ) vào bảng nguoi_dung
  // --------------------------------------------------------------------------
  static Future<void> dangKy({
    required String email,
    required String matKhau,
    required String hoTen,
    required String soDienThoai,
    required String diaChi,
  }) async {
    // B1: tạo tài khoản trong hệ thống auth của Supabase
    final res = await supabase.auth.signUp(email: email, password: matKhau);

    final user = res.user;
    if (user == null) {
      throw Exception('Đăng ký thất bại, vui lòng thử lại.');
    }

    // B2: lưu thông tin thêm vào bảng nguoi_dung
    // vai_tro mặc định là 'khach_hang' (đã cài trong SQL)
    await supabase.from('nguoi_dung').insert({
      'id': user.id, // trùng id với auth.users
      'ho_ten': hoTen,
      'so_dien_thoai': soDienThoai,
      'dia_chi': diaChi,
      'email': email,
    });
  }

  // --------------------------------------------------------------------------
  // UC02 - ĐĂNG NHẬP
  // Nếu sai email/mật khẩu, Supabase ném lỗi AuthException -> màn hình bắt và
  // hiện thông báo tiếng Việt.
  // --------------------------------------------------------------------------
  static Future<void> dangNhap({
    required String email,
    required String matKhau,
  }) async {
    await supabase.auth.signInWithPassword(email: email, password: matKhau);
  }

  // --------------------------------------------------------------------------
  // UC03 - QUÊN MẬT KHẨU
  // Supabase gửi email chứa link đặt lại mật khẩu tới hộp thư người dùng.
  // --------------------------------------------------------------------------
  static Future<void> quenMatKhau(String email) async {
    await supabase.auth.resetPasswordForEmail(email);
  }

  // --------------------------------------------------------------------------
  // ĐĂNG XUẤT
  // Sau khi gọi, stream onAuthStateChange trong main.dart phát tín hiệu
  // -> app tự quay về màn hình Login.
  // --------------------------------------------------------------------------
  static Future<void> dangXuat() async {
    await supabase.auth.signOut();
  }

  /// Dịch lỗi tiếng Anh của Supabase sang tiếng Việt cho dễ hiểu
  static String dichLoi(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('invalid login credentials')) {
      return 'Email hoặc mật khẩu không đúng.';
    }
    if (msg.contains('already registered') || msg.contains('already exists')) {
      return 'Email này đã được đăng ký.';
    }
    if (msg.contains('password should be at least')) {
      return 'Mật khẩu phải có ít nhất 6 ký tự.';
    }
    if (msg.contains('invalid email') || msg.contains('validate email')) {
      return 'Email không hợp lệ.';
    }
    return 'Có lỗi xảy ra: $e';
  }
}
