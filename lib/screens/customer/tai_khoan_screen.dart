// ============================================================================
// tai_khoan_screen.dart - TRANG CÁ NHÂN của khách hàng (UC06 - Quản lý hồ sơ)
// ----------------------------------------------------------------------------
// Chức năng:
//   1. Xem thông tin: họ tên, email, SĐT, địa chỉ
//   2. Sửa họ tên / SĐT / địa chỉ (email không sửa được vì là tên đăng nhập)
//   3. Đổi mật khẩu
//   4. Đăng xuất
// Địa chỉ lưu ở đây sẽ được TỰ ĐIỀN SẴN khi đặt lịch -> đỡ phải gõ lại.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/storage_service.dart';

class TaiKhoanScreen extends StatefulWidget {
  const TaiKhoanScreen({super.key});

  @override
  State<TaiKhoanScreen> createState() => _TaiKhoanScreenState();
}

class _TaiKhoanScreenState extends State<TaiKhoanScreen> {
  final _formKey = GlobalKey<FormState>();

  final _hoTenCtrl = TextEditingController();
  final _sdtCtrl = TextEditingController();
  final _diaChiCtrl = TextEditingController();

  String _email = ''; // chỉ hiển thị, không cho sửa
  String? _anhDaiDienUrl; // link ảnh đại diện (null = chưa có, hiện chữ cái đầu)
  bool _dangTaiHoSo = true; // đang tải hồ sơ lần đầu
  bool _dangLuu = false; // đang bấm nút Lưu
  bool _dangUploadAnh = false; // đang chọn/tải ảnh đại diện lên

  @override
  void initState() {
    super.initState();
    _taiHoSo(); // mở màn hình là tải hồ sơ ngay
  }

  /// Tải hồ sơ từ bảng nguoi_dung rồi đổ vào các ô nhập
  Future<void> _taiHoSo() async {
    try {
      final hoSo = await DatabaseService.layHoSoCuaToi();
      if (!mounted) return;
      setState(() {
        _hoTenCtrl.text = hoSo?['ho_ten'] ?? '';
        _sdtCtrl.text = hoSo?['so_dien_thoai'] ?? '';
        _diaChiCtrl.text = hoSo?['dia_chi'] ?? '';
        _email = hoSo?['email'] ?? supabase.auth.currentUser?.email ?? '';
        _anhDaiDienUrl = hoSo?['anh_dai_dien_url'];
        _dangTaiHoSo = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _dangTaiHoSo = false);
      _baoLoi('Không tải được hồ sơ: $e');
    }
  }

  /// Bấm nút "Lưu thay đổi"
  Future<void> _luuHoSo() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _dangLuu = true);
    try {
      await DatabaseService.capNhatHoSo(
        hoTen: _hoTenCtrl.text.trim(),
        soDienThoai: _sdtCtrl.text.trim(),
        diaChi: _diaChiCtrl.text.trim(),
      );
      _baoThanhCong('Đã lưu thông tin!');
    } catch (e) {
      _baoLoi('Lưu thất bại: $e');
    } finally {
      if (mounted) setState(() => _dangLuu = false);
    }
  }

  /// Bấm avatar / nút "Đổi ảnh đại diện": chọn ảnh -> upload -> lưu link vào DB
  Future<void> _doiAnhDaiDien() async {
    try {
      final chon = await StorageService.chonAnh();
      if (chon == null) return; // người dùng bấm hủy không chọn ảnh

      setState(() => _dangUploadAnh = true);
      final url = await StorageService.uploadAnh(chon.bytes, chon.tenFile);
      await DatabaseService.capNhatAnhDaiDien(url);

      if (!mounted) return;
      setState(() => _anhDaiDienUrl = url);
      _baoThanhCong('Đã cập nhật ảnh đại diện!');
    } catch (e) {
      _baoLoi('Đổi ảnh thất bại: $e');
    } finally {
      if (mounted) setState(() => _dangUploadAnh = false);
    }
  }

  /// Mở hộp thoại đổi mật khẩu
  Future<void> _moDoiMatKhau() async {
    final mkCtrl = TextEditingController();
    final mk2Ctrl = TextEditingController();
    final formDoiMk = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đổi mật khẩu'),
        content: Form(
          key: formDoiMk,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: mkCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Mật khẩu mới (ít nhất 6 ký tự)'),
                validator: (v) =>
                    (v == null || v.length < 6) ? 'Tối thiểu 6 ký tự' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: mk2Ctrl,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Nhập lại mật khẩu mới'),
                validator: (v) =>
                    v != mkCtrl.text ? 'Mật khẩu nhập lại không khớp' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          FilledButton(
            onPressed: () async {
              if (!formDoiMk.currentState!.validate()) return;
              try {
                // Hàm đổi mật khẩu có sẵn của Supabase
                await supabase.auth
                    .updateUser(UserAttributes(password: mkCtrl.text));
                if (ctx.mounted) Navigator.pop(ctx);
                _baoThanhCong('Đổi mật khẩu thành công!');
              } catch (e) {
                _baoLoi(AuthService.dichLoi(e));
              }
            },
            child: const Text('Đổi mật khẩu'),
          ),
        ],
      ),
    );
  }

  /// Bấm nút Đăng xuất (có hỏi xác nhận)
  Future<void> _dangXuat() async {
    final dongY = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Đăng xuất')),
        ],
      ),
    );
    if (dongY == true) await AuthService.dangXuat();
  }

  // ---- 2 hàm tiện ích hiện thông báo ----
  void _baoThanhCong(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.green));
  }

  void _baoLoi(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  void dispose() {
    _hoTenCtrl.dispose();
    _sdtCtrl.dispose();
    _diaChiCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_dangTaiHoSo) {
      return const Center(child: CircularProgressIndicator());
    }

    // Lấy chữ cái đầu của tên làm "avatar"
    final chuCaiDau =
        _hoTenCtrl.text.isNotEmpty ? _hoTenCtrl.text.trim()[0].toUpperCase() : '?';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            children: [
              // ---- Avatar (bấm vào để đổi ảnh) + email ----
              Stack(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: const Color(0xFF2E7D32),
                    // Có ảnh -> hiện ảnh; chưa có -> hiện chữ cái đầu tên
                    backgroundImage: _anhDaiDienUrl != null
                        ? NetworkImage(_anhDaiDienUrl!)
                        : null,
                    child: _anhDaiDienUrl == null
                        ? Text(chuCaiDau,
                            style: const TextStyle(
                                fontSize: 32, color: Colors.white))
                        : null,
                  ),
                  // Nút camera nhỏ góc dưới phải - bấm để đổi ảnh
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onTap: _dangUploadAnh ? null : _doiAnhDaiDien,
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.white,
                        child: _dangUploadAnh
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.photo_camera,
                                size: 16, color: Color(0xFF2E7D32)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(_email, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),

              // ---- Form sửa thông tin ----
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Thông tin cá nhân',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _hoTenCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Họ và tên',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Vui lòng nhập họ tên'
                              : null,
                        ),
                        const SizedBox(height: 16),
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
                            if (!RegExp(r'^0\d{9}$').hasMatch(v.trim())) {
                              return 'SĐT phải gồm 10 số, bắt đầu bằng 0';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _diaChiCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Địa chỉ mặc định',
                            helperText:
                                'Địa chỉ này sẽ tự điền sẵn khi bạn đặt lịch',
                            prefixIcon: Icon(Icons.home_outlined),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Vui lòng nhập địa chỉ'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: FilledButton.icon(
                            onPressed: _dangLuu ? null : _luuHoSo,
                            icon: _dangLuu
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.save_outlined),
                            label: const Text('Lưu thay đổi'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ---- Đổi mật khẩu + Đăng xuất ----
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.lock_reset),
                      title: const Text('Đổi mật khẩu'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _moDoiMatKhau,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.logout, color: Colors.red),
                      title: const Text('Đăng xuất',
                          style: TextStyle(color: Colors.red)),
                      onTap: _dangXuat,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
