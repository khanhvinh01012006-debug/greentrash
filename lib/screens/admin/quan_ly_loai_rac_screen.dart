// ============================================================================
// quan_ly_loai_rac_screen.dart - ADMIN QUẢN LÝ DANH MỤC LOẠI RÁC
// ----------------------------------------------------------------------------
// CRUD đầy đủ (Create - Read - Update - Delete):
//   - Xem danh sách loại rác + đơn giá
//   - Thêm loại rác mới (nút + góc dưới)
//   - Sửa (bấm icon bút)
//   - Xóa (bấm icon thùng rác; nếu loại rác đang được lịch nào dùng thì
//     database CHẶN xóa -> ta bắt lỗi và báo cho admin biết)
// ============================================================================

import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../widgets/common.dart';

class QuanLyLoaiRacScreen extends StatefulWidget {
  const QuanLyLoaiRacScreen({super.key});

  @override
  State<QuanLyLoaiRacScreen> createState() => _QuanLyLoaiRacScreenState();
}

class _QuanLyLoaiRacScreenState extends State<QuanLyLoaiRacScreen> {
  List<Map<String, dynamic>> _dsLoaiRac = [];
  bool _dangTai = true;

  @override
  void initState() {
    super.initState();
    _taiDuLieu();
  }

  /// Tải lại danh sách từ server (gọi sau mỗi lần thêm/sửa/xóa)
  Future<void> _taiDuLieu() async {
    setState(() => _dangTai = true);
    final ds = await DatabaseService.layDanhSachLoaiRac();
    if (mounted) {
      setState(() {
        _dsLoaiRac = ds;
        _dangTai = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _dangTai
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _dsLoaiRac.length,
              itemBuilder: (context, i) {
                final loai = _dsLoaiRac[i];
                return Card(
                  child: ListTile(
                    title: Text(loai['ten_loai_rac'],
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                        '${dinhDangTien(loai['don_gia'])}/kg\n${loai['mo_ta'] ?? ''}'),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Nút SỬA
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _moForm(loaiRacCu: loai),
                        ),
                        // Nút XÓA
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          onPressed: () => _xoa(loai),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      // Nút thêm loại rác mới
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _moForm(),
        icon: const Icon(Icons.add),
        label: const Text('Thêm loại rác'),
      ),
    );
  }

  /// Mở form thêm/sửa. Dùng CHUNG cho 2 việc:
  ///   - loaiRacCu == null  -> chế độ THÊM MỚI
  ///   - loaiRacCu != null  -> chế độ SỬA (điền sẵn dữ liệu cũ)
  Future<void> _moForm({Map<String, dynamic>? loaiRacCu}) async {
    final tenCtrl =
        TextEditingController(text: loaiRacCu?['ten_loai_rac'] ?? '');
    final giaCtrl =
        TextEditingController(text: loaiRacCu?['don_gia']?.toString() ?? '');
    final moTaCtrl = TextEditingController(text: loaiRacCu?['mo_ta'] ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loaiRacCu == null ? 'Thêm loại rác' : 'Sửa loại rác'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: tenCtrl,
              decoration: const InputDecoration(labelText: 'Tên loại rác'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: giaCtrl,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Đơn giá / kg (VNĐ)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: moTaCtrl,
              decoration: const InputDecoration(labelText: 'Mô tả'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          FilledButton(
            onPressed: () async {
              // Kiểm tra dữ liệu trước khi lưu
              final ten = tenCtrl.text.trim();
              final gia = num.tryParse(giaCtrl.text);
              if (ten.isEmpty || gia == null || gia <= 0) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content: Text('Vui lòng nhập tên và đơn giá hợp lệ')));
                return;
              }

              if (loaiRacCu == null) {
                // THÊM MỚI
                await DatabaseService.themLoaiRac(
                    ten: ten, donGia: gia, moTa: moTaCtrl.text.trim());
              } else {
                // SỬA: truyền map các cột cần đổi
                await DatabaseService.suaLoaiRac(loaiRacCu['id'], {
                  'ten_loai_rac': ten,
                  'don_gia': gia,
                  'mo_ta': moTaCtrl.text.trim(),
                });
              }

              if (ctx.mounted) Navigator.pop(ctx);
              _taiDuLieu(); // tải lại danh sách
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  /// Xóa loại rác (có hộp thoại xác nhận + bắt lỗi ràng buộc khóa ngoại)
  Future<void> _xoa(Map<String, dynamic> loai) async {
    final dongY = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa loại rác'),
        content: Text('Xóa "${loai['ten_loai_rac']}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (dongY != true) return;

    try {
      await DatabaseService.xoaLoaiRac(loai['id']);
      _taiDuLieu();
    } catch (e) {
      // Lỗi hay gặp nhất: loại rác đang được lịch hẹn sử dụng (FK RESTRICT)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Không xóa được: loại rác này đang được lịch hẹn sử dụng.'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }
}
