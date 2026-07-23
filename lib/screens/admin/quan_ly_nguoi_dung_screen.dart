// ============================================================================
// quan_ly_nguoi_dung_screen.dart - ADMIN quản lý NGƯỜI DÙNG (UC22)
// ----------------------------------------------------------------------------
// Chức năng:
//   - Xem danh sách toàn bộ tài khoản (khách hàng + admin)
//   - Tìm kiếm theo tên / email / SĐT
//   - Cấp quyền admin hoặc hạ xuống khách hàng
//   - Khóa / mở khóa tài khoản (người bị khóa không vào được app)
// Chốt an toàn: admin KHÔNG thể tự khóa hay tự hạ quyền chính mình
// (tránh tình huống hệ thống không còn admin nào).
// ============================================================================

import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/database_service.dart';

class QuanLyNguoiDungScreen extends StatefulWidget {
  const QuanLyNguoiDungScreen({super.key});

  @override
  State<QuanLyNguoiDungScreen> createState() => _QuanLyNguoiDungScreenState();
}

class _QuanLyNguoiDungScreenState extends State<QuanLyNguoiDungScreen> {
  List<Map<String, dynamic>> _dsNguoiDung = [];
  bool _dangTai = true;
  String _tuKhoa = ''; // chữ đang gõ trong ô tìm kiếm

  @override
  void initState() {
    super.initState();
    _taiDanhSach();
  }

  Future<void> _taiDanhSach() async {
    setState(() => _dangTai = true);
    try {
      final ds = await NguoiDungService.layTatCa();
      if (mounted) setState(() => _dsNguoiDung = ds);
    } catch (e) {
      _baoLoi('Lỗi tải danh sách: $e');
    } finally {
      if (mounted) setState(() => _dangTai = false);
    }
  }

  /// Lọc danh sách theo từ khóa (tìm trong tên, email, SĐT - không phân biệt hoa thường)
  List<Map<String, dynamic>> get _dsSauLoc {
    if (_tuKhoa.isEmpty) return _dsNguoiDung;
    final tk = _tuKhoa.toLowerCase();
    return _dsNguoiDung.where((nd) {
      return (nd['ho_ten'] ?? '').toLowerCase().contains(tk) ||
          (nd['email'] ?? '').toLowerCase().contains(tk) ||
          (nd['so_dien_thoai'] ?? '').contains(tk);
    }).toList();
  }

  /// Đổi vai trò (có hỏi xác nhận)
  Future<void> _doiVaiTro(Map<String, dynamic> nd) async {
    final laAdmin = nd['vai_tro'] == 'admin';
    final vaiTroMoi = laAdmin ? 'khach_hang' : 'admin';

    final dongY = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(laAdmin ? 'Hạ quyền' : 'Cấp quyền admin'),
        content: Text(laAdmin
            ? 'Chuyển "${nd['ho_ten']}" về vai trò khách hàng?'
            : 'Cấp quyền QUẢN TRỊ VIÊN cho "${nd['ho_ten']}"?\n'
                'Người này sẽ thấy và sửa được TOÀN BỘ dữ liệu hệ thống.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Đồng ý')),
        ],
      ),
    );
    if (dongY != true) return;

    try {
      await NguoiDungService.doiVaiTro(nd['id'], vaiTroMoi);
      _baoThanhCong('Đã đổi vai trò của ${nd['ho_ten']}.');
      _taiDanhSach();
    } catch (e) {
      _baoLoi('Lỗi: $e');
    }
  }

  /// Khóa / mở khóa (có hỏi xác nhận)
  Future<void> _doiKhoa(Map<String, dynamic> nd) async {
    final dangKhoa = nd['bi_khoa'] == true;

    final dongY = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(dangKhoa ? 'Mở khóa tài khoản' : 'Khóa tài khoản'),
        content: Text(dangKhoa
            ? 'Cho phép "${nd['ho_ten']}" đăng nhập trở lại?'
            : 'Khóa tài khoản "${nd['ho_ten']}"?\n'
                'Người này sẽ không sử dụng được app cho tới khi mở khóa.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy')),
          FilledButton(
            style: dangKhoa
                ? null
                : FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(dangKhoa ? 'Mở khóa' : 'Khóa'),
          ),
        ],
      ),
    );
    if (dongY != true) return;

    try {
      await NguoiDungService.datKhoa(nd['id'], !dangKhoa);
      _baoThanhCong(dangKhoa
          ? 'Đã mở khóa ${nd['ho_ten']}.'
          : 'Đã khóa ${nd['ho_ten']}.');
      _taiDanhSach();
    } catch (e) {
      _baoLoi('Lỗi: $e');
    }
  }

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
  Widget build(BuildContext context) {
    // id của chính admin đang đăng nhập - để chặn tự khóa/tự hạ quyền
    final idCuaToi = supabase.auth.currentUser?.id;

    return Column(
      children: [
        // ---- Ô tìm kiếm ----
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Tìm theo tên, email, số điện thoại...',
              prefixIcon: const Icon(Icons.search),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _tuKhoa = v.trim()),
          ),
        ),

        // ---- Danh sách người dùng ----
        Expanded(
          child: _dangTai
              ? const Center(child: CircularProgressIndicator())
              : _dsSauLoc.isEmpty
                  ? const Center(child: Text('Không tìm thấy người dùng nào.'))
                  : RefreshIndicator(
                      onRefresh: _taiDanhSach, // kéo xuống để tải lại
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _dsSauLoc.length,
                        itemBuilder: (context, i) {
                          final nd = _dsSauLoc[i];
                          final laAdmin = nd['vai_tro'] == 'admin';
                          final biKhoa = nd['bi_khoa'] == true;
                          final laChinhMinh = nd['id'] == idCuaToi;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: biKhoa
                                    ? Colors.grey
                                    : (laAdmin
                                        ? const Color(0xFF1B5E20)
                                        : const Color(0xFF66BB6A)),
                                child: Text(
                                  (nd['ho_ten'] ?? '?')
                                      .toString()
                                      .trim()
                                      .isNotEmpty
                                      ? nd['ho_ten'].toString().trim()[0]
                                          .toUpperCase()
                                      : '?',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      nd['ho_ten'] ?? '(chưa có tên)',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  // Nhãn vai trò
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: laAdmin
                                          ? const Color(0xFF1B5E20)
                                          : Colors.grey.shade300,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      laAdmin ? 'Admin' : 'Khách',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: laAdmin
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                  ),
                                  if (biKhoa) ...[
                                    const SizedBox(width: 6),
                                    const Icon(Icons.lock,
                                        size: 16, color: Colors.red),
                                  ],
                                ],
                              ),
                              subtitle: Text(
                                '${nd['email'] ?? ''}\n${nd['so_dien_thoai'] ?? ''}',
                                style: const TextStyle(height: 1.4),
                              ),
                              isThreeLine: true,
                              // Menu 3 chấm: các thao tác quản trị
                              trailing: laChinhMinh
                                  // Với chính mình: chỉ hiện chữ, không có menu
                                  ? const Text('(bạn)',
                                      style: TextStyle(color: Colors.grey))
                                  : PopupMenuButton<String>(
                                      onSelected: (chon) {
                                        if (chon == 'vai_tro') _doiVaiTro(nd);
                                        if (chon == 'khoa') _doiKhoa(nd);
                                      },
                                      itemBuilder: (_) => [
                                        PopupMenuItem(
                                          value: 'vai_tro',
                                          child: Text(laAdmin
                                              ? 'Hạ xuống khách hàng'
                                              : 'Cấp quyền admin'),
                                        ),
                                        PopupMenuItem(
                                          value: 'khoa',
                                          child: Text(
                                            biKhoa
                                                ? 'Mở khóa tài khoản'
                                                : 'Khóa tài khoản',
                                            style: TextStyle(
                                                color: biKhoa
                                                    ? Colors.green
                                                    : Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}
