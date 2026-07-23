// ============================================================================
// register_screen.dart - MÀN HÌNH ĐĂNG KÝ TÀI KHOẢN (UC01)
// ----------------------------------------------------------------------------
// Thu thập: họ tên, SĐT, địa chỉ, email, mật khẩu (+ nhập lại mật khẩu).
// Sau khi đăng ký thành công, Supabase tự đăng nhập luôn -> main.dart tự
// chuyển vào trang chủ khách hàng.
// ============================================================================

import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _hoTenCtrl = TextEditingController();
  final _sdtCtrl = TextEditingController();
  final _diaChiCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _matKhauCtrl = TextEditingController();
  final _nhapLaiMkCtrl = TextEditingController();

  bool _dangTai = false;
  bool _hienMatKhau = false; // nút con mắt cho cả 2 ô mật khẩu

  Future<void> _xuLyDangKy() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _dangTai = true);
    try {
      await AuthService.dangKy(
        email: _emailCtrl.text.trim(),
        matKhau: _matKhauCtrl.text,
        hoTen: _hoTenCtrl.text.trim(),
        soDienThoai: _sdtCtrl.text.trim(),
        diaChi: _diaChiCtrl.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đăng ký thành công! Chào mừng bạn đến GreenTrash 🌱'),
            backgroundColor: Colors.green,
          ),
        );
        // Đóng hết màn Đăng ký lẫn Đăng nhập phía dưới -> lộ Trang chủ,
        // main.dart thấy đã đăng nhập sẽ tự vẽ lại giao diện đầy đủ
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AuthService.dichLoi(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _dangTai = false);
    }
  }

  @override
  void dispose() {
    _hoTenCtrl.dispose();
    _sdtCtrl.dispose();
    _diaChiCtrl.dispose();
    _emailCtrl.dispose();
    _matKhauCtrl.dispose();
    _nhapLaiMkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng ký tài khoản')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // ---- Họ tên ----
                  TextFormField(
                    controller: _hoTenCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Họ và tên',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Vui lòng nhập họ tên' : null,
                  ),
                  const SizedBox(height: 16),

                  // ---- Số điện thoại ----
                  TextFormField(
                    controller: _sdtCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Số điện thoại',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Vui lòng nhập số điện thoại';
                      }
                      // Kiểm tra đơn giản: 10 chữ số, bắt đầu bằng 0
                      if (!RegExp(r'^0\d{9}$').hasMatch(v.trim())) {
                        return 'SĐT phải gồm 10 số, bắt đầu bằng 0';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // ---- Địa chỉ ----
                  TextFormField(
                    controller: _diaChiCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Địa chỉ thu gom mặc định',
                      prefixIcon: Icon(Icons.home_outlined),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Vui lòng nhập địa chỉ' : null,
                  ),
                  const SizedBox(height: 16),

                  // ---- Email ----
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Vui lòng nhập email';
                      if (!v.contains('@')) return 'Email không hợp lệ';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // ---- Mật khẩu ----
                  TextFormField(
                    controller: _matKhauCtrl,
                    obscureText: !_hienMatKhau,
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu (ít nhất 6 ký tự)',
                      prefixIcon: const Icon(Icons.lock_outline),
                      // Nút con mắt hiện/ẩn mật khẩu
                      suffixIcon: IconButton(
                        icon: Icon(_hienMatKhau
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined),
                        onPressed: () =>
                            setState(() => _hienMatKhau = !_hienMatKhau),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu';
                      if (v.length < 6) return 'Mật khẩu phải từ 6 ký tự';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // ---- Nhập lại mật khẩu ----
                  TextFormField(
                    controller: _nhapLaiMkCtrl,
                    // Dùng chung nút con mắt với ô mật khẩu phía trên
                    obscureText: !_hienMatKhau,
                    decoration: const InputDecoration(
                      labelText: 'Nhập lại mật khẩu',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    // So khớp với ô mật khẩu ở trên
                    validator: (v) =>
                        v != _matKhauCtrl.text ? 'Mật khẩu nhập lại không khớp' : null,
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: _dangTai ? null : _xuLyDangKy,
                      child: _dangTai
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Đăng ký'),
                    ),
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
