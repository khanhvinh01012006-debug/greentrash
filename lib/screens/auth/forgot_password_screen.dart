// ============================================================================
// forgot_password_screen.dart - MÀN HÌNH QUÊN MẬT KHẨU (UC03)
// ----------------------------------------------------------------------------
// Người dùng nhập email -> Supabase gửi email chứa link đặt lại mật khẩu.
// (Đúng theo đặc tả UC03: "Hệ thống gửi OTP/email để đặt lại mật khẩu")
// ============================================================================

import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  bool _dangTai = false;
  bool _daGui = false; // true = đã gửi email thành công -> đổi giao diện

  Future<void> _guiEmail() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập email hợp lệ')),
      );
      return;
    }

    setState(() => _dangTai = true);
    try {
      await AuthService.quenMatKhau(email);
      setState(() => _daGui = true); // chuyển sang giao diện "đã gửi"
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AuthService.dichLoi(e)), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _dangTai = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quên mật khẩu')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            // Nếu đã gửi email thì hiện thông báo, chưa thì hiện form nhập
            child: _daGui ? _giaoDienDaGui() : _giaoDienNhapEmail(),
          ),
        ),
      ),
    );
  }

  /// Giao diện nhập email
  Widget _giaoDienNhapEmail() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.lock_reset, size: 64, color: Color(0xFF2E7D32)),
        const SizedBox(height: 16),
        const Text(
          'Nhập email đã đăng ký, chúng tôi sẽ gửi link đặt lại mật khẩu.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed: _dangTai ? null : _guiEmail,
            child: _dangTai
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Gửi email đặt lại mật khẩu'),
          ),
        ),
      ],
    );
  }

  /// Giao diện sau khi gửi email thành công
  Widget _giaoDienDaGui() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.mark_email_read, size: 64, color: Colors.green),
        const SizedBox(height: 16),
        Text(
          'Đã gửi email tới ${_emailCtrl.text.trim()}.\n'
          'Hãy kiểm tra hộp thư (kể cả mục Spam) và làm theo hướng dẫn.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Quay lại đăng nhập'),
        ),
      ],
    );
  }
}
