// ============================================================================
// quan_ly_lich_screen.dart - ADMIN QUẢN LÝ LỊCH HẸN
// ----------------------------------------------------------------------------
// (Ứng với yêu cầu 26, 27 trong bảng khảo sát: "xem danh sách lịch hẹn theo
// trạng thái" và "xác nhận / từ chối lịch hẹn")
//
// Chức năng:
//   - Xem TẤT CẢ lịch của mọi khách hàng, realtime
//   - Lọc theo trạng thái bằng các chip phía trên
//   - Duyệt (cho_xac_nhan -> da_xac_nhan)
//   - Hoàn tất (da_xac_nhan -> hoan_tat)  -> lịch này được tính doanh thu
//   - Từ chối/Hủy (bất kỳ -> da_huy)
//   - Bấm vào lịch để xem chi tiết (kèm tên + SĐT khách, ảnh rác)
// ============================================================================

import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../widgets/common.dart';
import '../../widgets/khung_chat.dart';

class QuanLyLichScreen extends StatefulWidget {
  const QuanLyLichScreen({super.key});

  @override
  State<QuanLyLichScreen> createState() => _QuanLyLichScreenState();
}

class _QuanLyLichScreenState extends State<QuanLyLichScreen> {
  // Bộ lọc trạng thái: 'tat_ca' hoặc 1 trong 4 trạng thái
  String _boLoc = 'tat_ca';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ---- Thanh chip lọc trạng thái ----
        SingleChildScrollView(
          scrollDirection: Axis.horizontal, // cuộn ngang khi hẹp
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              for (final muc in const [
                ('tat_ca', 'Tất cả'),
                ('cho_xac_nhan', 'Chờ xác nhận'),
                ('da_xac_nhan', 'Đã xác nhận'),
                ('hoan_tat', 'Hoàn tất'),
                ('da_huy', 'Đã hủy'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(muc.$2),
                    selected: _boLoc == muc.$1,
                    onSelected: (_) => setState(() => _boLoc = muc.$1),
                  ),
                ),
            ],
          ),
        ),

        // ---- Danh sách lịch realtime ----
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: DatabaseService.streamTatCaLich(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Lỗi: ${snapshot.error}'));
              }

              var dsLich = snapshot.data ?? [];

              // Áp bộ lọc: where() giữ lại phần tử thỏa điều kiện
              if (_boLoc != 'tat_ca') {
                dsLich =
                    dsLich.where((l) => l['trang_thai'] == _boLoc).toList();
              }

              if (dsLich.isEmpty) {
                return const Center(child: Text('Không có lịch nào.'));
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: dsLich.length,
                itemBuilder: (context, i) {
                  final lich = dsLich[i];
                  final trangThai = lich['trang_thai'] as String;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      onTap: () => _xemChiTiet(context, lich['id']),
                      title: Text(
                          'Lịch #${lich['id']} - ${dinhDangNgay(DateTime.parse(lich['ngay_hen']))}'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(lich['dia_chi_thu_gom'] ?? ''),
                          Text(dinhDangTien(lich['chi_phi_du_kien'] ?? 0),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2E7D32))),
                          const SizedBox(height: 4),
                          // Nhãn thanh toán: nhờ realtime, khi khách bấm
                          // "Tôi đã chuyển khoản" nhãn này đổi màu cam NGAY
                          // - chính là "thông báo" cho admin
                          ChipThanhToan(
                            trangThaiTT: lich['trang_thai_tt'],
                            phuongThuc: lich['phuong_thuc_tt'],
                          ),
                        ],
                      ),
                      // Bên phải: chip trạng thái + menu 3 chấm
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Nhắn tin với khách về lịch này - luôn hiện
                          IconButton(
                            tooltip: 'Nhắn tin',
                            onPressed: () =>
                                moKhungChat(context, lich['id']),
                            icon: const Icon(Icons.chat_bubble_outline),
                          ),
                          ChipTrangThai(trangThai: trangThai),
                          // PopupMenuButton = menu 3 chấm với các hành động
                          PopupMenuButton<String>(
                            onSelected: (hanhDong) =>
                                _xuLyHanhDong(lich['id'], hanhDong),
                            itemBuilder: (_) => [
                              // Chỉ hiện "Duyệt" khi đang chờ xác nhận
                              if (trangThai == 'cho_xac_nhan')
                                const PopupMenuItem(
                                    value: 'da_xac_nhan',
                                    child: Text('✅ Duyệt lịch')),
                              // Chỉ hiện "Hoàn tất" khi đã xác nhận
                              if (trangThai == 'da_xac_nhan')
                                const PopupMenuItem(
                                    value: 'hoan_tat',
                                    child: Text('🏁 Hoàn tất thu gom')),
                              // Xác nhận nhận tiền: khi khách đã chọn phương
                              // thức mà tiền chưa được xác nhận (ưu tiên hiện
                              // khi khách vừa báo đã chuyển khoản)
                              if (lich['trang_thai_tt'] != 'da_thanh_toan' &&
                                  (trangThai == 'da_xac_nhan' ||
                                      trangThai == 'hoan_tat'))
                                const PopupMenuItem(
                                    value: 'xac_nhan_tien',
                                    child: Text('💰 Xác nhận đã nhận tiền')),
                              // Hủy được khi chưa hoàn tất/chưa hủy
                              if (trangThai == 'cho_xac_nhan' ||
                                  trangThai == 'da_xac_nhan')
                                const PopupMenuItem(
                                    value: 'da_huy',
                                    child: Text('❌ Từ chối / Hủy')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// Đổi trạng thái lịch theo hành động admin chọn từ menu
  Future<void> _xuLyHanhDong(int idLich, String trangThaiMoi) async {
    try {
      // XÁC NHẬN ĐÃ NHẬN TIỀN (không phải đổi trạng thái lịch)
      if (trangThaiMoi == 'xac_nhan_tien') {
        await ThanhToanService.adminXacNhanDaNhanTien(idLich);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Đã xác nhận nhận tiền cho lịch #$idLich.'),
              backgroundColor: Colors.green));
        }
        return;
      }

      if (trangThaiMoi == 'hoan_tat') {
        // HOÀN TẤT là nghiệp vụ đặc biệt: trước tiên cho admin DUYỆT LẠI
        // số lượng vật tư dùng THỰC TẾ của lần thu gom này (mặc định theo
        // định mức, sửa được nếu lần này dùng nhiều/ít hơn), sau đó mới
        // LẬP HÓA ĐƠN + TRỪ KHO (UC16 + UC07).
        final soLuongThucTe = await _hoiSoLuongVatTu();
        if (soLuongThucTe == null) return; // admin bấm Hủy -> không làm gì

        await HoaDonService.hoanTatLichVaLapHoaDon(idLich,
            soLuongThucTe: soLuongThucTe);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Đã hoàn tất lịch #$idLich, lập hóa đơn và trừ kho vật tư.'),
            backgroundColor: Colors.green,
          ));
        }
        return;
      }

      // Các hành động khác (duyệt / từ chối) chỉ đổi trạng thái như cũ
      await DatabaseService.doiTrangThaiLich(idLich, trangThaiMoi);
      // Realtime stream tự cập nhật list, khách hàng cũng thấy thay đổi NGAY
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Đã cập nhật lịch #$idLich -> ${tenTrangThai(trangThaiMoi)}')),
        );
      }
    } catch (e) {
      // Lỗi hay gặp nhất: kho không đủ vật tư -> hiện nguyên văn để admin xử lý
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e'), backgroundColor: Colors.red));
      }
    }
  }


  /// Hộp thoại DUYỆT VẬT TƯ trước khi hoàn tất (UC07 - Chọn vật tư thu gom):
  /// liệt kê mọi vật tư, ô số lượng điền sẵn = ĐỊNH MỨC; admin sửa tự do
  /// (tăng nếu lần này dùng thêm, giảm/về 0 nếu không dùng).
  /// Trả về map {id vật tư: số lượng} hoặc null nếu bấm Hủy.
  Future<Map<int, int>?> _hoiSoLuongVatTu() async {
    // Tải danh sách vật tư hiện có
    final dsVatTu = await DatabaseService.layDanhSachVatTu();
    if (!mounted) return null;

    // Mỗi vật tư 1 controller, điền sẵn định mức
    final cacCtrl = <int, TextEditingController>{
      for (final vt in dsVatTu)
        vt['id'] as int: TextEditingController(
            text: '${vt['dinh_muc_su_dung'] ?? 0}'),
    };

    final ketQua = await showDialog<Map<int, int>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vật tư sử dụng lần này'),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Số điền sẵn là định mức chuẩn. Lần thu gom này dùng '
                  'khác thì sửa số (0 = không dùng).',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 12),
                // Mỗi vật tư 1 hàng: tên (kèm tồn kho) + ô số lượng
                ...dsVatTu.map((vt) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                                '${vt['ten_vat_tu']}\n(tồn: ${vt['so_luong_ton']} ${vt['don_vi_tinh']})',
                                style: const TextStyle(height: 1.3)),
                          ),
                          SizedBox(
                            width: 70,
                            child: TextField(
                              controller: cacCtrl[vt['id']],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              decoration: const InputDecoration(
                                  isDense: true,
                                  border: OutlineInputBorder()),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          FilledButton(
            onPressed: () {
              // Gom số liệu từ các ô nhập thành map {id: số lượng}
              final map = <int, int>{};
              cacCtrl.forEach((id, ctrl) {
                map[id] = int.tryParse(ctrl.text) ?? 0;
              });
              Navigator.pop(ctx, map);
            },
            child: const Text('Xác nhận hoàn tất'),
          ),
        ],
      ),
    );
    return ketQua;
  }

  /// Mở bottom sheet xem chi tiết lịch (kèm thông tin khách + ảnh)
  Future<void> _xemChiTiet(BuildContext context, int idLich) async {
    // Lấy chi tiết có JOIN sang bảng nguoi_dung và loai_rac
    final lich = await DatabaseService.layChiTietLich(idLich);
    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            Text('Chi tiết lịch #$idLich',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            // ?[''] có thể null nên dùng ?? để có giá trị dự phòng
            Text('👤 Khách hàng: ${lich['nguoi_dung']?['ho_ten'] ?? '?'}'),
            Text('📞 SĐT: ${lich['nguoi_dung']?['so_dien_thoai'] ?? '?'}'),
            Text('🗑️ Loại rác: ${lich['loai_rac']?['ten_loai_rac'] ?? '?'}'),
            Text('📍 Địa chỉ: ${lich['dia_chi_thu_gom']}'),
            Text(
                '📅 Ngày hẹn: ${dinhDangNgay(DateTime.parse(lich['ngay_hen']))} (${lich['khung_gio'] == 'sang' ? 'Sáng' : 'Chiều'})'),
            Text('⚖️ Khối lượng: ${lich['khoi_luong_uoc_tinh'] ?? '?'} kg'),
            Text('💰 Chi phí dự kiến: ${dinhDangTien(lich['chi_phi_du_kien'] ?? 0)}'),
            if (lich['ghi_chu'] != null) Text('📝 Ghi chú: ${lich['ghi_chu']}'),
            const SizedBox(height: 12),
            if (lich['hinh_anh_url'] != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(lich['hinh_anh_url'],
                    height: 200, fit: BoxFit.cover),
              ),
          ],
        ),
      ),
    );
  }
}
