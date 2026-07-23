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
import '../../widgets/common.dart';

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

  /// Dải thống kê 3 ô (số lần thu gom / tổng khối lượng / tổng chi phí) -
  /// CHỈ tính các lịch đã 'hoan_tat'. Dùng lại đúng
  /// DatabaseService.streamLichCuaToi() đã có (không viết query mới), rồi
  /// LỌC + CỘNG DỒN bằng Dart thuần ngay trong builder.
  Widget _daiThongKe() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: DatabaseService.streamLichCuaToi(),
      builder: (context, snapshot) {
        String soDon = '—';
        String tongKhoiLuong = '—';
        String tongChiPhi = '—';

        // Có dữ liệu (không phải đang tải/lỗi) -> lọc + cộng dồn. Đang tải
        // (chưa hasData) hoặc lỗi (hasError) -> giữ nguyên '—' ở cả 3 ô,
        // KHÔNG dùng CircularProgressIndicator để layout khỏi nhảy giật.
        if (snapshot.hasData) {
          num soLuong = 0;
          num tongKg = 0;
          num tongTien = 0;
          for (final lich in snapshot.data!) {
            if (lich['trang_thai'] == 'hoan_tat') {
              soLuong += 1;
              tongKg += (lich['khoi_luong_uoc_tinh'] as num? ?? 0);
              tongTien += (lich['chi_phi_du_kien'] as num? ?? 0);
            }
          }
          soDon = '$soLuong';
          tongKhoiLuong = '${tongKg.toStringAsFixed(1)} kg';
          tongChiPhi = dinhDangTien(tongTien);
        }

        final oSoDon =
            _oThongKe(Icons.check_circle_outline, soDon, 'Lần thu gom');
        final oKhoiLuong =
            _oThongKe(Icons.scale, tongKhoiLuong, 'Tổng khối lượng');
        final oChiPhi = _oThongKe(Icons.payments, tongChiPhi, 'Tổng chi phí');

        // Cố định nằm ngang: vùng nội dung màn này đã bị ConstrainedBox
        // giới hạn ~500px (không phải bề rộng cửa sổ) nên không cần đo
        // responsive - 3 ô vẫn đủ chỗ.
        //
        // IntrinsicHeight + CrossAxisAlignment.stretch để 3 Card cao bằng
        // nhau. LƯU Ý: Row này nằm trong Column đang ở trong
        // SingleChildScrollView (chiều cao KHÔNG giới hạn) - nếu chỉ dùng
        // CrossAxisAlignment.stretch suông (không có IntrinsicHeight bọc
        // ngoài), Row sẽ cố ép các ô con nhận chiều cao VÔ HẠN và vỡ layout
        // (lỗi "Cannot hit test a render box with no size" từng gặp).
        // IntrinsicHeight đo trước chiều cao lớn nhất trong các ô rồi ép
        // Row về đúng con số hữu hạn đó, stretch mới an toàn.
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: oSoDon),
              const SizedBox(width: 12),
              Expanded(child: oKhoiLuong),
              const SizedBox(width: 12),
              Expanded(child: oChiPhi),
            ],
          ),
        );
      },
    );
  }

  /// 1 ô thống kê: icon -> số liệu đậm cỡ 20 -> nhãn xám nhỏ - dùng chung
  /// cho cả 3 ô trong dải thống kê, tránh chép lại bố cục 3 lần.
  Widget _oThongKe(IconData icon, String giaTri, String nhan) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF2E7D32)),
            const SizedBox(height: 8),
            // FittedBox tự thu nhỏ chữ vừa khung thay vì xuống dòng - số
            // tiền dài (vd "375.000 đ") ở màn hẹp trước đây bị wrap xuống
            // dòng 2, làm chiều cao 3 ô lệch nhau.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(giaTri,
                  maxLines: 1,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 2),
            Text(nhan,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
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

              // ---- Dải thống kê: số lần thu gom / khối lượng / chi phí ----
              _daiThongKe(),
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
