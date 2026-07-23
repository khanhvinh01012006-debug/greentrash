// ============================================================================
// quan_ly_bai_viet_screen.dart - ADMIN quản lý TIN TỨC / BÀI VIẾT
// ----------------------------------------------------------------------------
// Chức năng:
//   - Xem danh sách bài viết (ảnh bìa thu nhỏ + tiêu đề + ngày đăng)
//   - Đăng bài mới: tiêu đề, tóm tắt, nội dung, ảnh bìa (upload từ máy)
//   - Sửa / Xóa bài đã đăng
// Dùng chung StorageService.uploadAnh với chức năng đặt lịch - ảnh bài viết
// cũng lưu trong bucket 'hinh-anh-rac'.
// ============================================================================

import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/common.dart';

class QuanLyBaiVietScreen extends StatefulWidget {
  const QuanLyBaiVietScreen({super.key});

  @override
  State<QuanLyBaiVietScreen> createState() => _QuanLyBaiVietScreenState();
}

class _QuanLyBaiVietScreenState extends State<QuanLyBaiVietScreen> {
  List<Map<String, dynamic>> _dsBaiViet = [];
  bool _dangTai = true;

  @override
  void initState() {
    super.initState();
    _taiDanhSach();
  }

  Future<void> _taiDanhSach() async {
    setState(() => _dangTai = true);
    try {
      final ds = await BaiVietService.layDanhSachBaiViet();
      if (mounted) setState(() => _dsBaiViet = ds);
    } catch (e) {
      _baoLoi('Lỗi tải bài viết: $e');
    } finally {
      if (mounted) setState(() => _dangTai = false);
    }
  }

  // ==========================================================================
  // Hộp thoại ĐĂNG BÀI MỚI / SỬA BÀI - dùng chung 1 hàm
  // (baiCu = null -> đăng mới; khác null -> sửa, form điền sẵn dữ liệu cũ)
  // ==========================================================================
  Future<void> _moFormBaiViet({Map<String, dynamic>? baiCu}) async {
    final formKey = GlobalKey<FormState>();
    final tieuDeCtrl = TextEditingController(text: baiCu?['tieu_de'] ?? '');
    final tomTatCtrl = TextEditingController(text: baiCu?['tom_tat'] ?? '');
    final noiDungCtrl = TextEditingController(text: baiCu?['noi_dung'] ?? '');

    // Ảnh bìa: giữ link cũ (nếu sửa) hoặc bytes ảnh mới vừa chọn
    String? linkAnhCu = baiCu?['hinh_anh_url'];
    Uint8List? anhMoiBytes;
    String? anhMoiTen;
    bool dangLuu = false;

    await showDialog(
      context: context,
      // StatefulBuilder: cho phép setState RIÊNG bên trong dialog
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Text(baiCu == null ? 'Đăng bài viết mới' : 'Sửa bài viết'),
          content: SizedBox(
            width: 500, // dialog rộng hơn mặc định cho dễ soạn bài
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ---- Ảnh bìa ----
                    // Ưu tiên hiện: ảnh mới chọn > ảnh cũ > khung trống
                    if (anhMoiBytes != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(anhMoiBytes!,
                            height: 140, fit: BoxFit.cover),
                      )
                    else if (linkAnhCu != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(linkAnhCu,
                            height: 140, fit: BoxFit.cover),
                      )
                    else
                      Container(
                        height: 140,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.image_outlined,
                            size: 48, color: Colors.grey),
                      ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(anhMoiBytes == null && linkAnhCu == null
                          ? 'Chọn ảnh bìa'
                          : 'Đổi ảnh bìa'),
                      onPressed: () async {
                        final anh = await StorageService.chonAnh();
                        if (anh != null) {
                          setStateDialog(() {
                            anhMoiBytes = anh.bytes;
                            anhMoiTen = anh.tenFile;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // ---- Tiêu đề ----
                    TextFormField(
                      controller: tieuDeCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Tiêu đề bài viết'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Vui lòng nhập tiêu đề'
                          : null,
                    ),
                    const SizedBox(height: 12),

                    // ---- Tóm tắt ----
                    TextFormField(
                      controller: tomTatCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Tóm tắt (1-2 câu, hiện ở trang chủ)',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Vui lòng nhập tóm tắt'
                          : null,
                    ),
                    const SizedBox(height: 12),

                    // ---- Nội dung ----
                    TextFormField(
                      controller: noiDungCtrl,
                      maxLines: 8, // ô soạn thảo cao 8 dòng
                      decoration: const InputDecoration(
                        labelText: 'Nội dung đầy đủ',
                        alignLabelWithHint: true,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Vui lòng nhập nội dung'
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: dangLuu ? null : () => Navigator.pop(ctx),
                child: const Text('Hủy')),
            FilledButton(
              onPressed: dangLuu
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setStateDialog(() => dangLuu = true);
                      try {
                        // Có ảnh mới -> upload trước, lấy link
                        String? linkAnh = linkAnhCu;
                        if (anhMoiBytes != null) {
                          linkAnh = await StorageService.uploadAnh(
                              anhMoiBytes!, anhMoiTen!);
                        }

                        if (baiCu == null) {
                          // ĐĂNG MỚI
                          await BaiVietService.themBaiViet(
                            tieuDe: tieuDeCtrl.text.trim(),
                            tomTat: tomTatCtrl.text.trim(),
                            noiDung: noiDungCtrl.text.trim(),
                            hinhAnhUrl: linkAnh,
                          );
                        } else {
                          // SỬA BÀI CŨ
                          await BaiVietService.suaBaiViet(baiCu['id'], {
                            'tieu_de': tieuDeCtrl.text.trim(),
                            'tom_tat': tomTatCtrl.text.trim(),
                            'noi_dung': noiDungCtrl.text.trim(),
                            'hinh_anh_url': linkAnh,
                          });
                        }

                        if (ctx.mounted) Navigator.pop(ctx);
                        _baoThanhCong(baiCu == null
                            ? 'Đã đăng bài viết!'
                            : 'Đã cập nhật bài viết!');
                        _taiDanhSach(); // tải lại danh sách cho thấy bài mới
                      } catch (e) {
                        setStateDialog(() => dangLuu = false);
                        _baoLoi('Lỗi: $e');
                      }
                    },
              child: dangLuu
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(baiCu == null ? 'Đăng bài' : 'Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  /// Xóa bài viết (hỏi xác nhận trước)
  Future<void> _xoaBai(Map<String, dynamic> bai) async {
    final dongY = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa bài viết'),
        content: Text('Xóa bài "${bai['tieu_de']}"?'),
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
      await BaiVietService.xoaBaiViet(bai['id']);
      _baoThanhCong('Đã xóa bài viết.');
      _taiDanhSach();
    } catch (e) {
      _baoLoi('Lỗi xóa: $e');
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
    return Scaffold(
      body: _dangTai
          ? const Center(child: CircularProgressIndicator())
          : _dsBaiViet.isEmpty
              ? const Center(child: Text('Chưa có bài viết nào.\nBấm nút + để đăng bài đầu tiên!',
                  textAlign: TextAlign.center))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _dsBaiViet.length,
                  itemBuilder: (context, i) {
                    final bai = _dsBaiViet[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        // Ảnh bìa thu nhỏ bên trái (không có ảnh -> icon)
                        leading: bai['hinh_anh_url'] != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.network(
                                  bai['hinh_anh_url'],
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  // Ảnh lỗi/mất mạng -> hiện icon thay thế
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.article_outlined),
                                ),
                              )
                            : const CircleAvatar(
                                child: Icon(Icons.article_outlined)),
                        title: Text(bai['tieu_de'],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        // ngay_dang trong database là CHUỖI -> đổi sang
                        // DateTime bằng DateTime.parse rồi mới định dạng
                        subtitle: Text(
                            'Đăng ngày ${dinhDangNgay(DateTime.parse(bai['ngay_dang']))}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Sửa',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _moFormBaiViet(baiCu: bai),
                            ),
                            IconButton(
                              tooltip: 'Xóa',
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red),
                              onPressed: () => _xoaBai(bai),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      // Nút tròn góc phải dưới để đăng bài mới
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _moFormBaiViet(),
        icon: const Icon(Icons.add),
        label: const Text('Đăng bài'),
      ),
    );
  }
}
