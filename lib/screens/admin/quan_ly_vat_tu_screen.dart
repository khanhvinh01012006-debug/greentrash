// ============================================================================
// quan_ly_vat_tu_screen.dart - ADMIN QUẢN LÝ KHO VẬT TƯ (PKG03)
// ----------------------------------------------------------------------------
// (Ứng với UC11 tra cứu, UC12 nhập kho, UC13 xuất kho và yêu cầu 34:
//  "cảnh báo khi tồn kho dưới mức tối thiểu" - hiện chữ đỏ)
//
// Chức năng:
//   - Xem danh sách vật tư + số tồn (tồn thấp hơn ngưỡng -> cảnh báo đỏ)
//   - Thêm vật tư mới
//   - Nhập kho (cộng tồn) / Xuất kho (trừ tồn, không cho âm)
//   - Xóa vật tư
// ============================================================================

import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../widgets/common.dart';

class QuanLyVatTuScreen extends StatefulWidget {
  const QuanLyVatTuScreen({super.key});

  @override
  State<QuanLyVatTuScreen> createState() => _QuanLyVatTuScreenState();
}

class _QuanLyVatTuScreenState extends State<QuanLyVatTuScreen> {
  List<Map<String, dynamic>> _dsVatTu = [];
  bool _dangTai = true;

  @override
  void initState() {
    super.initState();
    _taiDuLieu();
  }

  Future<void> _taiDuLieu() async {
    setState(() => _dangTai = true);
    final ds = await DatabaseService.layDanhSachVatTu();
    if (mounted) {
      setState(() {
        _dsVatTu = ds;
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
              itemCount: _dsVatTu.length,
              itemBuilder: (context, i) {
                final vt = _dsVatTu[i];
                final ton = vt['so_luong_ton'] as int;
                final nguong = vt['ton_toi_thieu'] as int;
                // CẢNH BÁO: tồn kho dưới ngưỡng tối thiểu (yêu cầu 34)
                final sapHet = ton < nguong;

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          sapHet ? Colors.red.shade50 : const Color(0xFFE8F5E9),
                      child: Icon(Icons.inventory_2_outlined,
                          color: sapHet ? Colors.red : const Color(0xFF2E7D32)),
                    ),
                    title: Text(vt['ten_vat_tu'],
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      'Tồn: $ton ${vt['don_vi_tinh']}'
                      '${sapHet ? '  ⚠️ SẮP HẾT (dưới $nguong)' : ''}'
                      '\nĐơn giá: ${dinhDangTien(vt['don_gia'])}'
                      // Định mức = số lượng tự trừ kho mỗi lần hoàn tất thu gom
                      ' • Định mức/lần: ${vt['dinh_muc_su_dung'] ?? 0}',
                      style: TextStyle(color: sapHet ? Colors.red : null),
                    ),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      onSelected: (hanhDong) => _xuLyMenu(vt, hanhDong),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'nhap', child: Text('📥 Nhập kho')),
                        PopupMenuItem(value: 'xuat', child: Text('📤 Xuất kho')),
                        PopupMenuItem(
                            value: 'dinh_muc',
                            child: Text('⚙️ Định mức sử dụng')),
                        PopupMenuItem(value: 'xoa', child: Text('🗑️ Xóa')),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _themVatTu,
        icon: const Icon(Icons.add),
        label: const Text('Thêm vật tư'),
      ),
    );
  }

  /// Điều phối hành động từ menu 3 chấm
  Future<void> _xuLyMenu(Map<String, dynamic> vt, String hanhDong) async {
    switch (hanhDong) {
      case 'nhap':
        await _nhapXuatKho(vt, laNhap: true);
      case 'xuat':
        await _nhapXuatKho(vt, laNhap: false);
      case 'dinh_muc':
        await _suaDinhMuc(vt);
      case 'xoa':
        await DatabaseService.xoaVatTu(vt['id']);
        _taiDuLieu();
    }
  }

  /// Hộp thoại nhập/xuất kho - dùng chung, khác nhau ở dấu +/- số lượng
  Future<void> _nhapXuatKho(Map<String, dynamic> vt,
      {required bool laNhap}) async {
    final soLuongCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${laNhap ? "Nhập" : "Xuất"} kho: ${vt['ten_vat_tu']}'),
        content: TextField(
          controller: soLuongCtrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Số lượng ${laNhap ? "nhập" : "xuất"} (${vt['don_vi_tinh']})',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          FilledButton(
            onPressed: () async {
              final soLuong = int.tryParse(soLuongCtrl.text);
              if (soLuong == null || soLuong <= 0) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content: Text('Nhập số lượng hợp lệ (> 0)')));
                return;
              }

              try {
                // Nhập kho -> +soLuong ; Xuất kho -> -soLuong
                await DatabaseService.capNhatTonKho(
                    vt['id'], laNhap ? soLuong : -soLuong);
                if (ctx.mounted) Navigator.pop(ctx);
                _taiDuLieu();
              } catch (e) {
                // Lỗi "tồn không đủ để xuất" ném từ service
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                      content: Text(e.toString().replaceAll('Exception: ', '')),
                      backgroundColor: Colors.red));
                }
              }
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  /// Sửa ĐỊNH MỨC SỬ DỤNG: số lượng vật tư này tiêu hao cho MỖI lần thu gom.
  /// Khi admin bấm "Hoàn tất" một lịch, kho sẽ TỰ TRỪ đúng bằng định mức
  /// và ghi vào chi tiết hóa đơn (0 = vật tư không tiêu hao theo lần).
  Future<void> _suaDinhMuc(Map<String, dynamic> vt) async {
    final dinhMucCtrl = TextEditingController(
        text: '${vt['dinh_muc_su_dung'] ?? 0}');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Định mức: ${vt['ten_vat_tu']}'),
        content: TextField(
          controller: dinhMucCtrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Số ${vt['don_vi_tinh']} dùng mỗi lần thu gom',
            helperText: 'Nhập 0 nếu vật tư này không tiêu hao theo lần',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          FilledButton(
            onPressed: () async {
              final dinhMuc = int.tryParse(dinhMucCtrl.text) ?? 0;
              await DatabaseService.suaVatTu(
                  vt['id'], {'dinh_muc_su_dung': dinhMuc});
              if (ctx.mounted) Navigator.pop(ctx);
              _taiDuLieu();
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  /// Form thêm vật tư mới
  Future<void> _themVatTu() async {
    final tenCtrl = TextEditingController();
    final dvtCtrl = TextEditingController(text: 'cái');
    final tonCtrl = TextEditingController(text: '0');
    final giaCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm vật tư'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: tenCtrl,
                decoration: const InputDecoration(labelText: 'Tên vật tư')),
            const SizedBox(height: 12),
            TextField(
                controller: dvtCtrl,
                decoration: const InputDecoration(labelText: 'Đơn vị tính')),
            const SizedBox(height: 12),
            TextField(
                controller: tonCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Số lượng ban đầu')),
            const SizedBox(height: 12),
            TextField(
                controller: giaCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Đơn giá (VNĐ)')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          FilledButton(
            onPressed: () async {
              final ten = tenCtrl.text.trim();
              if (ten.isEmpty) return;

              await DatabaseService.themVatTu(
                ten: ten,
                donViTinh: dvtCtrl.text.trim(),
                soLuongTon: int.tryParse(tonCtrl.text) ?? 0,
                donGia: num.tryParse(giaCtrl.text) ?? 0,
              );
              if (ctx.mounted) Navigator.pop(ctx);
              _taiDuLieu();
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}
