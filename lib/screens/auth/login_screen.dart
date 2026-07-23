// ============================================================================
// login_screen.dart - MÀN HÌNH ĐĂNG NHẬP (UC02)
// ----------------------------------------------------------------------------
// Kiến thức dùng trong file:
//   - StatefulWidget: màn hình có trạng thái thay đổi (đang tải, lỗi...)
//   - TextEditingController: đọc chữ người dùng gõ vào ô nhập
//   - Form + validator: kiểm tra dữ liệu trước khi gửi lên server
// ============================================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Key để gọi validate() kiểm tra toàn bộ form
  final _formKey = GlobalKey<FormState>();

  // Controller đọc nội dung 2 ô nhập
  final _emailCtrl = TextEditingController();
  final _matKhauCtrl = TextEditingController();

  bool _dangTai = false; // true = đang gọi server -> hiện vòng xoay, khóa nút
  bool _hienMatKhau = false; // true = hiện chữ mật khẩu (nút con mắt)
  bool _ghiNhoEmail = true; // ô tick "Ghi nhớ email"

  @override
  void initState() {
    super.initState();
    _taiEmailDaLuu(); // mở màn hình -> điền sẵn email lần trước (nếu có)
  }

  /// Đọc email đã lưu từ lần đăng nhập trước và điền sẵn vào ô Email.
  /// SharedPreferences = kho lưu chuỗi nhỏ trên máy người dùng, tồn tại
  /// kể cả khi đóng trình duyệt (trên web nó lưu vào bộ nhớ của Chrome).
  Future<void> _taiEmailDaLuu() async {
    final kho = await SharedPreferences.getInstance();
    final emailCu = kho.getString('email_da_luu');
    if (emailCu != null && mounted) {
      setState(() => _emailCtrl.text = emailCu);
    }
  }

  /// Sau khi đăng nhập THÀNH CÔNG: lưu email nếu có tick, xóa nếu bỏ tick
  Future<void> _luuEmailNeuCan() async {
    final kho = await SharedPreferences.getInstance();
    if (_ghiNhoEmail) {
      await kho.setString('email_da_luu', _emailCtrl.text.trim());
    } else {
      await kho.remove('email_da_luu');
    }
  }

  /// Hàm xử lý khi bấm nút Đăng nhập
  Future<void> _xuLyDangNhap() async {
    // validate() chạy tất cả validator của các ô; sai thì dừng luôn
    if (!_formKey.currentState!.validate()) return;

    setState(() => _dangTai = true); // bật vòng xoay

    try {
      await AuthService.dangNhap(
        email: _emailCtrl.text.trim(), // trim() bỏ khoảng trắng thừa
        matKhau: _matKhauCtrl.text,
      );
      await _luuEmailNeuCan(); // đăng nhập OK -> ghi nhớ email cho lần sau
      // Màn hình này luôn được PUSH lên (từ lúc khách bấm "Tạo đơn thu gom"
      // khi đang xem Trang chủ) -> đóng hết các màn đã mở (kể cả Đăng ký/
      // Quên mật khẩu nếu có) để lộ ra Trang chủ đã tự đổi sang giao diện
      // đã đăng nhập (main.dart lắng nghe stream và tự vẽ lại).
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      // Đăng nhập lỗi -> hiện thông báo đỏ ở đáy màn hình
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AuthService.dichLoi(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // Dù thành công hay lỗi cũng tắt vòng xoay
      if (mounted) setState(() => _dangTai = false);
    }
  }

  @override
  void dispose() {
    // Giải phóng bộ nhớ của controller khi màn hình bị hủy (thói quen tốt)
    _emailCtrl.dispose();
    _matKhauCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar trong suốt: chỉ để hiện nút back - màn này luôn được PUSH lên
      // từ Trang chủ nên khách bấm nhầm vẫn quay lại xem tiếp được.
      // foregroundColor đặt riêng màu tối vì nền trong suốt ở đây để lộ ra
      // nền TRẮNG của Scaffold (khác với AppBar xanh mặc định toàn app),
      // nếu dùng chữ/icon trắng theo theme chung sẽ bị chìm mất.
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: Center(
        child: SingleChildScrollView( // cuộn được khi bàn phím che màn hình
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            // Giới hạn rộng tối đa 400px để form không bị kéo dài trên web
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo + tên app
                  const Icon(Icons.recycling, size: 80, color: Color(0xFF2E7D32)),
                  const SizedBox(height: 8),
                  Text(
                    'GreenTrash',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2E7D32),
                        ),
                  ),
                  const Text('Đặt lịch thu gom rác tại nhà'),
                  const SizedBox(height: 32),

                  // Ô nhập Email
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    // validator trả về chuỗi lỗi, hoặc null nếu hợp lệ
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Vui lòng nhập email';
                      }
                      if (!v.contains('@')) return 'Email không hợp lệ';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Ô nhập Mật khẩu
                  TextFormField(
                    controller: _matKhauCtrl,
                    // Ẩn ký tự khi _hienMatKhau = false
                    obscureText: !_hienMatKhau,
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu',
                      prefixIcon: const Icon(Icons.lock_outline),
                      // Nút con mắt: bấm để đảo trạng thái hiện/ẩn
                      suffixIcon: IconButton(
                        icon: Icon(_hienMatKhau
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined),
                        onPressed: () =>
                            setState(() => _hienMatKhau = !_hienMatKhau),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Vui lòng nhập mật khẩu' : null,
                  ),

                  // Hàng: [Ghi nhớ email] ..... [Quên mật khẩu?]
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Ô tick ghi nhớ email - bấm cả chữ cũng đổi được
                      Row(
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: _ghiNhoEmail,
                              onChanged: (v) =>
                                  setState(() => _ghiNhoEmail = v ?? true),
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => setState(
                                () => _ghiNhoEmail = !_ghiNhoEmail),
                            child: const Text('Ghi nhớ email'),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ForgotPasswordScreen()),
                        ),
                        child: const Text('Quên mật khẩu?'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Nút Đăng nhập - khi _dangTai thì khóa nút và hiện vòng xoay
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: _dangTai ? null : _xuLyDangNhap,
                      child: _dangTai
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Đăng nhập'),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Link sang màn hình đăng ký
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Chưa có tài khoản?'),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const RegisterScreen()),
                        ),
                        child: const Text('Đăng ký ngay'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
