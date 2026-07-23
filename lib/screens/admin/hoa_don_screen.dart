// ============================================================================
// hoa_don_screen.dart - ADMIN xem LỊCH SỬ HÓA ĐƠN (UC16, BM04)
// ----------------------------------------------------------------------------
// Hóa đơn được LẬP TỰ ĐỘNG khi admin bấm "Hoàn tất" một lịch thu gom
// (xem HoaDonService.hoanTatLichVaLapHoaDon). Màn hình này chỉ để TRA CỨU:
//   - Danh sách hóa đơn: mã, khách, ngày lập, tiền rác
//   - Bấm vào 1 hóa đơn -> xem chi tiết: thông tin lịch + bảng vật tư tiêu hao
// ============================================================================

import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../widgets/common.dart';

class HoaDonScreen extends StatefulWidget {
  const HoaDonScreen({super.key});

  @override
  State<HoaDonScreen> createState() => _HoaDonScreenState();
}

class _HoaDonScreenState extends State<HoaDonScreen> {
  List<Map<String, dynamic>> _dsHoaDon = [];
  bool _dangTai = true;

  @override
  void initState() {
    super.initState();
    _taiDanhSach();
  }

  Future<void> _taiDanhSach() async {
    setState(() => _dangTai = true);
    try {
      final ds = await HoaDonService.layDanhSachHoaDon();
      if (mounted) setState(() => _dsHoaDon = ds);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Lỗi tải hóa đơn: $e '
              '(bạn đã chạy update_02_hoa_don_nguoi_dung.sql chưa?)'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _dangTai = false);
    }
  }

  /// Mở bảng chi tiết hóa đơn (trượt từ dưới lên)
  Future<void> _moChiTiet(Map<String, dynamic> hd) async {
    // Tải danh sách vật tư tiêu hao của hóa đơn này
    List<Map<String, dynamic>> dsVatTu = [];
    try {
      dsVatTu = await HoaDonService.layChiTietVatTu(hd['id']);
    } catch (_) {}

    if (!mounted) return;

    final lich = hd['lich_thu_gom'] ?? {};
    final khach = lich['nguoi_dung'] ?? {};
    final loaiRac = lich['loai_rac'] ?? {};
    // Tổng cộng = tiền trả khách (tiền rác). Chi phí vật tư là chi phí
    // NỘI BỘ của doanh nghiệp, hiển thị riêng để admin nắm giá vốn.
    final tienRac = hd['tien_rac'] ?? 0;
    final tienVatTu = hd['tong_tien_vat_tu'] ?? 0;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true, // cho phép sheet cao quá nửa màn hình
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (ctx, scrollCtrl) => SingleChildScrollView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text('HÓA ĐƠN #${hd['id']}',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              Center(
                child: Text(
                  'Lập ngày ${dinhDangNgay(DateTime.parse(hd['ngay_lap']))}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
              const Divider(height: 28),

              // ---- Thông tin khách + lịch ----
              _dong('Khách hàng', khach['ho_ten'] ?? '—'),
              _dong('Điện thoại', khach['so_dien_thoai'] ?? '—'),
              _dong('Địa chỉ thu gom', lich['dia_chi_thu_gom'] ?? '—'),
              _dong('Loại rác', loaiRac['ten_loai_rac'] ?? '—'),
              _dong('Khối lượng', '${lich['khoi_luong_uoc_tinh'] ?? '—'} kg'),
              const Divider(height: 28),

              // ---- Tiền trả khách ----
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('TIỀN KHÁCH THANH TOÁN',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(dinhDangTien(tienRac),
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32))),
                ],
              ),
              const Divider(height: 28),

              // ---- Bảng vật tư tiêu hao ----
              const Text('Vật tư tiêu hao (chi phí nội bộ)',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (dsVatTu.isEmpty)
                const Text('Không tiêu hao vật tư nào.',
                    style: TextStyle(color: Colors.grey))
              else
                Table(
                  // Bảng 4 cột: Tên | SL | Đơn giá | Thành tiền
                  columnWidths: const {
                    0: FlexColumnWidth(3),
                    1: FlexColumnWidth(1),
                    2: FlexColumnWidth(2),
                    3: FlexColumnWidth(2),
                  },
                  children: [
                    // Hàng tiêu đề
                    const TableRow(children: [
                      Text('Vật tư',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      Text('SL',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      Text('Đơn giá',
                          textAlign: TextAlign.right,
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      Text('T.Tiền',
                          textAlign: TextAlign.right,
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ]),
                    // Mỗi vật tư 1 hàng
                    ...dsVatTu.map((vt) => TableRow(children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                                '${vt['ten_vat_tu']} (${vt['don_vi_tinh']})'),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text('${vt['so_luong']}'),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(dinhDangTien(vt['don_gia']),
                                textAlign: TextAlign.right),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(dinhDangTien(vt['thanh_tien']),
                                textAlign: TextAlign.right),
                          ),
                        ])),
                  ],
                ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text('Tổng chi phí vật tư: ${dinhDangTien(tienVatTu)}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 1 dòng "nhãn: giá trị" trong phần chi tiết
  Widget _dong(String nhan, String giaTri) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 140,
              child: Text(nhan, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(giaTri)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_dangTai) return const Center(child: CircularProgressIndicator());

    if (_dsHoaDon.isEmpty) {
      return const Center(
        child: Text(
          'Chưa có hóa đơn nào.\nHóa đơn tự sinh khi bạn bấm "Hoàn tất" một lịch thu gom.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _taiDanhSach,
      child: Column(
        children: [
          // Thanh công cụ: đếm số hóa đơn + nút TẢI LẠI
          // (danh sách này tải-một-lần chứ không realtime - xem chú thích đầu
          // file - nên sau khi hoàn tất lịch mới, bấm nút này để thấy hóa đơn)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Tổng: ${_dsHoaDon.length} hóa đơn',
                    style: const TextStyle(color: Colors.grey)),
                OutlinedButton.icon(
                  onPressed: _taiDanhSach,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Tải lại'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _dsHoaDon.length,
              itemBuilder: (context, i) {
          final hd = _dsHoaDon[i];
          final khach = (hd['lich_thu_gom'] ?? {})['nguoi_dung'] ?? {};
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE8F5E9),
                child: Icon(Icons.receipt_long, color: Color(0xFF2E7D32)),
              ),
              title: Text('Hóa đơn #${hd['id']} - ${khach['ho_ten'] ?? '—'}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                  'Lập ngày ${dinhDangNgay(DateTime.parse(hd['ngay_lap']))}'),
              trailing: Text(
                dinhDangTien(hd['tien_rac'] ?? 0),
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF2E7D32)),
              ),
              onTap: () => _moChiTiet(hd),
            ),
          );
              },
            ),
          ),
        ],
      ),
    );
  }
}
